<#
FACILITATOR-ONLY. Phase 9 — Teardown.

Removes the estate created by the provisioning scripts. Personas in Phase 2 can optionally persist
between deliveries; pass -RemovePersonas to remove them too. The Azure endpoints are removed separately:
  az group delete -n rg-meridian-lab --yes

Lines marked [verify] depend on tenant specifics.
#>
param(
  [switch]$RemovePersonas
)
$ErrorActionPreference = 'Continue'
Add-PowerAppsAccount | Out-Null

Write-Host 'Removing agents (all 10) across the four environments...'
# [verify] Delete each Copilot Studio agent (PPAC / pac / Agent 365 admin).

Write-Host 'Removing connections (including svc-claims and tom.dean shared connections)...'
# [verify] Get-AdminPowerAppConnection | Remove-AdminPowerAppConnection per environment.

Write-Host 'Removing Dataverse Claim/Customer tables and SharePoint HR-Benefits/Claims-Knowledge sites...'
# [verify] Remove tables (or delete the solution); Remove-PnPSite for the two sites.

Write-Host 'Removing non-default environments (Meridian-Prod, Claims-Test, Maker-Sandbox)...'
# [verify] Remove-AdminPowerAppEnvironment for each (NOT the default environment).

if ($RemovePersonas) {
  Connect-MgGraph -Scopes 'User.ReadWrite.All','Group.ReadWrite.All' | Out-Null
  Write-Host 'Removing personas, service account, shared mailbox, and groups...'
  # [verify] Remove-MgUser / Remove-MgGroup for each principal created in Phase 2.
}

Write-Host 'Teardown complete. Remember: az group delete -n rg-meridian-lab --yes'
