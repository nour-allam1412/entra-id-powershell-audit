[CmdletBinding()]
param(
    [string]$TenantId,
    [string]$OutputFolder = ".\output"
)

# --- Connect (read-only permissions) ---
$scopes = @("User.Read.All", "Group.Read.All", "RoleManagement.Read.Directory")
try {
    if ($TenantId) { Connect-MgGraph -Scopes $scopes -TenantId $TenantId -NoWelcome -ErrorAction Stop }
    else           { Connect-MgGraph -Scopes $scopes -NoWelcome -ErrorAction Stop }
}
catch {
    Write-Error "Could not connect to Microsoft Graph: $($_.Exception.Message)"
    return
}

New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmm"

# --- 1. Users ---
Write-Host "Reading users..." -ForegroundColor Cyan
$users = Get-MgUser -All -Property Id,DisplayName,UserPrincipalName,Department,JobTitle,AccountEnabled,UserType |
    Select-Object Id,DisplayName,UserPrincipalName,Department,JobTitle,AccountEnabled,UserType
$users | Export-Csv -Path (Join-Path $OutputFolder "users-$stamp.csv") -NoTypeInformation -Encoding UTF8

# --- 2. Groups and member counts ---
Write-Host "Reading groups..." -ForegroundColor Cyan
$groups      = Get-MgGroup -All -Property Id,DisplayName,SecurityEnabled
$groupedIds  = New-Object 'System.Collections.Generic.HashSet[string]'
$groupReport = foreach ($g in $groups) {
    $members = @(Get-MgGroupMember -GroupId $g.Id -All)
    foreach ($m in $members) { [void]$groupedIds.Add($m.Id) }
    [pscustomobject]@{ Group = $g.DisplayName; Members = $members.Count }
}
$groupReport | Export-Csv -Path (Join-Path $OutputFolder "group-membership-$stamp.csv") -NoTypeInformation -Encoding UTF8

# --- 3. Users in no group (external #EXT# accounts excluded) ---
$ungrouped = $users | Where-Object {
    $_.UserType -eq "Member" -and
    $_.UserPrincipalName -notlike "*#EXT#*" -and
    -not $groupedIds.Contains($_.Id)
}
$ungrouped | Select-Object DisplayName,UserPrincipalName,Department |
    Export-Csv -Path (Join-Path $OutputFolder "users-without-a-group-$stamp.csv") -NoTypeInformation -Encoding UTF8

# --- 4. Admin role assignments ---
Write-Host "Reading role assignments..." -ForegroundColor Cyan
$roleReport = foreach ($role in (Get-MgDirectoryRole -All)) {
    foreach ($m in @(Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id -All)) {
        [pscustomobject]@{
            Role              = $role.DisplayName
            Member            = $m.AdditionalProperties["displayName"]
            UserPrincipalName = $m.AdditionalProperties["userPrincipalName"]
            Type              = $m.AdditionalProperties["@odata.type"]
        }
    }
}
$roleReport | Export-Csv -Path (Join-Path $OutputFolder "role-assignments-$stamp.csv") -NoTypeInformation -Encoding UTF8

# --- Summary ---
Write-Host ""
Write-Host "================ SUMMARY ================" -ForegroundColor Green
Write-Host ("Users found:            {0}" -f @($users).Count)
Write-Host ("Groups found:           {0}" -f @($groups).Count)
Write-Host ("Users in no group:      {0}" -f @($ungrouped).Count)
Write-Host ("Role assignments found: {0}" -f @($roleReport).Count)
Write-Host ""
Write-Host "Members per group:" -ForegroundColor Yellow
$groupReport | Sort-Object Group | Format-Table -AutoSize
if (@($ungrouped).Count -gt 0) {
    Write-Host "Users who are in no group:" -ForegroundColor Yellow
    $ungrouped | Select-Object DisplayName,Department | Format-Table -AutoSize
}
Write-Host "Role assignments:" -ForegroundColor Yellow
$roleReport | Sort-Object Role,Member | Format-Table -AutoSize
Write-Host "CSV files saved in: $((Resolve-Path $OutputFolder).Path)" -ForegroundColor Green

Disconnect-MgGraph | Out-Null