<#
FACILITATOR-ONLY. Phase 3 — Environments, DLP, Conditional Access baseline.

Creates the four environments, applies DLP to PROD ONLY, and creates the baseline CA policies.
Deliberately leaves Default / Claims-Test / Maker-Sandbox WITHOUT DLP, and creates NO Conditional
Access policy targeting workload/agent identities — those omissions drive Module 5.

Requires: Microsoft.PowerApps.Administration.PowerShell (Add-PowerAppsAccount) and pac CLI.
Lines marked [verify] depend on tenant specifics / evolving 2026 surfaces.
#>
param(
  [string]$Location = 'unitedstates'
)
$ErrorActionPreference = 'Stop'
Add-PowerAppsAccount | Out-Null

# --- Environments ------------------------------------------------------------
# The default environment already exists; rename/adopt it as "Meridian (default)".
$envs = @(
  @{ Name='Meridian-Prod';   Sku='Production'; Managed=$true  }
  @{ Name='Claims-Test';     Sku='Sandbox';    Managed=$false }
  @{ Name='Maker-Sandbox';   Sku='Developer';  Managed=$false }
)
foreach ($e in $envs) {
  Write-Host "Creating environment $($e.Name) ($($e.Sku))"
  # [verify] exact params for New-AdminPowerAppEnvironment in the delivery-date module version
  New-AdminPowerAppEnvironment -DisplayName $e.Name -LocationName $Location -EnvironmentSku $e.Sku | Out-Null
}
Write-Host '[verify] Mark Meridian-Prod as a Managed Environment in PPAC (or via pac admin).'

# --- DLP: PROD ONLY ----------------------------------------------------------
# Baseline business/non-business split applied to Meridian-Prod only. Everything else stays open.
Write-Host 'Creating Meridian-Prod-DLP (business/non-business split), scoped to Meridian-Prod only.'
# [verify] Use New-DlpPolicy / Set-DlpPolicy (Microsoft.PowerApps.Administration.PowerShell) or pac admin.
# Intent:
#   - Business group: Dataverse, SharePoint, Office 365 Outlook, Office 365 Users
#   - Non-business (default) group: everything else
#   - Blocked: HTTP with Entra ID / HTTP action / custom connectors in Prod (Scenario E lever for Module 5)
#   - Scope: environment = Meridian-Prod
Write-Host 'DEALER''S CHOICE for Module 5: leave the HTTP/custom-connector block OFF at start so Scenario E fires,'
Write-Host 'then have attendees turn it on during Module 5 and retest.'

# --- Conditional Access baseline --------------------------------------------
Write-Host '[verify] Create CA baseline in Entra: CA-Require-MFA-Admins, CA-Block-Legacy-Auth.'
Write-Host 'Deliberately DO NOT create a policy targeting workload/agent identities — that gap is a Module 5 finding.'

Write-Host 'Phase 3 complete.'
