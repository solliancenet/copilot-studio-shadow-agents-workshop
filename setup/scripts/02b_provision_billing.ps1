<#
FACILITATOR-ONLY. Phase 3 - Copilot Studio pay-as-you-go billing.

Links this estate's Halcourt-Prod and Claims-Test to a Power Platform PAYG billing plan in THEIR region, so
attendees can send messages to the agents. Publishing an agent works without a plan; runtime message
consumption needs one. Maker-Sandbox (a Developer environment) cannot be linked and does not need to be -
its agents run without a plan.

Estates in one tenant SHARE a plan per region (it is just an Azure meter; each environment's usage is
reported separately). So this finds a plan in the environments' region with the Copilot Studio meter on and
links to it, whatever its name (a Dev Program tenant may already have one, e.g. ppccdevcanada); if none
exists it creates the once-per-region plan - a Microsoft.PowerPlatform/accounts Azure resource plus a billing
policy - then links. A plan it creates is SHARED, so its names carry the region, never an estate id: resource
group rg-halcourt-billing, account ppcc-halcourt-<region>, plan Halcourt-PAYG-<region>. No estate owns it, and
estate teardown (99) only unlinks.

Reuses az's sign-in for both ARM and api.powerplatform.com (no device code). Region-lock: a plan only lists
environments in its own region, so the plan region must match where Phase 3 put the environments (a macro
region like "north-america" auto-lands in e.g. "canada"). Safe to re-run.

Lines marked [verify] are the create-a-new-plan path, unconfirmed on a tenant that already had a plan.
#>
param(
  [string]$Estate = $env:HALCOURT_ESTATE,               # this build's estate id, e.g. jsmith (see _estate.ps1)
  [string]$SubscriptionId,                              # default: az's current subscription
  [string]$ResourceGroup = 'rg-halcourt-billing',       # shared by every estate: no estate id
  [string]$ResourceGroupLocation = 'eastus',            # AZURE region for the RG; unrelated to the plan's region
  [string]$PlanName                                     # default: Halcourt-PAYG-<region> (shared)
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_estate.ps1')
$Estate = Resolve-Estate $Estate
$PP  = 'https://api.powerplatform.com'
$BAP = 'https://api.bap.microsoft.com'
$api = 'api-version=2022-03-01-preview'

# az rest wrapper: a body goes through a temp file (the same pattern as 04_provision_dataverse.ps1, and it
# keeps quoting out of the picture). $azArgs, not $args - $args is a PowerShell automatic variable.
function Invoke-Rest([string]$Method, [string]$Url, [string]$Resource, $Body) {
  $azArgs = @('rest', '--method', $Method, '--url', $Url, '--resource', $Resource)
  $bodyFile = $null
  if ($null -ne $Body) {
    $bodyFile = New-TemporaryFile
    ($Body | ConvertTo-Json -Depth 20) | Set-Content $bodyFile -Encoding utf8
    $azArgs += @('--headers', 'Content-Type=application/json', '--body', "@$bodyFile")
  }
  $errFile = New-TemporaryFile
  $out  = az @azArgs 2> $errFile
  $code = $LASTEXITCODE
  $err  = Get-Content $errFile -Raw
  Remove-Item $errFile -ErrorAction SilentlyContinue
  if ($bodyFile) { Remove-Item $bodyFile -ErrorAction SilentlyContinue }
  if ($code) { throw "$Method $Url failed: $err" }
  $text = ($out | Out-String).Trim()
  if ($text) { $text | ConvertFrom-Json }
}

if (-not $SubscriptionId) { $SubscriptionId = az account show --query id -o tsv }
Write-Host "Estate: $Estate   Subscription: $SubscriptionId"

# --- Resolve this estate's Prod + Claims-Test and their region ------------------------------------------
$envs = (Invoke-Rest GET "$BAP/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2021-04-01" 'https://service.powerapps.com/').value
$targets = @()
foreach ($canon in 'Halcourt-Prod', 'Claims-Test') {
  $name = Get-EstateName $canon $Estate
  $e = $envs | Where-Object { $_.properties.displayName -eq $name } | Select-Object -First 1
  if (-not $e) { throw "Environment '$name' not found - run Phase 3 first." }
  $targets += [pscustomobject]@{ Name = $name; Id = $e.name; Region = $e.location }
}
$region = $targets[0].Region
if ($targets.Region | Where-Object { $_ -ne $region }) { throw "Prod and Claims-Test are in different regions - link them to separate plans." }
if (-not $PlanName) { $PlanName = "Halcourt-PAYG-$region" }
Write-Host "Linking to a '$region' plan: $($targets.Name -join ', ')"

# --- Find a plan in that region with the Copilot Studio (MCSMessages) meter on --------------------------
# Prefer the kit's own Halcourt-PAYG-<region>; otherwise the region's one MCS-metered plan. More than one
# (e.g. a legacy per-estate plan beside the Dev Program's) is reported: estates should share ONE.
function Get-McsPlan([string]$Region) {
  $policies = @((Invoke-Rest GET "$PP/licensing/billingPolicies?$api" $PP).value | Where-Object {
    $_.location -eq $Region -and ($_.payGoEntitlements | Where-Object { $_.entitlementId -eq 'MCSMessages' -and $_.payAsYouGoState }) })
  if ($policies.Count -gt 1) { Write-Warning "$($policies.Count) Copilot Studio plans in '$Region' ($($policies.name -join ', ')) - estates should share one; linking to $((@($policies | Where-Object name -eq $PlanName) + $policies)[0].name)." }
  (@($policies | Where-Object name -eq $PlanName) + $policies) | Select-Object -First 1
}
$plan = Get-McsPlan $region
# Phase 3 creates Prod and Claims-Test ON a plan (capacity); keep that link rather than move them to another.
foreach ($p in @((Invoke-Rest GET "$PP/licensing/billingPolicies?$api" $PP).value | Where-Object { $_.location -eq $region })) {
  $ids = @((Invoke-Rest GET "$PP/licensing/billingPolicies/$($p.id)/environments?$api" $PP).value.environmentId)
  if ($targets.Id | Where-Object { $_ -in $ids }) { $plan = $p; break }
}
# A kit plan whose Copilot Studio meter isn't on (yet) isn't matched above; re-use it rather than POST a
# second plan with the same name.
if (-not $plan) {
  $plan = (Invoke-Rest GET "$PP/licensing/billingPolicies?$api" $PP).value | Where-Object { $_.location -eq $region -and $_.name -eq $PlanName } | Select-Object -First 1
  if ($plan) { Write-Warning "Plan $PlanName exists but its Copilot Studio meter is off - turn it on in PPAC (Licensing -> Billing Plans)." }
}

if (-not $plan) {
  # [verify] Once-per-region setup, untested here because the tenant already had a plan. A plan is two
  # objects: a Microsoft.PowerPlatform/accounts ARM resource (the Azure meter) and the billing policy that
  # points at the resource group holding it.
  Write-Host "No '$region' plan found - creating one (once-per-region setup)."

  # The resource group is ordinary Azure: its location is metadata and need NOT match the plan's region.
  az group show -n $ResourceGroup --subscription $SubscriptionId -o none 2>$null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "  creating resource group $ResourceGroup in $ResourceGroupLocation"
    az group create -n $ResourceGroup -l $ResourceGroupLocation --subscription $SubscriptionId -o none
  }

  # The ARM account takes the Power Platform region TITLE-CASED ('Canada'); the billing policy below takes
  # the same region lower-case ('canada'). They really are spelled differently.
  $accountName = "ppcc-halcourt-$region"
  $accountUrl  = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup" +
                 "/providers/Microsoft.PowerPlatform/accounts/$accountName" + '?api-version=2020-10-30-preview'
  Invoke-Rest PUT $accountUrl 'https://management.azure.com/' @{
    location = (Get-Culture).TextInfo.ToTitleCase($region)
  } | Out-Null

  $plan = Invoke-Rest POST "$PP/licensing/billingPolicies?$api" $PP @{
    name = $PlanName; location = $region; status = 'Enabled'
    billingInstrument = @{ resourceGroup = $ResourceGroup; subscriptionId = $SubscriptionId }
  }
  if (-not $plan) { $plan = Get-McsPlan $region }
  if (-not $plan) { throw "Created the plan but could not read it back - check PPAC (Licensing -> Billing Plans)." }
}
Write-Host "Plan: $($plan.name) ($($plan.id), $($plan.location))"

# --- Protect the plan's resource group -----------------------------------------------------------------
# Every estate in the region bills through this group, and a Dev Program tenant's plan sits in a group with a
# generated name (rg-<number>) that says nothing about the workshop. Tag it and lock it against deletion
# (CanNotDelete: updates still work, so linking environments is unaffected). A lock needs Owner or User
# Access Administrator; with Contributor alone this warns and carries on.
$bi = $plan.billingInstrument
if ($bi.resourceGroup -and $bi.subscriptionId) {
  az group update -n $bi.resourceGroup --subscription $bi.subscriptionId --set tags.halcourt-shared='Copilot Studio billing plan - every estate in the tenant' -o none 2>$null
  if ($LASTEXITCODE) { Write-Warning "Could not tag resource group $($bi.resourceGroup)." }
  # lock create is an idempotent PUT; its own error says why it failed (role, or a subscription az can't see).
  $err = az lock create --name halcourt-shared-billing --lock-type CanNotDelete -g $bi.resourceGroup --subscription $bi.subscriptionId `
    --notes 'Shared Copilot Studio billing plan (ADR-0014). Remove only when the tenant is retired.' -o none 2>&1
  if ($LASTEXITCODE) { Write-Warning "Could not lock resource group $($bi.resourceGroup): $(($err | Out-String).Trim().Split([char]10)[0]) - a lock needs Owner or User Access Administrator." }
  else { Write-Host "  $($bi.resourceGroup) locked against deletion (halcourt-shared-billing)" }
}

# --- Link the two environments --------------------------------------------------------------------------
$linked = (Invoke-Rest GET "$PP/licensing/billingPolicies/$($plan.id)/environments?$api" $PP).value.environmentId
$toAdd = @($targets | Where-Object { $_.Id -notin $linked })
if ($toAdd) {
  Invoke-Rest POST "$PP/licensing/billingPolicies/$($plan.id)/environments/add?$api" $PP @{ environmentIds = @($toAdd.Id) } | Out-Null
  Write-Host "Linked: $($toAdd.Name -join ', ')"
} else {
  Write-Host "Already linked: $($targets.Name -join ', ')"
}

# --- Verify ---------------------------------------------------------------------------------------------
Start-Sleep 3
$now = (Invoke-Rest GET "$PP/licensing/billingPolicies/$($plan.id)/environments?$api" $PP).value.environmentId
Write-Host ""
Write-Host "================ Phase 3 billing summary ================"
foreach ($t in $targets) {
  $ok = if ($t.Id -in $now) { 'linked' } else { 'NOT linked' }
  "{0,-22} {1,-40} {2}" -f $t.Name, $t.Id, $ok | Write-Host
}
Write-Host "Plan '$($plan.name)' ($region). Maker-Sandbox is a Developer env - not linkable, not needed."
Write-Host "Phase 3 billing complete."
