<#
FACILITATOR-ONLY. Phase 8c - per-student slices, so every attendee can do Module 5 hands-on.

Module 5 asks attendees to APPLY controls - a scoped Dataverse role, row-level security, a DLP policy,
orphan remediation - and then retest. Those are environment-scoped changes: the first attendee to enable
row-level security removes the "before" state for everyone else, and the exercise's whole method is that
each attendee reaches their own CLOSES IT / DENTS IT / MISSES IT verdict. One shared estate cannot carry
that. This script gives each attendee an environment of their own with a vulnerable slice in it.

WHAT MAKES THIS AFFORDABLE. Two facts, both verified live 2026-10-13:

  - Dataverse security roles and row-level security are PER ENVIRONMENT. The same shared `svc-claims` can
    hold the over-broad role in one attendee's environment and a scoped role in another's at the same
    time, so the slices need NO new licences. The tenant has 25 E5 seats and none free, which is what
    rules out giving each attendee a whole estate.
  - The BAP admin `addUser` endpoint adds an account to an environment regardless of licensing, which is
    how `svc-claims` gets into a fresh environment at all (Dataverse's own path refuses with
    userNotLicensed).

WHAT THIS BUILDS, PER ATTENDEE (slice = one environment, not a whole estate):

  1. environment `Lab-<estate>-NN` (Sandbox + Dataverse), in the estate's macro region;
  2. linked to the estate's PAYG billing policy, or agents in it cannot publish;
  3. `svc-claims` added, then the Phase 5 seed run into it - Claim and Customer with PII rows, and the
     over-broad `svc-claims Dataverse Full Access` role assigned. That is Scenario C/D's substrate;
  4. the attendee added as System Administrator OF THEIR OWN environment, so they can create roles,
     enable row-level security and remediate - none of which they can do in the shared estate.

NOT YET BUILT HERE - the slice is not complete until these land:
  - the SharePoint site + grounding document (Benefits-Buddy-shaped agent);
  - the two agents, including the orphaned-connection agent owned by the disabled `tom.dean`.
Both need a per-environment override in `03_provision_sharepoint.ps1` and `06_provision_agents.ps1`.

  pwsh setup/scripts/08_provision_student_slices.ps1 -Count 20
  pwsh setup/scripts/08_provision_student_slices.ps1 -Destroy

Safe to re-run: an environment that already exists is reused and its seed re-applied (Phase 5 is
idempotent). ASCII only.
#>
param(
  [int]$Count         = 1,                       # how many attendee slices
  [string]$Estate     = $env:HALCOURT_ESTATE,
  [string]$Prefix     = 'Lab',                   # environment name: <Prefix>-<estate>-NN
  [string]$MacroRegion = 'north-america',        # must match the billing policy's region (see Phase 3)
  [string]$StudentPrefix = 'student',            # attendee accounts from 07_provision_lab_users.ps1
  [string]$BillingPolicyId,                      # default: the policy that already covers the estate's Prod
  [switch]$SkipSeed,                             # environment + billing only
  [switch]$Destroy,
  [switch]$Force                                 # -Destroy without the confirmation prompt
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_estate.ps1')
$Estate = Resolve-Estate $Estate

$BAP = 'https://api.bap.microsoft.com'
$PP  = 'https://api.powerplatform.com'
$script:Tokens = @{}
function Get-AdminToken([string]$r) { if (-not $script:Tokens[$r]) { $script:Tokens[$r] = az account get-access-token --resource $r --query accessToken -o tsv }; $script:Tokens[$r] }
function Invoke-Api([string]$m, [string]$url, [string]$resource, $body) {
  $h = @{ Authorization = "Bearer $(Get-AdminToken $resource)"; Accept = 'application/json' }
  if ($null -ne $body) { Invoke-RestMethod -Method $m -Uri $url -Headers $h -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 20) }
  else                 { Invoke-RestMethod -Method $m -Uri $url -Headers $h }
}
function Get-Environments { (Invoke-Api GET "$BAP/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2021-04-01" 'https://service.powerapps.com/' $null).value }
function Get-SliceName([int]$N) { "{0}-{1}-{2:d2}" -f $Prefix, $Estate, $N }

function Get-DomainSuffix {
  az rest --method GET --url 'https://graph.microsoft.com/v1.0/organization?$select=verifiedDomains' `
    --query "value[0].verifiedDomains[?isDefault].name | [0]" -o tsv
}
$DomainSuffix = Get-DomainSuffix

# The policy that already covers this estate's Prod - a policy only links environments in its own region,
# so reusing the estate's keeps every slice in a region the policy accepts.
function Resolve-BillingPolicy {
  if ($BillingPolicyId) { return $BillingPolicyId }
  $prod = Get-Environments | Where-Object { $_.properties.displayName -eq (Get-EstateName 'Halcourt-Prod' $Estate) } | Select-Object -First 1
  if (-not $prod) { Write-Warning 'Estate Prod not found - pass -BillingPolicyId.'; return $null }
  foreach ($p in (Invoke-Api GET "$PP/licensing/billingPolicies?api-version=2022-03-01-preview" $PP $null).value) {
    $linked = (Invoke-Api GET "$PP/licensing/billingPolicies/$($p.id)/environments?api-version=2022-03-01-preview" $PP $null).value
    if ($linked.environmentId -contains $prod.name) { return $p.id }
  }
  Write-Warning 'No billing policy covers the estate Prod - agents in the slices will not publish.'
  $null
}

# --- Destroy ----------------------------------------------------------------------------------------------
if ($Destroy) {
  $pattern = "^$([regex]::Escape("$Prefix-$Estate-"))\d+$"
  $mine = @(Get-Environments | Where-Object { $_.properties.displayName -match $pattern })
  if (-not $mine) { Write-Host "No slices match '$Prefix-$Estate-NN'."; return }
  Write-Host "`nAbout to delete $($mine.Count) attendee environment(s) and everything in them:"
  $mine | ForEach-Object { Write-Host "  $($_.properties.displayName)" }
  if (-not $Force) {
    if ((Read-Host "`nType the estate id ('$Estate') to confirm") -ne $Estate) { Write-Host 'Aborted.'; return }
  }
  $policy = Resolve-BillingPolicy
  foreach ($e in $mine) {
    # Unlink billing FIRST. Deleting the environment leaves the link behind otherwise, and this tenant
    # already carries three such links pointing at environments that no longer exist.
    if ($policy) {
      try { Invoke-Api POST "$PP/licensing/billingPolicies/$policy/environments/remove?api-version=2022-03-01-preview" $PP @{ environmentIds = @($e.name) } | Out-Null }
      catch { Write-Warning "  $($e.properties.displayName): billing unlink failed - $($_.Exception.Message.Split([char]10)[0])" }
    }
    try {
      Invoke-Api DELETE "$BAP/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/$($e.name)?api-version=2021-04-01" 'https://service.powerapps.com/' $null | Out-Null
      Write-Host "  deleted $($e.properties.displayName)"
    } catch { Write-Warning "  $($e.properties.displayName): delete failed - $($_.Exception.Message.Split([char]10)[0])" }
  }
  return
}

# --- Build ------------------------------------------------------------------------------------------------
Write-Host "Estate '$Estate' on $DomainSuffix - building $Count attendee slice(s)."
$policy = Resolve-BillingPolicy
if ($policy) { Write-Host "Billing policy: $policy" }

function Add-EnvUser([string]$EnvId, [string]$Upn) {
  $oid = az rest --method GET --url "https://graph.microsoft.com/v1.0/users/$Upn`?`$select=id" --query id -o tsv 2>$null
  if (-not $oid) { Write-Warning "  $Upn not found in Entra."; return $null }
  try { Invoke-Api POST "$BAP/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/$EnvId/addUser?api-version=2021-04-01" 'https://service.powerapps.com/' @{ objectId = $oid } | Out-Null }
  catch { }   # already a member answers 400; the caller checks for the user record instead
  $oid
}

# A fresh org's first calls can fail with "Interactive authentication is needed" while az settles a token
# for the brand-new resource. It clears on its own, so retry rather than failing the slice.
function Invoke-DvRetry([string]$OrgUrl, [string]$Path, [int]$Tries = 6) {
  for ($i = 1; $i -le $Tries; $i++) {
    try { return Invoke-Api GET "$OrgUrl/api/data/v9.2/$Path" $OrgUrl $null }
    catch { if ($i -eq $Tries) { throw }; Start-Sleep -Seconds 10; $script:Tokens.Remove($OrgUrl) | Out-Null }
  }
}

foreach ($n in 1..$Count) {
  $name = Get-SliceName $n
  Write-Host "`n=== $name ==="
  $env = Get-Environments | Where-Object { $_.properties.displayName -eq $name } | Select-Object -First 1
  if ($env) {
    Write-Host "  exists - reusing it."
  } else {
    Write-Host '  creating environment (Sandbox + Dataverse)...'
    # location and properties.azureRegion are both rejected here; macroRegion is the one that works.
    Invoke-Api POST "$BAP/providers/Microsoft.BusinessAppPlatform/environments?api-version=2021-04-01&id=/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments" 'https://service.powerapps.com/' @{
      macroRegion = $MacroRegion
      properties  = @{
        displayName               = $name
        environmentSku            = 'Sandbox'
        databaseType              = 'CommonDataService'
        linkedEnvironmentMetadata = @{ baseLanguage = 1033; currency = @{ code = 'USD' }; templates = @() }
      }
    } | Out-Null
  }
  # Wait for Dataverse. On the build tenant this took about 30 seconds, not the minutes Phase 3 waits.
  $deadline = (Get-Date).AddMinutes(15)
  do {
    $env = Get-Environments | Where-Object { $_.properties.displayName -eq $name } | Select-Object -First 1
    $url = $env.properties.linkedEnvironmentMetadata.instanceApiUrl
    if (-not $url) { Start-Sleep -Seconds 15 }
  } while (-not $url -and (Get-Date) -lt $deadline)
  if (-not $url) { Write-Warning "  $name has no Dataverse after 15 minutes - skipping."; continue }
  Write-Host "  ready: $url"

  if ($policy) {
    try {
      Invoke-Api POST "$PP/licensing/billingPolicies/$policy/environments/add?api-version=2022-03-01-preview" $PP @{ environmentIds = @($env.name) } | Out-Null
      Write-Host '  billing linked'
    } catch { Write-Warning "  billing link failed - agents here will not publish: $($_.Exception.Message.Split([char]10)[0])" }
  }

  if (-not $SkipSeed) {
    # svc-claims must be IN the environment before Phase 5 can give it the over-broad role - and addUser
    # is ASYNCHRONOUS. Phase 5 reports a missing user record as "needs a license", which is the wrong
    # diagnosis and leaves the slice without the over-broad role, so wait for the record to appear.
    $svcUpn = "$(Get-EstateAlias 'svc-claims' $Estate)@$DomainSuffix"
    $svcOid = Add-EnvUser $env.name $svcUpn
    Invoke-DvRetry $url 'WhoAmI' | Out-Null
    if ($svcOid) {
      $seen = $false
      foreach ($try in 1..12) {
        $hit = (Invoke-DvRetry $url ("systemusers?`$select=systemuserid&`$filter=" + [uri]::EscapeDataString("azureactivedirectoryobjectid eq $svcOid"))).value
        if ($hit) { $seen = $true; break }
        Start-Sleep -Seconds 10
      }
      if ($seen) { Write-Host '  svc-claims is present in the environment' }
      else       { Write-Warning '  svc-claims has not appeared yet - the over-broad role will be left unassigned; re-run to finish.' }
    }
    Write-Host '  seeding Claim/Customer + the over-broad role (Phase 5 into this environment)...'
    & (Join-Path $PSScriptRoot '04_provision_dataverse.ps1') -Estate $Estate -ClaimsTestEnvUrl $url | ForEach-Object {
      if ($_ -match 'Phase 5 complete|role assignment|Customer rows|Claim rows') { Write-Host "    $_" }
    }
  }

  # The attendee owns their slice: System Administrator here lets them build a scoped role, switch on
  # row-level security and remediate - the Module 5 work they cannot do in the shared estate.
  $studentUpn = "$(Get-EstateAlias ("{0}{1:d2}" -f $StudentPrefix, $n) $Estate)@$DomainSuffix"
  $oid = Add-EnvUser $env.name $studentUpn
  if ($oid) {
    try {
      $su = (Invoke-DvRetry $url ("systemusers?`$select=systemuserid&`$filter=" + [uri]::EscapeDataString("azureactivedirectoryobjectid eq $oid"))).value | Select-Object -First 1
      $role = (Invoke-DvRetry $url ("roles?`$select=roleid&`$filter=" + [uri]::EscapeDataString("name eq 'System Administrator'"))).value | Select-Object -First 1
      if ($su -and $role) {
        Invoke-Api POST "$url/api/data/v9.2/systemusers($($su.systemuserid))/systemuserroles_association/`$ref" $url @{ '@odata.id' = "$url/api/data/v9.2/roles($($role.roleid))" } | Out-Null
        Write-Host "  $studentUpn is System Administrator of this slice"
      } else { Write-Warning "  could not give $studentUpn System Administrator here - assign it by hand." }
    } catch {
      if ("$($_.Exception.Message)" -match 'duplicate|already') { Write-Host "  $studentUpn already System Administrator here" }
      else { Write-Warning "  role grant failed for ${studentUpn}: $($_.Exception.Message.Split([char]10)[0])" }
    }
  } else {
    Write-Warning "  $studentUpn does not exist - run 07_provision_lab_users.ps1 -Count $Count first."
  }
}

Write-Host "`nSlices built. Still missing from each one: the SharePoint grounding site and the two agents"
Write-Host '  (including the orphaned-connection agent owned by the disabled tom.dean) - see this header.'
Write-Host "Teardown: pwsh setup/scripts/08_provision_student_slices.ps1 -Estate $Estate -Destroy"
