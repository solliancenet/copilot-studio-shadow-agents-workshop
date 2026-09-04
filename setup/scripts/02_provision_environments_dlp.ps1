<#
FACILITATOR-ONLY. Phase 3 — Environments, DLP, Conditional Access baseline.

Creates the four environments, applies DLP to PROD ONLY, and notes the baseline CA policies
(CA is manual — see below). Deliberately leaves Default / Claims-Test / Maker-Sandbox WITHOUT DLP,
and creates NO Conditional Access policy targeting workload/agent identities — those omissions drive
Module 5.

Claims-Test is created WITH a Dataverse (Common Data Service) database so Phase 5
(04_provision_dataverse.ps1) has a real *.crm.dynamics.com org URL to target. Prod also gets a DB
because it hosts Dataverse-backed agents. Default and Maker-Sandbox stay as canon specifies.

The org URLs / environment IDs of the created environments are echoed at the end — hand Claims-Test's
*.crm.dynamics.com URL to Phase 5.

Requires: Microsoft.PowerApps.Administration.PowerShell (Add-PowerAppsAccount) and pac CLI.
Lines marked [verify] depend on tenant specifics / evolving 2026 surfaces.
#>
param(
  [string]$Location = 'unitedstates',
  [string]$CurrencyName = 'USD',
  [string]$LanguageName = '1033',              # 1033 = en-US
  [int]$ProvisionTimeoutMinutes = 30
)
$ErrorActionPreference = 'Stop'
Add-PowerAppsAccount | Out-Null

# Helper: return the CDS/Dataverse org URL for an environment object, or $null if none is provisioned.
function Get-EnvInstanceUrl($env) {
  # [verify] property path on the delivery-date module; instanceUrl lives under the linked CDS metadata.
  return $env.Internal.properties.linkedEnvironmentMetadata.instanceUrl
}

# Helper: find an existing environment by display name (idempotency guard).
function Find-EnvByDisplayName([string]$displayName) {
  Get-AdminPowerAppEnvironment | Where-Object { $_.DisplayName -eq $displayName } | Select-Object -First 1
}

# --- Environments ------------------------------------------------------------
# The default environment already exists; adopt it as "Halcourt (default)" — do NOT recreate it.
$defaultEnv = Get-AdminPowerAppEnvironment -Default   # [verify] -Default switch returns the tenant default env
if ($defaultEnv) {
  Write-Host "Adopting existing default environment as 'Halcourt (default)': $($defaultEnv.EnvironmentName)"
  # [verify] Optional cosmetic rename; canon only requires we reference it, so keep this best-effort.
  try {
    Set-AdminPowerAppEnvironmentDisplayName -EnvironmentName $defaultEnv.EnvironmentName `
      -NewDisplayName 'Halcourt (default)' -ErrorAction SilentlyContinue | Out-Null
  } catch { Write-Host "  (skipped rename of default env: $($_.Exception.Message))" }
} else {
  Write-Host '[verify] Could not resolve the tenant default environment — confirm one exists (Phase 0/2).'
}

# Environments to create. WithDatabase => provision a Dataverse (CDS) database at create time.
#   Halcourt-Prod : Production, Managed, DB (hosts Dataverse-backed prod agents)
#   Claims-Test   : Sandbox, DB (Phase 5 needs its *.crm.dynamics.com org URL)
#   Maker-Sandbox : Developer, NO DB (canon: shadow-agent origin, personal productivity)
$envs = @(
  @{ Name='Halcourt-Prod'; Sku='Production'; Managed=$true;  WithDatabase=$true  }
  @{ Name='Claims-Test';   Sku='Sandbox';    Managed=$false; WithDatabase=$true  }
  @{ Name='Maker-Sandbox'; Sku='Developer';  Managed=$false; WithDatabase=$false }
)

$created = @{}   # DisplayName -> environment object
foreach ($e in $envs) {
  $existing = Find-EnvByDisplayName $e.Name
  if ($existing) {
    Write-Host "Environment '$($e.Name)' already exists ($($existing.EnvironmentName)) — skipping create."
    $created[$e.Name] = $existing
    continue
  }

  Write-Host "Creating environment '$($e.Name)' (Sku=$($e.Sku), Database=$($e.WithDatabase))"
  # [verify] exact params for New-AdminPowerAppEnvironment in the delivery-date module version.
  $params = @{
    DisplayName    = $e.Name
    LocationName   = $Location
    EnvironmentSku = $e.Sku
  }
  if ($e.WithDatabase) {
    # -ProvisionDatabase spins up Common Data Service / Dataverse; required for a *.crm.dynamics.com org URL.
    $params['ProvisionDatabase'] = $true
    $params['CurrencyName']      = $CurrencyName
    $params['LanguageName']      = $LanguageName
  }
  $new = New-AdminPowerAppEnvironment @params
  $created[$e.Name] = $new
}

# --- Wait for Dataverse provisioning, then resolve org URLs ------------------
# DB provisioning is async; poll until each DB-bearing env reports an instanceUrl (or we time out).
$deadline = (Get-Date).AddMinutes($ProvisionTimeoutMinutes)
foreach ($e in $envs | Where-Object { $_.WithDatabase }) {
  $envObj = $created[$e.Name]
  if (-not $envObj) { continue }
  $url = Get-EnvInstanceUrl $envObj
  while (-not $url -and (Get-Date) -lt $deadline) {
    Start-Sleep -Seconds 30
    # [verify] refresh the env object to pick up the freshly-linked CDS metadata.
    $envObj = Get-AdminPowerAppEnvironment -EnvironmentName $envObj.EnvironmentName
    $created[$e.Name] = $envObj
    $url = Get-EnvInstanceUrl $envObj
    Write-Host "  waiting on Dataverse for '$($e.Name)'..."
  }
  if ($url) { Write-Host "  '$($e.Name)' org URL: $url" }
  else { Write-Host "  [verify] '$($e.Name)' has no org URL yet — check PPAC; provisioning may still be running." }
}

# Mark Halcourt-Prod as a Managed Environment.
$prodEnv = $created['Halcourt-Prod']
if ($prodEnv) {
  Write-Host "Marking Halcourt-Prod as a Managed Environment: $($prodEnv.EnvironmentName)"
  try {
    # [verify] cmdlet/param name for enabling managed environment governance in the delivery-date module.
    Set-AdminPowerAppEnvironmentGovernanceConfiguration `
      -EnvironmentName $prodEnv.EnvironmentName `
      -ProtectionLevel Standard -ErrorAction Stop | Out-Null
  } catch {
    Write-Host "  [verify] Enable Managed Environments on Halcourt-Prod via PPAC (or pac admin) — cmdlet path unconfirmed: $($_.Exception.Message)"
  }
}

# --- DLP: PROD ONLY ----------------------------------------------------------
# Baseline business/non-business connector split applied to Halcourt-Prod ONLY.
# Default / Claims-Test / Maker-Sandbox INTENTIONALLY stay open (planted gap for Module 5) — do NOT add DLP.
$dlpName = 'Halcourt-Prod-DLP'
if (-not $prodEnv) {
  Write-Host "[verify] Halcourt-Prod not resolved — cannot scope DLP. Create the env first, then re-run."
} else {
  $existingDlp = Get-DlpPolicy -ErrorAction SilentlyContinue | Where-Object { $_.displayName -eq $dlpName }
  if ($existingDlp) {
    Write-Host "DLP policy '$dlpName' already exists — leaving it in place."
  } else {
    Write-Host "Creating '$dlpName' (business/non-business split), scoped to Halcourt-Prod only."
    # New-DlpPolicy seeds a policy; we then classify connectors and scope it to the single Prod env.
    $policy = New-DlpPolicy -DisplayName $dlpName    # [verify] New-DlpPolicy DisplayName param in delivery-date module

    # Business group: Dataverse, SharePoint, Office 365 Outlook, Office 365 Users.
    # Everything else falls to the default (non-business) group -> can't share data with Business connectors.
    # [verify] connectorGroups schema (classification names 'Confidential'/'General'/'Blocked') and connector IDs.
    $businessConnectors = @(
      @{ id = '/providers/Microsoft.PowerApps/apis/shared_commondataserviceforapps'; name = 'Dataverse' }
      @{ id = '/providers/Microsoft.PowerApps/apis/shared_sharepointonline';         name = 'SharePoint' }
      @{ id = '/providers/Microsoft.PowerApps/apis/shared_office365';                 name = 'Office 365 Outlook' }
      @{ id = '/providers/Microsoft.PowerApps/apis/shared_office365users';            name = 'Office 365 Users' }
    )
    foreach ($grp in $policy.connectorGroups) {
      if ($grp.classification -eq 'Confidential') { $grp.connectors = $businessConnectors }  # Business
    }

    # Scope: this environment ONLY.
    $policy.environmentType = 'OnlyEnvironments'    # [verify] enum value for single-environment scoping
    $policy.environments = @(@{
      name = $prodEnv.EnvironmentName
      id   = $prodEnv.EnvironmentName
      type = 'Microsoft.BusinessAppPlatform/scopes/environments'
    })

    Set-DlpPolicy -PolicyName $policy.name -UpdatedPolicy $policy | Out-Null   # [verify] -PolicyName/-UpdatedPolicy param names
    Write-Host "  '$dlpName' applied to Halcourt-Prod ($($prodEnv.EnvironmentName))."
  }
}
Write-Host 'DEALER''S CHOICE for Module 5: leave any HTTP/custom-connector *block* OFF at start so Scenario E fires,'
Write-Host 'then have attendees tighten it (block HTTP / custom connectors in Prod) during Module 5 and retest.'
Write-Host 'DO NOT create DLP for Halcourt (default), Claims-Test, or Maker-Sandbox — that gap is a planted Module 5 finding.'

# --- Conditional Access baseline (MANUAL — not this PowerShell surface) -------
# CA policies are NOT created via the Power Platform admin cmdlets; author them in Entra (Graph/portal).
Write-Host '[verify] MANUAL: In Entra ID, create CA baseline: CA-Require-MFA-Admins, CA-Block-Legacy-Auth.'
Write-Host '[verify] MANUAL: Deliberately DO NOT create any CA policy targeting workload/agent identities — that gap is a Module 5 finding.'

# --- Summary block: hand these to Phase 5 ------------------------------------
Write-Host ''
Write-Host '================ Phase 3 environment summary ================'
$summary = foreach ($name in @('Halcourt (default)') + ($envs | ForEach-Object { $_.Name })) {
  $obj = if ($name -eq 'Halcourt (default)') { $defaultEnv } else { $created[$name] }
  [pscustomobject]@{
    Environment   = $name
    EnvironmentId = if ($obj) { $obj.EnvironmentName } else { '(unresolved)' }
    OrgUrl        = if ($obj) { (Get-EnvInstanceUrl $obj) } else { $null }
    DLP           = if ($name -eq 'Halcourt-Prod') { $dlpName } else { '(none — intentional)' }
  }
}
$summary | Format-Table -AutoSize

$claimsTest = $created['Claims-Test']
$claimsUrl  = if ($claimsTest) { Get-EnvInstanceUrl $claimsTest } else { $null }
if ($claimsUrl) {
  Write-Host ''
  Write-Host 'Phase 5 (04_provision_dataverse.ps1) — pass this Claims-Test org URL:'
  Write-Host "  pwsh setup/scripts/04_provision_dataverse.ps1 -ClaimsTestEnvUrl $claimsUrl"
} else {
  Write-Host ''
  Write-Host '[verify] Claims-Test org URL not available yet. Once Dataverse finishes provisioning, read the'
  Write-Host '         instanceUrl from PPAC (or Get-AdminPowerAppEnvironment) and pass it to Phase 5.'
}

Write-Host 'Phase 3 complete.'
