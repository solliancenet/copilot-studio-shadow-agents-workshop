<#
FACILITATOR-ONLY. Phase 3 - Environments and DLP.

Creates this estate's three environments and applies DLP to PROD ONLY. Deliberately leaves Default /
Claims-Test / Maker-Sandbox WITHOUT DLP, and creates NO Conditional Access policy targeting workload/agent
identities - those omissions drive Exercise 05. The CA baseline already exists: Phase 0 created it
(00_conditional_access_baseline.ps1), because security defaults block the device-code sign-ins used here.

  Halcourt-Prod-<estate>  Production + Dataverse, Managed Environment, Halcourt-Prod-DLP-<estate>
  Claims-Test-<estate>    Sandbox + Dataverse (Phase 5 seeds it)
  Maker-Sandbox-<estate>  Developer + Dataverse, assigned to dev.kim.<estate> (his personal environment;
                          Developer environments always come with Dataverse, and its agents need it)
  Halcourt (default)      the tenant's default environment - shared by every estate; named once

Runs anywhere az is signed in to the lab tenant - the dev container, the host, or Windows - with no new
sign-in: everything goes through the Power Platform admin API with az's saved token. It uses no PowerApps
admin module (it can no longer create environments and only signs in on Windows) and no `pac admin create`
(pac caches a token only for the resource it signed in for, so creating fails with "No token cache item
found ... service.powerapps.com").

REGION (verified 2026-09-18): the API no longer takes a country. It requires a MACRO REGION
(-MacroRegion north-america) and picks the country itself - `location` alone is rejected
(MacroRegionRequired), both together are rejected, and properties.azureRegion is ignored. That tenant got
Canada for every environment. So create the PAYG billing plan in whatever region the summary below reports -
billing plans are region-locked and won't list environments from another region.

Estate (setup/scripts/_estate.ps1): pass -Estate or set HALCOURT_ESTATE. Safe to re-run: environments and
the DLP policy that already exist are reported, not recreated.
#>
param(
  [string]$Estate = $env:HALCOURT_ESTATE,      # this build's estate id, e.g. jsmith (see _estate.ps1)
  [string]$MacroRegion = 'north-america',      # asia-pacific, emea, eu-efta, europe-uk, north-america, the-americas
  [string]$CurrencyName = 'USD',
  [int]$LanguageCode = 1033,                   # 1033 = English
  [int]$ProvisionTimeoutMinutes = 30
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_estate.ps1')
$Estate = Resolve-Estate $Estate
Write-Host "Estate: $Estate"

# --- Power Platform admin API through az (its saved sign-in; no extra prompt) -------------------------
$bap = 'https://api.bap.microsoft.com'
$envApi = "$bap/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments"
function Invoke-Bap([string]$Method, [string]$Url, $Body) {
  $azArgs = @('rest', '--method', $Method, '--url', $Url, '--resource', 'https://service.powerapps.com/')
  if ($Body) {
    $file = New-TemporaryFile
    $Body | ConvertTo-Json -Depth 10 | Set-Content -Path $file -Encoding utf8
    $azArgs += @('--body', "@$file", '--headers', 'Content-Type=application/json')
  }
  $out = az @azArgs
  if ($Body) { Remove-Item $file }
  if ($LASTEXITCODE) { throw "Power Platform admin API $Method $Url failed (az exit $LASTEXITCODE) - is az signed in to the lab tenant?" }
  if ($out) { $out | ConvertFrom-Json }
}
function Get-Environments { @((Invoke-Bap GET "$envApi`?api-version=2021-04-01&`$expand=properties.createdBy").value) }
function Find-Env([string]$DisplayName) { Get-Environments | Where-Object { $_.properties.displayName -eq $DisplayName } | Select-Object -First 1 }
# The API often returns only the creator's object id; resolve it so a clash names a person.
function Get-Creator($Environment) {
  $by = $Environment.properties.createdBy
  if ($by.displayName) { return $by.displayName }
  if ($by.id) { $upn = az ad user show --id $by.id --query userPrincipalName -o tsv 2>$null; if ($upn) { return $upn } }
  return 'unknown'
}

$tenant = az account show --query tenantId -o tsv
if ($LASTEXITCODE -or -not $tenant) { throw 'az is not signed in (Phase 0, step 5).' }
$domain = (az rest --method GET --url 'https://graph.microsoft.com/v1.0/organization?$select=verifiedDomains' `
  --query "value[0].verifiedDomains[?isDefault].name | [0]" -o tsv)
Write-Host "Tenant: $tenant ($domain)"

# --- The shared default environment -----------------------------------------------------------------
$default = Get-Environments | Where-Object { $_.properties.environmentSku -eq 'Default' } | Select-Object -First 1
if (-not $default) { throw 'Could not find the tenant default environment.' }
if ($default.properties.displayName -eq 'Halcourt (default)') {
  Write-Host "Default environment already named 'Halcourt (default)' ($($default.name))."
} else {
  Write-Host "Naming the shared default environment 'Halcourt (default)' (was '$($default.properties.displayName)')."
  Invoke-Bap PATCH "$envApi/$($default.name)?api-version=2021-04-01" @{ properties = @{ displayName = 'Halcourt (default)' } } | Out-Null
}

# --- This estate's environments ---------------------------------------------------------------------
# Name = canonical (AGENTS.md); Live = what this estate creates in the tenant.
$envs = @(
  @{ Name = 'Halcourt-Prod'; Sku = 'Production' }
  @{ Name = 'Claims-Test';   Sku = 'Sandbox' }
  @{ Name = 'Maker-Sandbox'; Sku = 'Developer'; Owner = 'dev.kim' }
)
$createUri = "$bap/providers/Microsoft.BusinessAppPlatform/environments?api-version=2021-04-01&id=/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments"
foreach ($e in $envs) {
  $e.Live = Get-EstateName $e.Name $Estate
  $existing = Find-Env $e.Live
  if ($existing) {
    # Same estate id = same names: say whose it is, so a clash with someone else's estate is visible.
    Write-Host "Environment '$($e.Live)' already exists ($($existing.name), created by $(Get-Creator $existing)) - leaving it."
    continue
  }
  $props = @{
    displayName               = $e.Live
    environmentSku            = $e.Sku
    databaseType              = 'CommonDataService'
    linkedEnvironmentMetadata = @{ baseLanguage = $LanguageCode; currency = @{ code = $CurrencyName }; templates = @() }
  }
  if ($e.Owner) {
    # A Developer environment belongs to one user: this estate's persona, not the admin running the script.
    $ownerUpn = "$(Get-EstateAlias $e.Owner $Estate)@$domain"
    $ownerId = az ad user show --id $ownerUpn --query id -o tsv
    if ($LASTEXITCODE -or -not $ownerId) { throw "$ownerUpn not found - run Phase 2 first." }
    $props.usedBy = @{ id = $ownerId; type = 'User'; tenantId = $tenant }
  }
  Write-Host "Creating '$($e.Live)' ($($e.Sku) + Dataverse$(if ($e.Owner) { ", for $ownerUpn" }), macro region $MacroRegion)..."
  Invoke-Bap POST $createUri @{ macroRegion = $MacroRegion; properties = $props } | Out-Null
}

# Provisioning is asynchronous: wait until every estate environment has its Dataverse org.
$created = @{}   # canonical name -> environment
$deadline = (Get-Date).AddMinutes($ProvisionTimeoutMinutes)
do {
  $all = Get-Environments
  foreach ($e in $envs) {
    $en = $all | Where-Object { $_.properties.displayName -eq $e.Live } | Select-Object -First 1
    if ($en.properties.linkedEnvironmentMetadata.instanceUrl) { $created[$e.Name] = $en }
  }
  if ($created.Count -lt $envs.Count) { Write-Host "  waiting on Dataverse ($($created.Count)/$($envs.Count) ready)..."; Start-Sleep -Seconds 20 }
} while ($created.Count -lt $envs.Count -and (Get-Date) -lt $deadline)
if ($created.Count -lt $envs.Count) { throw "Not all environments were ready after $ProvisionTimeoutMinutes minutes - check PPAC, then re-run." }

# One region for the whole estate: the PAYG billing plan can only link environments in its own region.
$regions = @($created.Values | ForEach-Object { $_.location } | Sort-Object -Unique)
if ($regions.Count -gt 1) {
  Write-Warning "This estate's environments landed in different regions ($($regions -join ', ')). A billing plan links only one region - recreate the odd one out."
}

# --- Managed Environment: Prod ----------------------------------------------------------------------
$prod = $created['Halcourt-Prod']
if ($prod.properties.governanceConfiguration.protectionLevel -eq 'Standard') {
  Write-Host "$($prod.properties.displayName) is already a Managed Environment."
} else {
  Write-Host "Making $($prod.properties.displayName) a Managed Environment..."
  Invoke-Bap POST "$bap/providers/Microsoft.BusinessAppPlatform/environments/$($prod.name)/governanceConfiguration?api-version=2021-04-01" @{ protectionLevel = 'Standard' } | Out-Null
}

# --- DLP: PROD ONLY ---------------------------------------------------------------------------------
# Baseline business/non-business connector split on this estate's Prod ONLY. Default / Claims-Test /
# Maker-Sandbox INTENTIONALLY stay open (planted gap for Exercise 05) - do NOT add DLP.
$dlpName = Get-EstateName 'Halcourt-Prod-DLP' $Estate
$policyApi = "$bap/providers/PowerPlatform.Governance/v1/policies"
$existingDlp = @((Invoke-Bap GET "$policyApi`?api-version=2016-11-01").value) | Where-Object { $_.displayName -eq $dlpName } | Select-Object -First 1
if ($existingDlp) {
  # A policy with this name can outlive the environment it was scoped to (a torn-down estate leaves the
  # policy behind, and the rebuilt Prod has a NEW id). Matching on the name alone then "leaves it" pointing
  # at an environment that no longer exists - and the new Prod silently ends up with no DLP at all. So check
  # what it actually targets, and re-scope it if it is stale.
  $full = Invoke-Bap GET "$policyApi/$($existingDlp.name)?api-version=2016-11-01"
  $targets = @($full.environments | ForEach-Object { $_.name })
  if ($targets -contains $prod.name) {
    Write-Host "DLP policy '$dlpName' already exists and targets $($prod.properties.displayName) - leaving it."
  } else {
    Write-Host "DLP policy '$dlpName' exists but targets [$($targets -join ', ')] - re-scoping it to $($prod.properties.displayName)."
    $full.environments = @(@{
      id   = "/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/$($prod.name)"
      name = $prod.name
      type = 'Microsoft.BusinessAppPlatform/scopes/environments'
    })
    Invoke-Bap PATCH "$policyApi/$($existingDlp.name)?api-version=2016-11-01" $full | Out-Null
    Write-Host "  '$dlpName' now applies to $($prod.properties.displayName)."
  }
} else {
  Write-Host "Creating '$dlpName' (business-grouped connectors), scoped to $($prod.properties.displayName) only."
  # Business (Confidential): the sensitive data connectors, PLUS the Copilot Studio platform connector.
  # defaultConnectorsClassification is 'Confidential' (business-by-default) DELIBERATELY: a business/
  # non-business SPLIT cannot coexist with publishing connector-based Copilot Studio agents - every agent
  # implicitly pulls in platform connectors, and if any land in the non-business bucket the publish fails
  # with "conflict between business and non-business connectors" (verified 2026-09-21; see errata). So the
  # baseline groups the sensitive connectors as business and treats everything as business by default,
  # blocking nothing. It still demonstrates a DLP control on Prod that MISSES the agent-identity risks
  # (Exercise 05), which is the point. Default / Claims-Test / Maker-Sandbox still get NO DLP.
  $business = foreach ($c in @(
      @('shared_commondataserviceforapps', 'Microsoft Dataverse'),
      @('shared_sharepointonline',         'SharePoint'),
      @('shared_office365',                'Office 365 Outlook'),
      @('shared_office365users',           'Office 365 Users'),
      @('shared_conversionservice',        'Content Conversion (Copilot Studio)'))) {
    @{ id = "/providers/Microsoft.PowerApps/apis/$($c[0])"; name = $c[1]; type = 'Microsoft.PowerApps/apis' }
  }
  $policy = @{
    displayName                     = $dlpName
    defaultConnectorsClassification = 'Confidential'
    environmentType                 = 'OnlyEnvironments'
    environments                    = @(@{
      id   = "/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/$($prod.name)"
      name = $prod.name
      type = 'Microsoft.BusinessAppPlatform/scopes/environments'
    })
    connectorGroups                 = @(
      @{ classification = 'Confidential'; connectors = @($business) }
      @{ classification = 'General';      connectors = @() }
      @{ classification = 'Blocked';      connectors = @() }
    )
  }
  Invoke-Bap POST "$policyApi`?api-version=2016-11-01" $policy | Out-Null
  Write-Host "  '$dlpName' applied to $($prod.properties.displayName)."
}
Write-Host "DEALER'S CHOICE for Exercise 05: leave any HTTP/custom-connector *block* OFF at start so Scenario E fires,"
Write-Host 'then the facilitator demonstrates tightening it (block HTTP / custom connectors in Prod) in Exercise 05 and retests.'
Write-Host "DO NOT create DLP for Halcourt (default), $(Get-EstateName 'Claims-Test' $Estate), or $(Get-EstateName 'Maker-Sandbox' $Estate) - that gap is a planted Exercise 05 finding."

# --- Conditional Access -----------------------------------------------------------------------------
Write-Host 'Conditional Access: baseline created in Phase 0 (00_conditional_access_baseline.ps1).'
Write-Host 'Deliberately DO NOT create any CA policy targeting workload/agent identities - that gap is an Exercise 05 finding.'

# --- Summary: hand these to Phase 5 -----------------------------------------------------------------
Write-Host ''
Write-Host '================ Phase 3 environment summary ================'
$all = Get-Environments
@($default.name) + @($created.Values | ForEach-Object { $_.name }) | ForEach-Object {
  $id = $_
  $en = $all | Where-Object { $_.name -eq $id }
  [pscustomobject]@{
    Environment = $en.properties.displayName
    Type        = $en.properties.environmentSku
    Region      = $en.location
    Managed     = if ($en.properties.governanceConfiguration.protectionLevel -eq 'Standard') { 'Yes' } else { 'No' }
    OrgUrl      = $en.properties.linkedEnvironmentMetadata.instanceUrl
    Id          = $en.name
  }
} | Format-Table -AutoSize | Out-String | Write-Host

$claimsUrl = ($all | Where-Object { $_.name -eq $created['Claims-Test'].name }).properties.linkedEnvironmentMetadata.instanceUrl
Write-Host "Phase 5 seeds $($created['Claims-Test'].properties.displayName) ($claimsUrl):"
Write-Host "  pwsh setup/scripts/04_provision_dataverse.ps1 -Estate $Estate"
Write-Host "Phase 3 complete. Next: the PAYG billing plan (RUNBOOK Phase 3) in region '$($regions -join ', ')', linking $($created['Halcourt-Prod'].properties.displayName) and $($created['Claims-Test'].properties.displayName)."
