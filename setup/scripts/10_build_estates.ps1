<#
FACILITATOR-ONLY. Build one or more estates end to end - RUNBOOK Phases 2 to 8c per estate, in order -
for a delivery that gives every attendee their own estate (issue #30). Phase 0 (once per tenant) and
Phase 1 (one shared Azure deployment, ADR-0005) must already be done.

The last two phases are the estate's attendees: 8b creates -Attendees accounts (student01.<estate>...)
WITHOUT a seat, and 8c their slices (Lab-<estate>-NN), which the attendee needs from Exercise 03. Seats are
the day before the delivery (RUNBOOK Phase 8b: re-run 07 without -NoLicense, once persona seats are
reclaimed).

  pwsh setup/scripts/10_build_estates.ps1 -Estates fac01                       # one estate
  pwsh setup/scripts/10_build_estates.ps1 -Estates fac02,fac03 -ReclaimSeats         # comma-separated, no spaces
  pwsh setup/scripts/10_build_estates.ps1 -Estates fac01 -From agents           # resume at Phase 6 (owners need seats)
  pwsh setup/scripts/10_build_estates.ps1 -Estates fac01 -ReclaimOnly           # just take the seats back

Per estate, before anything is created: the shared Phase 1 values must be present (_lab_endpoints.ps1) and
enough E5 seats free for the estate's eight licensed personas (ADR-0009). Each phase runs as its own
script, exactly as the RUNBOOK gives it, and its output goes to setup/build-logs/<estate>/ (gitignored).
The first failing phase stops that estate; -ContinueOnError moves on to the next estate instead. Every
phase script is safe to re-run, so -From <phase> resumes where a failure stopped.

-ReclaimSeats takes the E5 seat back from the estate's eight personas once its build passes (with
-ContinueOnError, after a failure too: resume that estate with -From entra), so the next
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
  [switch]$ContinueOnError,             # a failing estate doesn't stop the others
  [ValidateRange(1,99)][int]$Attendees = 1,   # Phase 8b accounts and 8c slices per estate (one estate per attendee: 1)
  [string]$LabPassword                          # the personas' password; default: Get-LabPassword (_estate.ps1)
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

# The Phase 4 PnP app, app-only (03, 03b): the variables the RUNBOOK exports (ENTRAID_APP_ID,
# HALCOURT_PNP_CERT_PFX, HALCOURT_PNP_CERT_PW). Any that aren't exported are filled from
# setup/pnp-app.local.{json,pfx} when present. Without all three, 03 would fall back to a device code.
$pnp = Join-Path $Root 'setup/pnp-app.local.json'
if (Test-Path $pnp) {
  $p = Get-Content $pnp -Raw | ConvertFrom-Json
  if (-not $env:ENTRAID_APP_ID)        { $env:ENTRAID_APP_ID = $p.appId }
  if (-not $env:HALCOURT_PNP_CERT_PW)  { $env:HALCOURT_PNP_CERT_PW = $p.pfxPassword }
  if (-not $env:HALCOURT_PNP_CERT_PFX) { $env:HALCOURT_PNP_CERT_PFX = Join-Path $Root 'setup/pnp-app.local.pfx' }
}
if (-not ($env:ENTRAID_APP_ID -and $env:HALCOURT_PNP_CERT_PFX -and $env:HALCOURT_PNP_CERT_PW)) {
  throw 'Export ENTRAID_APP_ID, HALCOURT_PNP_CERT_PFX and HALCOURT_PNP_CERT_PW (RUNBOOK Phase 4) - without them Phase 4 waits on a device code.'
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
  [pscustomobject]@{ Name = 'users';        Phase = '8b';  Script = '07_provision_lab_users.ps1';        Args = @('-Count', "$Attendees", '-NoLicense') }
  [pscustomobject]@{ Name = 'slices';       Phase = '8c';  Script = '08_provision_student_slices.ps1';   Args = @('-Count', "$Attendees") }
)
$names = $phases.Name
foreach ($n in @($From, $To) | Where-Object { $_ }) { if ($n -notin $names) { throw "Unknown phase '$n'. Phases: $($names -join ', ')" } }
$first = if ($From) { [array]::IndexOf($names, $From) } else { 0 }
$last  = if ($To)   { [array]::IndexOf($names, $To) }   else { $phases.Count - 1 }
if ($first -gt $last) { throw "-From $From comes after -To $To." }

# The eight accounts Phase 2 licenses (ADR-0009): svc-claims and the seven agent owners.
$LicensedPersonas = 'svc-claims', 'marcus.webb', 'priya.nair', 'lena.ford', 'dev.kim', 'tom.dean', 'sam.olsen', 'it.helpdesk'
# The tenant's E5, as 01 picks it.
$skus = (az rest --method GET --url 'https://graph.microsoft.com/v1.0/subscribedSkus' -o json | ConvertFrom-Json).value
$e5 = foreach ($want in 'DEVELOPERPACK_V2_E5', 'SPE_E5', 'ENTERPRISEPREMIUM') {                   # 01's preference order
  $skus | Where-Object skuPartNumber -eq $want | Select-Object -First 1 @{ n = 'id'; e = { $_.skuId } }
}
$e5 = @($e5)[0]
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
  $failed = @()
  foreach ($a in $held) {
    $upn = "$(Get-EstateAlias $a $Estate)@$tenantDomain"
    $body = @{ addLicenses = @(); removeLicenses = @($e5.id) } | ConvertTo-Json -Compress
    $tmp = New-TemporaryFile; Set-Content $tmp $body
    # Graph throttles licence changes after a busy night (429 DependencyThrottled, 2026-10-23): a removal that
    # wasn't retried simply didn't happen, and the next estates were skipped for lack of seats. Back off.
    for ($i = 1; $i -le 6; $i++) {
      $err = az rest --method POST --url "https://graph.microsoft.com/v1.0/users/$upn/assignLicense" --body "@$tmp" -o none 2>&1
      if (-not $LASTEXITCODE) { break }
      if ($i -eq 6) { $failed += $a; Write-Warning "  could not free $upn's seat: $(($err | Out-String).Trim().Split([char]10)[0])"; break }
      Start-Sleep -Seconds (20 * $i)
    }
    Remove-Item $tmp
  }
  # Removals land in Graph a little later than the call returns: wait for them before reporting.
  $still = Get-SeatHolders $Estate
  for ($i = 0; $i -lt 6 -and $still.Count; $i++) { Start-Sleep 30; $still = Get-SeatHolders $Estate }
  if ($still) { Write-Warning "  $Estate's $($still -join ', ') still hold a seat - re-run with -ReclaimOnly" }
  Write-Host "  reclaimed $($held.Count - $still.Count) of $($held.Count) seat(s) from $Estate's personas; $(Get-FreeSeats) free"
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
    username = "$(Get-EstateAlias 'dev.kim' $Estate)@$tenantDomain"; password = (Get-LabPassword $LabPassword) }).access_token
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
  $why = $null
  $lab = Get-LabEndpoints
  if ($lab.Missing.Count) { $why = "Phase 1 values missing ($($lab.Missing -join ', ')) - get setup/lab-endpoints.local.json first (RUNBOOK Phase 1)" }
  elseif ($first -le [array]::IndexOf($names, 'entra')) {
    $need = $LicensedPersonas.Count - (Get-SeatHolders $estate).Count
    $free = Get-FreeSeats
    # The previous estate's reclaim may still be landing: give the count up to five minutes to catch up.
    for ($i = 0; $i -lt 10 -and $free -lt $need; $i++) { Start-Sleep 30; $free = Get-FreeSeats }
    if ($free -lt $need) { $why = "needs $need E5 seat(s) for its personas; $free free - reclaim another estate's (-ReclaimOnly) or free seats" }
  } elseif (@('onedrive', 'agents') | Where-Object { $i = [array]::IndexOf($names, $_); $i -ge $first -and $i -le $last }) {
    # Resuming past Phase 2 into a phase that signs in AS the personas (4b: dev.kim's OneDrive; 6: the agents'
    # owners) - they must still hold their seats. The rest run as the admin or the lab app: re-running
    # Phase 4c alone (-From purview -To purview) after a reclaim is fine.
    $held = (Get-SeatHolders $estate).Count
    if ($held -lt $LicensedPersonas.Count) { $why = "only $held of $($LicensedPersonas.Count) personas hold a seat - resume from entra (Phase 2) to give them back" }
  }
  if ($why) {
    Write-Warning "estate $estate not started: $why"
    $summary += [pscustomobject]@{ Estate = $estate; Result = "NOT STARTED: $why"; Minutes = 0 }
    if ($ContinueOnError) { continue } else { break }
  }

  $failed = $null; $timings = @()
  foreach ($ph in $phases[$first..$last]) {
    $log = Join-Path $logDir ("{0}-{1}.log" -f $ph.Phase, $ph.Name)
    $t0 = Get-Date
    Write-Host ("[{0:HH:mm:ss}] Phase {1,-4} {2,-13} {3} {4}" -f $t0, $ph.Phase, $ph.Name, $ph.Script, ($ph.Args -join ' '))
    if ($ph.Script) {
      # Shown as well as logged: a phase that falls back to a device code must not wait unseen. Phase 6 is
      # retried once, and only after a 401 (06 names failing calls "-> 401 :"): it is safe to re-run, and an
      # intermittent 401 stopped it twice (fac02, fac03, 2026-10-22). Other failures repeat - no retry.
      $tries = 0
      while ($true) {
        $tries++
        $log = Join-Path $logDir ("{0}-{1}{2}.log" -f $ph.Phase, $ph.Name, $(if ($tries -gt 1) { ".try$tries" } else { '' }))
        & pwsh -NoProfile -File (Join-Path $PSScriptRoot $ph.Script) @($ph.Args) *>&1 | Tee-Object -FilePath $log | ForEach-Object { "    $_" } | Out-Host
        $code = $LASTEXITCODE
        if (-not $code -or $ph.Name -ne 'agents' -or $tries -ge 2 -or -not (Select-String -Path $log -Pattern '-> 401 :|\(401\)' -Quiet)) { break }
        Write-Host "           Phase $($ph.Phase) ($($ph.Name)) failed with a 401 - retrying once (log: $log)"
      }
    } else {                                                             # in-process step (devadmin)
      try { Grant-DevEnvAdmin $estate *> $log; $code = 0 } catch { "$_" | Out-File $log -Append; $code = 1 }
    }
    $mins = [math]::Round(((Get-Date) - $t0).TotalMinutes, 1)
    $timings += [pscustomobject]@{ Phase = $ph.Phase; Name = $ph.Name; Minutes = $mins; Exit = $code; Tries = $(if ($ph.Script) { $tries } else { 1 }) }
    $tail = (Get-Content $log -Tail 2 -ErrorAction SilentlyContinue) -join ' | '
    Write-Host ("           exit {0} in {1} min - {2}" -f $code, $mins, $tail.Substring(0, [Math]::Min(160, $tail.Length)))
    if (-not $code -and $ph.Name -eq 'entra') {
      $held = Get-SeatHolders $estate
      # Exchange creates it.helpdesk (a shared mailbox) late, so 01 can't license it yet - 01 itself says
      # "re-run in a minute". Do that once before calling it a failure (stu10, 2026-10-22).
      if ($held.Count -lt $LicensedPersonas.Count) {
        Write-Host "           $($LicensedPersonas.Count - $held.Count) persona(s) not licensed yet - re-running Phase 2 in 60s"
        Start-Sleep 60
        & pwsh -NoProfile -File (Join-Path $PSScriptRoot $ph.Script) @($ph.Args) *>&1 | Tee-Object -FilePath $log -Append | ForEach-Object { "    $_" } | Out-Host
        $held = Get-SeatHolders $estate
      }
      if ($held.Count -lt $LicensedPersonas.Count) {
        "Phase 2 left $($LicensedPersonas.Count - $held.Count) persona(s) without a seat: $(@($LicensedPersonas | Where-Object { $_ -notin $held }) -join ', ') - re-run -From entra in a minute (Exchange creates it.helpdesk late)" | Tee-Object -FilePath $log -Append | Write-Warning
        $code = 1
      }
    }
    if ($code) { $failed = $ph.Name; break }
  }
  $timings | Format-Table -AutoSize | Out-String | Tee-Object -FilePath (Join-Path $logDir 'timings.txt') | Write-Host
  if (-not $failed -and $ReclaimSeats) { Invoke-Reclaim $estate }
  # A failed estate holds its eight seats, and the next estate then can't start: one stalled OneDrive skipped
  # fourteen estates on 2026-10-22. With -ContinueOnError, give them back; resume the failed estate with
  # -From entra (Phase 2 re-licenses its personas).
  elseif ($failed -and $ReclaimSeats -and $ContinueOnError) {
    Write-Host "  $estate failed at $failed - reclaiming its seats so the remaining estates can build; resume it with -From entra"
    Invoke-Reclaim $estate
  }
  $retried = @($timings | Where-Object { $_.Tries -gt 1 } | ForEach-Object { $_.Name })
  $summary += [pscustomobject]@{ Estate = $estate; Result = $(if ($failed) { "FAILED at $failed (log: setup/build-logs/$estate/)" } elseif ($retried) { "built (retried after 401: $($retried -join ', '))" } else { 'built' })
                                 Minutes = [math]::Round(($timings | Measure-Object Minutes -Sum).Sum, 1) }
  if ($failed -and -not $ContinueOnError) { break }
}
Write-Host "`n================ summary ================"
$summary | Format-Table -AutoSize | Out-String | Write-Host
if ($summary | Where-Object Result -like 'FAILED*') { exit 1 }
