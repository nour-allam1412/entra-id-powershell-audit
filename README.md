# Entra ID Audit Script

**A read-only PowerShell script that audits a Microsoft Entra ID tenant through Microsoft Graph and reports who is in the tenant, who is in which group, who is in no group, and who holds each admin role.**

Built after a messy bulk upload left some users out of their department group in my [Entra ID Identity Lab](https://github.com/nour-allam1412/entra-id-identity-lab). When I ran the script, it caught the same kind of gap.

**Author:** Nour Allam | **Stack:** PowerShell 7, Microsoft Graph PowerShell SDK, Microsoft Entra ID

---

## Why it matters

- **Finds silent membership gaps.** Bulk operations can report success or failure unreliably; this verifies the real state of the directory.
- **Shows who holds admin power.** One report lists every directory role in use and its members, which supports least-privilege reviews.
- **Safe by design.** It requests read-only permissions and changes nothing in the tenant.

## Result from my lab tenant

The script ran against a lab tenant with 25 fictional users in three department groups, plus the tenant owner account (tenant name removed):

```
================ SUMMARY ================
Users found:            26
Groups found:           3
Users in no group:      0
Role assignments found: 4

Group    Members
-----    -------
SG-HR          7
SG-IT          9
SG-Sales       9

Role                   Member
----                   ------
Global Administrator   Tenant owner (external account)
Global Reader          Marco Rossi
Helpdesk Administrator Lucas Bennett
User Administrator     Oliver Reeves
```

**What it caught:** an early run showed SG-HR with 5 members when 7 were expected. Comparing the users whose department is HR with the group's actual members (`Compare-Object`) identified two users who had never been added. After I added them, the counts matched and the "users in no group" check returned 0. Group counts matched the Entra admin center, and the role report matched the assignments I had made.

## What it reports

| Report | Question it answers |
|---|---|
| Users | Who is in the tenant, with department, job title, enabled state and user type? |
| Group membership | How many members does each group have? |
| Users in no group | Which member accounts belong to no group? (external `#EXT#` accounts, such as the tenant owner, are excluded) |
| Role assignments | Who holds each directory (admin) role that is in use? |

---

## Quick start

**Requirements**
- PowerShell 7 or later
- An account that can approve the read-only permissions below
- The Microsoft Graph modules:

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
Install-Module Microsoft.Graph.Users -Scope CurrentUser
Install-Module Microsoft.Graph.Groups -Scope CurrentUser
Install-Module Microsoft.Graph.Identity.DirectoryManagement -Scope CurrentUser
```

**Run**

```powershell
.\Get-EntraLabReport.ps1 -TenantId "yourtenant.onmicrosoft.com"
```

A browser window asks you to sign in and approve the permissions. The optional `-OutputFolder` parameter sets where the CSV files go (default `.\output`). If PowerShell blocks the script, run `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` once and try again.

**Permissions requested (all read-only)**

| Scope | Used for |
|---|---|
| `User.Read.All` | Reading users |
| `Group.Read.All` | Reading groups and their members |
| `RoleManagement.Read.Directory` | Reading directory roles and their members |

**Output files** (timestamped, saved in the output folder)

- `users-<timestamp>.csv`
- `group-membership-<timestamp>.csv`
- `users-without-a-group-<timestamp>.csv`
- `role-assignments-<timestamp>.csv`

---

## How it works

1. **Connect:** `Connect-MgGraph` with the three read-only scopes. A `try/catch` turns a failed sign-in into one clear error.
2. **Users:** `Get-MgUser -All` with an explicit `-Property` list, because Graph returns only a default set of fields.
3. **Groups:** `Get-MgGroup` and `Get-MgGroupMember` for each group. Member IDs go into a `HashSet`, which stores each ID once and can be searched quickly.
4. **Users in no group:** member accounts whose ID is not in that set, excluding `#EXT#` accounts.
5. **Roles:** `Get-MgDirectoryRole` and `Get-MgDirectoryRoleMember`, reading names from `AdditionalProperties`.
6. **Export:** `Export-Csv` writes each report with a date and time in the file name, so a new run never overwrites an old one.

## Problems I hit and how I solved them

| Problem | Cause | Fix |
|---|---|---|
| Sign-in failed with "User canceled authentication" | The sign-in window opened behind other windows | Found the window, completed the sign-in and re-ran |
| Department column was blank | Graph returns only a default set of fields | Requested the fields explicitly with `-Property` |
| Tenant owner listed under "users in no group" | The owner is an external account but reports a user type of Member | Excluded `#EXT#` accounts by name instead of relying on user type |
| Had to sign in again whenever I added a step | Graph grants only the scopes requested at sign-in | Requested all three scopes in one `Connect-MgGraph` call |
| Pasted multi-line commands seemed to hang at `>>` | PowerShell was waiting for Enter at the end of the block | Pressed Enter, and moved the commands into a `.ps1` file |

## Limitations

- Only directory roles that are **activated** in the tenant appear. Roles nobody holds are not listed.
- Group counts are **direct members**; nested group members are not expanded.
- It does not report sign-in activity, licenses or devices.

## Security and privacy

- Read-only scopes only; the script cannot change the tenant.
- The CSV reports contain real user names and the tenant domain, so they are excluded from this repository by `.gitignore`.
- All data in my lab tenant is fictional.

## Skills demonstrated

PowerShell scripting, Microsoft Graph PowerShell SDK, Microsoft Entra ID administration, read-only auditing of users, groups and role assignments, data export (CSV), troubleshooting and documentation.

## Repository contents

```
/README.md
/Get-EntraLabReport.ps1   the script
/.gitignore               keeps CSV reports and output folders out of the repo
```
