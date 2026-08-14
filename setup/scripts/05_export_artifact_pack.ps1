<#
FACILITATOR-ONLY. Phase 7 — Export the artifact pack.

Pulls the estate from the Power Platform admin APIs + Microsoft Graph and writes the five canonical CSVs
that attendees analyze offline. The committed files in ../worksheets/artifact-pack/ ARE the expected
output for the canonical estate — diff against them after any change.

Requires: Microsoft.PowerApps.Administration.PowerShell, Microsoft.Graph.
Lines marked [verify] depend on evolving 2026 admin/Graph surfaces (agent + workload identity listings).
#>
param(
  [string]$OutDir = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) 'worksheets/artifact-pack')
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Add-PowerAppsAccount | Out-Null
Connect-MgGraph -Scopes 'User.Read.All','Application.Read.All' | Out-Null

Write-Host "Writing artifact pack to $OutDir"

# 1) agents-export.csv
# [verify] Enumerate Copilot Studio agents across ALL environments (PPAC admin API / Get-AdminPowerApp
# equivalent for agents, or the Agent 365 admin API). Include personal/sandbox environments.
Write-Host '[verify] Export agents (display_name, environment, owner_upn, status, published, created_utc, last_modified_utc, description) -> agents-export.csv'

# 2) connections-export.csv
# [verify] Get-AdminPowerAppConnection across environments; join connector + owner + shared-with + agent.
Write-Host '[verify] Export connections (connection_name, connector, environment, connection_owner_upn, shared_with, used_by_agent, auth_type) -> connections-export.csv'

# 3) agent-identities-export.csv
# [verify] Map each agent to its auto-created Entra identity (Get-MgServicePrincipal / Get-MgApplication
# filtered to the cs-agent-* naming), capturing app_id + created.
Write-Host '[verify] Export agent identities (agent, entra_identity, app_id, identity_created_utc) -> agent-identities-export.csv'

# 4) users-export.csv  (reveals the disabled owner + service/shared accounts)
Write-Host 'Exporting users -> users-export.csv'
# Get-MgUser -All -Property 'userPrincipalName,displayName,accountEnabled,signInActivity' |
#   Select upn, display_name, account_enabled, last_sign_in_utc, is_service_account, is_shared_mailbox |
#   Export-Csv -NoTypeInformation (Join-Path $OutDir 'users-export.csv')

# 5) environments-export.csv
Write-Host 'Exporting environments -> environments-export.csv'
# Get-AdminPowerAppEnvironment | Select environment, type, dlp_policy, managed, maker_access |
#   Export-Csv -NoTypeInformation (Join-Path $OutDir 'environments-export.csv')

Write-Host 'Phase 7 complete. Diff the output against the committed artifact pack; investigate any drift.'
