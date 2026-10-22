<#
FACILITATOR-ONLY. Build one or more estates end to end - RUNBOOK Phases 2 to 6.5 per estate, in order -
for a delivery that gives every attendee their own estate (issue #30). Phase 0 (once per tenant) and
Phase 1 (one shared Azure deployment, ADR-0005) must already be done; Phases 7, 8 and the attendee
accounts are separate.

  pwsh setup/scripts/10_build_estates.ps1 -Estates fac01                       # one estate
  pwsh setup/scripts/10_build_estates.ps1 -Estates fac02,fac03 -ReclaimSeats         # comma-separated, no spaces
  pwsh setup/scripts/10_build_estates.ps1 -Estates fac01 -From agents           # resume at Phase 6
  pwsh setup/scripts/10_build_estates.ps1 -Estates fac01 -ReclaimOnly           # just take the seats back

Per estate, before anything is created: the shared Phase 1 values must be present (_lab_endpoints.ps1) and
enough E5 seats free for the estate's eight licensed personas (ADR-0009). Each phase runs as its own
script, exactly as the RUNBOOK gives it, and its output goes to setup/build-logs/<estate>/ (gitignored).
The first failing phase stops that estate; -ContinueOnError moves on to the next estate instead. Every
phase script is safe to re-run, so -From <phase> resumes where a failure stopped.

-ReclaimSeats takes the E5 seat back from the estate's eight personas once its build passes, so the next
estate - and, the day before the delivery, the attendees - can use it. Its published agents kept answering
with the owner's seat removed (errata: Phase 2 - An agent owner without a seat); run the Teams chat probe
before a delivery to confirm. An owner without a seat can't open Copilot Studio or rebuild in a browser:
give the seats back (re-run Phase 2: 01_provision_entra.ps1) before changing an estate's agents.

Phase 4c's label takes hours, up to a day, to reach SharePoint: if 03c reports it isn't labelled yet, re-run
it later (-From purview -To purview). Needs az signed in to the lab tenant as the global admin, and the
Phase 4 PnP app's certificate in setup/pnp-app.local.{json,pfx}. ASCII only.
#>
param(
  [Parameter(Mandatory = $true)][string[]]$Estates,
  [string]$From,                        # first phase to run (a name from the table below); default: the first
  [string]$To,                          # last phase to run; default: the last
  [switch]$ReclaimSeats,                # after a build passes, take the eight persona seats back
  [switch]$ReclaimOnly,                 # build nothing; only take the seats back
  [switch]$ContinueOnError              # a failing estate doesn't stop the others
)
$ErrorActionPreference = 'Stop'
# `pwsh -File ... -Estates a,b` arrives as one string 'a,b'; split it (as 06's -Agents does).
$Estates = @($Estates | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)        # the repo root
. (Join-Path $PSScriptRoot '_estate.ps1')
. (Join-Path $PSScriptRoot '_lab_endpoints.ps1')

$tenantDomain = az rest --method GET --url 'https://graph.microsoft.com/v1.0/organization?$select=verifiedDomains' --query "value[0].verifiedDomains[?isDefault].name | [0]" -o tsv
$initialDomain = az rest --method GET --url 'https://graph.microsoft.com/v1.0/organization?$select=verifiedDomains' --query "value[0].verifiedDomains[?isInitial].name | [0]" -o tsv
if (-not $tenantDomain) { throw 'az is not signed in to the lab tenant - source scripts/env.sh and az login.' }
$rootSite = "https://$($initialDomain.Split('.')[0]).sharepoint.com"

# The Phase 4 PnP app, app-only (03, 03b): the same environment variables the RUNBOOK exports.
$pnp = Join-Path $Root 'setup/pnp-app.local.json'
if (-not $env:ENTRAID_APP_ID -and (Test-Path $pnp)) {
  $p = Get-Content $pnp -Raw | ConvertFrom-Json
  $env:ENTRAID_APP_ID = $p.appId; $env:HALCOURT_PNP_CERT_PW = $p.pfxPassword
  $env:HALCOURT_PNP_CERT_PFX = Join-Path $Root 'setup/pnp-app.local.pfx'
}

# RUNBOOK order. 'args' are what the RUNBOOK passes beyond the estate.
$phases = @(
  [pscustomobject]@{ Name = 'entra';        Phase = '2';   Script = '01_provision_entra.ps1';            Args = @('-TenantId', $tenantDomain) }
  [pscustomobject]@{ Name = 'environments'; Phase = '3';   Script = '02_provision_environments_dlp.ps1'; Args = @() }
  [pscustomobject]@{ Name = 'billing';      Phase = '3';   Script = '02b_provision_billing.ps1';         Args = @() }
  [pscustomobject]@{ Name = 'sharepoint';   Phase = '4';   Script = '03_provision_sharepoint.ps1';       Args = @('-RootSiteUrl', $rootSite) }
  [pscustomobject]@{ Name = 'onedrive';     Phase = '4b';  Script = '03b_provision_onedrive.ps1';        Args = @() }
  [pscustomobject]@{ Name = 'purview';      Phase = '4c';  Script = '03c_provision_purview.ps1';         Args = @() }
  [pscustomobject]@{ Name = 'dataverse';    Phase = '5';   Script = '04_provision_dataverse.ps1';        Args = @() }
  [pscustomobject]@{ Name = 'audit';        Phase = '5b';  Script = '04b_provision_audit.ps1';           Args = @() }
  [pscustomobject]@{ Name = 'agents';       Phase = '6';   Script = '06_provision_agents.ps1';           Args = @() }
  [pscustomobject]@{ Name = 'departed';     Phase = '6.5'; Script = '01_provision_entra.ps1';            Args = @('-MarkDepartedOwner') }
  [pscustomobject]@{ Name = 'devadmin';     Phase = '7';   Script = $null;                               Args = @() }
)
$names = $phases.Name
foreach ($n in @($From, $To) | Where-Object { $_ }) { if ($n -notin $names) { throw "Unknown phase '$n'. Phases: $($names -join ', ')" } }
$first = if ($From) { [array]::IndexOf($names, $From) } else { 0 }
$last  = if ($To)   { [array]::IndexOf($names, $To) }   else { $phases.Count - 1 }

# The eight accounts Phase 2 licenses (ADR-0009): svc-claims and the seven agent owners.
$LicensedPersonas = 'svc-claims', 'marcus.webb', 'priya.nair', 'lena.ford', 'dev.kim', 'tom.dean', 'sam.olsen', 'it.helpdesk'
# The tenant's E5, as 01 picks it.
$e5 = (az rest --method GET --url 'https://graph.microsoft.com/v1.0/subscribedSkus' -o json | ConvertFrom-Json).value |
  Where-Object skuPartNumber -in 'DEVELOPERPACK_V2_E5', 'SPE_E5', 'ENTERPRISEPREMIUM' | Select-Object -First 1 @{ n = 'id'; e = { $_.skuId } }
if (-not $e5) { throw 'No E5 licence (DEVELOPERPACK_V2_E5, SPE_E5 or ENTERPRISEPREMIUM) in this tenant.' }
function Get-FreeSeats {
  $s = az rest --method GET --url 'https://graph.microsoft.com/v1.0/subscribedSkus' --query "value[?skuId=='$($e5.id)'] | [0]" -o json | ConvertFrom-Json
  [int]$s.prepaidUnits.enabled - [int]$s.consumedUnits
}
function Get-SeatHolders([string]$Estate) {
  @($LicensedPersonas | Where-Object {
    $upn = "$(Get-EstateAlias $_ $Estate)@$tenantDomain"
    $lic = az rest --method GET --url "https://graph.microsoft.com/v1.0/users/$upn`?`$select=assignedLicenses" --query "assignedLicenses[?skuId=='$($e5.id)'] | length(@)" -o tsv 2>$null
    $lic -eq '1' })
}
function Invoke-Reclaim([string]$Estate) {
  $held = Get-SeatHolders $Estate
  foreach ($a in $held) {
    $upn = "$(Get-EstateAlias $a $Estate)@$tenantDomain"
    $body = @{ addLicenses = @(); removeLicenses = @($e5.id) } | ConvertTo-Json -Compress
    $tmp = New-TemporaryFile; Set-Content $tmp $body
    az rest --method POST --url "https://graph.microsoft.com/v1.0/users/$upn/assignLicense" --body "@$tmp" -o none; Remove-Item $tmp
  }
  Write-Host "  reclaimed $($held.Count) seat(s) from $Estate's personas; $(Get-FreeSeats) free"
}

# Phase 7's prerequisite, without a device code: a Developer environment's only System Administrator is its
# owner (dev.kim), so the admin can't read Maker-Sandbox - the preflight, 07 and the Phase 7 export all get
# 403. The RUNBOOK uses `pac admin assign-user`, whose sign-in expires; instead dev.kim (lab password, the
# same persona sign-in Phase 6 uses) gives the signed-in admin System Administrator there.
function Grant-DevEnvAdmin([string]$Estate) {
  $tenant = az account show --query tenantId -o tsv
  $admin  = az ad signed-in-user show --query id -o tsv
  $envs = (az rest --method GET --resource https://service.powerapps.com/ --url 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2021-04-01' -o json | ConvertFrom-Json).value
  $e = $envs | Where-Object { $_.properties.displayName -eq (Get-EstateName 'Maker-Sandbox' $Estate) } | Select-Object -First 1
  if (-not $e) { throw "no environment $(Get-EstateName 'Maker-Sandbox' $Estate)" }
  $org = $e.properties.linkedEnvironmentMetadata.instanceApiUrl.TrimEnd('/')
  $tok = (Invoke-RestMethod -Method POST "https://login.microsoftonline.com/$tenant/oauth2/v2.0/token" -Body @{
    client_id = '04b07795-8ddb-461a-bbee-02f9e1bf7b46'; grant_type = 'password'; scope = "$org/.default"
    username = "$(Get-EstateAlias 'dev.kim' $Estate)@$tenantDomain"; password = 'Lab-Only-Passw0rd!' }).access_token
  $h = @{ Authorization = "Bearer $tok"; Accept = 'application/json' }
  $su = (Invoke-RestMethod -Headers $h "$org/api/data/v9.2/systemusers?`$select=systemuserid&`$filter=azureactivedirectoryobjectid eq $admin").value | Select-Object -First 1
  if (-not $su) { throw "the signed-in admin has no user record in $($e.properties.displayName)" }
  $role = (Invoke-RestMethod -Headers $h "$org/api/data/v9.2/roles?`$select=roleid&`$filter=name eq 'System Administrator'").value | Select-Object -First 1
  $have = (Invoke-RestMethod -Headers $h "$org/api/data/v9.2/systemusers($($su.systemuserid))/systemuserroles_association?`$select=roleid").value.roleid
  if ($have -contains $role.roleid) { return 'already System Administrator' }
  Invoke-RestMethod -Method POST -Headers $h -ContentType 'application/json' -Uri "$org/api/data/v9.2/systemusers($($su.systemuserid))/systemuserroles_association/`$ref" `
    -Body (@{ '@odata.id' = "$org/api/data/v9.2/roles($($role.roleid))" } | ConvertTo-Json) | Out-Null
  'assigned System Administrator'
}

$summary = @()
foreach ($estate in $Estates) {
  $estate = Resolve-Estate $estate
  $env:HALCOURT_ESTATE = $estate
  Write-Host "`n================ estate $estate ================"
  if ($ReclaimOnly) { Invoke-Reclaim $estate; continue }
  $logDir = Join-Path $Root "setup/build-logs/$estate"; New-Item -ItemType Directory -Force $logDir | Out-Null

  # Preconditions, checked before anything is created for this estate.
  $lab = Get-LabEndpoints
  if ($lab.Missing.Count) { throw "Phase 1 values missing ($($lab.Missing -join ', ')) - get setup/lab-endpoints.local.json first (RUNBOOK Phase 1)." }
  if ($first -le [array]::IndexOf($names, 'entra')) {
    $need = $LicensedPersonas.Count - (Get-SeatHolders $estate).Count
    $free = Get-FreeSeats
    if ($free -lt $need) { throw "Estate $estate needs $need E5 seat(s) for its personas; $free free. Reclaim another estate's (-ReclaimOnly) or free seats first." }
  }

  $failed = $null; $timings = @()
  foreach ($ph in $phases[$first..$last]) {
    $log = Join-Path $logDir ("{0}-{1}.log" -f $ph.Phase, $ph.Name)
    $t0 = Get-Date
    Write-Host ("[{0:HH:mm:ss}] Phase {1,-4} {2,-13} {3} {4}" -f $t0, $ph.Phase, $ph.Name, $ph.Script, ($ph.Args -join ' '))
    if ($ph.Script) {
      & pwsh -NoProfile -File (Join-Path $PSScriptRoot $ph.Script) @($ph.Args) *> $log
      $code = $LASTEXITCODE
    } else {                                                             # in-process step (devadmin)
      try { Grant-DevEnvAdmin $estate *> $log; $code = 0 } catch { "$_" | Out-File $log -Append; $code = 1 }
    }
    $mins = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)
    $timings += [pscustomobject]@{ Phase = $ph.Phase; Name = $ph.Name; Minutes = $mins; Exit = $code }
    $tail = (Get-Content $log -Tail 2 -ErrorAction SilentlyContinue) -join ' | '
    Write-Host ("           exit {0} in {1} min - {2}" -f $code, $mins, $tail.Substring(0, [Math]::Min(160, $tail.Length)))
    if ($code) { $failed = $ph.Name; break }
  }
  $timings | Format-Table -AutoSize | Out-String | Tee-Object -FilePath (Join-Path $logDir 'timings.txt') | Write-Host
  if (-not $failed -and $ReclaimSeats) { Invoke-Reclaim $estate }
  $summary += [pscustomobject]@{ Estate = $estate; Result = $(if ($failed) { "FAILED at $failed (log: setup/build-logs/$estate/)" } else { 'built' })
                                 Minutes = [math]::Round(($timings | Measure-Object Minutes -Sum).Sum, 1) }
  if ($failed -and -not $ContinueOnError) { break }
}
Write-Host "`n================ summary ================"
$summary | Format-Table -AutoSize | Out-String | Write-Host
if ($summary | Where-Object Result -like 'FAILED*') { exit 1 }
