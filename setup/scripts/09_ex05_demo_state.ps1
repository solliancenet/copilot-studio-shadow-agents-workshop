<#
FACILITATOR-ONLY. Exercise 05 demonstrations: snapshot the estate before a control is applied, restore it
exactly afterwards.

Exercise 05 is demonstrated, not done by attendees (decided 2026-10-19): the facilitator applies each control
to the SHARED estate once, the room retests, and the estate goes back. "Back" must be exact and must not
depend on clicking the portal in reverse, so every change has a snapshot taken before it and a restore from
that snapshot afterwards. RUNBOOK -> "Exercise 05 demonstrations" has the order; this script is the tool.

  pwsh setup/scripts/09_ex05_demo_state.ps1 -Action Snapshot -Control All     # before the session
  pwsh setup/scripts/09_ex05_demo_state.ps1 -Action Diff     -Control Dlp     # what the demo changed
  pwsh setup/scripts/09_ex05_demo_state.ps1 -Action Restore  -Control Dlp     # after the retests

Controls the script can restore exactly:
  Dlp           every data policy (05-01 Prod blocks, 05-02 default-environment policy). Restore PATCHes changed
                policies back and deletes policies created since the snapshot whose name carries this estate's
                id - name a demo policy <something>-<estate> (e.g. Halcourt-Default-DLP-mgray).
  DefaultMakers the default environment's Environment Maker role: its users AND teams (05-02 lockdown).
  ClaimsRoles   svc-claims' security roles and team memberships in Claims-Test, and custom roles created there
                since the snapshot (05-03 scoped role).
  Both also strip roles the facilitator account gave itself in that environment (Membership > Add me).
Not restorable here (portal only; RUNBOOK checklist): Benefits Buddy's knowledge scope (05-03), the Agent 365
Block (05-05), Defender real-time protection (05-07).

Snapshots live in setup/ex05-state/<estate>/ (gitignored). Runs as the az sign-in (tenant admin). ASCII only.
#>
param(
  [Parameter(Mandatory)][ValidateSet('Snapshot', 'Restore', 'Diff')][string]$Action,
  [Parameter(Mandatory)][ValidateSet('Dlp', 'DefaultMakers', 'ClaimsRoles', 'All')][string]$Control,
  [string]$Estate = $env:HALCOURT_ESTATE,
  [string]$StateDir
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_estate.ps1')          # also the tenant guard: refuses any az sign-in but the repo's
$Estate = Resolve-Estate $Estate
if (-not $StateDir) { $StateDir = Join-Path (Split-Path $PSScriptRoot -Parent) "ex05-state/$Estate" }
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null

$script:Tokens = @{}
function Tok([string]$Resource) {
  if (-not $script:Tokens[$Resource]) { $script:Tokens[$Resource] = az account get-access-token --resource $Resource --query accessToken -o tsv }
  $script:Tokens[$Resource]
}
function Api([string]$Method, [string]$Uri, [string]$Resource, $Body) {
  $h = @{ Authorization = "Bearer $(Tok $Resource)" }
  if ($null -eq $Body) { Invoke-RestMethod -Method $Method -Uri $Uri -Headers $h }
  else { Invoke-RestMethod -Method $Method -Uri $Uri -Headers $h -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 30) }
}
function Save($Name, $Obj) { $Obj | ConvertTo-Json -Depth 30 | Set-Content (Join-Path $StateDir "$Name.json"); Write-Host "  snapshot -> $StateDir/$Name.json" }
function Load($Name) {
  $p = Join-Path $StateDir "$Name.json"
  if (-not (Test-Path $p)) { throw "No snapshot $p - run -Action Snapshot -Control $Control before the demonstration." }
  Get-Content $p -Raw | ConvertFrom-Json
}

# ---- environments ------------------------------------------------------------------------------------
$PP = 'https://service.powerapps.com/'
$envs = (Api GET 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2021-04-01' $PP).value
function Env([string]$Display) {
  $e = $envs | Where-Object { $_.properties.displayName -eq $Display } | Select-Object -First 1
  if (-not $e) { throw "Environment '$Display' not found." }
  [pscustomobject]@{ Id = $e.name; Org = $e.properties.linkedEnvironmentMetadata.instanceUrl.TrimEnd('/') }
}
function DefaultEnv {
  $e = $envs | Where-Object { $_.properties.isDefault } | Select-Object -First 1
  [pscustomobject]@{ Id = $e.name; Org = $e.properties.linkedEnvironmentMetadata.instanceUrl.TrimEnd('/') }
}
function Dv($E, [string]$Method, [string]$Path, $Body) { Api $Method "$($E.Org)/api/data/v9.2/$Path" $E.Org $Body }
function RootRole($E, [string]$Name) {
  $bu = (Dv $E GET 'businessunits?$select=businessunitid&$filter=parentbusinessunitid eq null').value[0].businessunitid
  (Dv $E GET "roles?`$select=roleid&`$filter=name eq '$Name' and _businessunitid_value eq $bu").value[0].roleid
}

# ---- Dlp ---------------------------------------------------------------------------------------------
$BAP = 'https://api.bap.microsoft.com/providers/PowerPlatform.Governance/v2/policies'
# The LIST call returns each policy WITHOUT its connectorGroups - a snapshot or a comparison built on it is
# blind to the very change 05-01 makes (found 2026-10-19: a blocked HTTP connector read as "unchanged", and
# the restore did nothing). Read every policy individually.
function DlpAll {
  (Api GET "$BAP`?api-version=2016-11-01" $PP).value | ForEach-Object {
    (Api GET "$BAP/$($_.policyDefinition.name)?api-version=2016-11-01" $PP).policyDefinition
  }
}
function DlpShape($p) {
  # What a demonstration changes: connector classification, custom-connector patterns, scope.
  [ordered]@{
    default = $p.defaultConnectorsClassification
    groups = @($p.connectorGroups | Sort-Object classification | ForEach-Object { "$($_.classification): " + ((@($_.connectors | ForEach-Object name) | Sort-Object) -join ',') })
    custom = @($p.customConnectorUrlPatternsDefinition.rules | ForEach-Object { "$($_.order) $($_.pattern) $($_.dataGroup)" })
    envs   = @($p.environments | ForEach-Object name | Sort-Object)
    type   = $p.environmentType
  } | ConvertTo-Json -Depth 5 -Compress
}
function Dlp-Snapshot { Save 'dlp' @(DlpAll) }
function Dlp-Diff {
  $want = @(Load 'dlp'); $have = @(DlpAll); $changed = 0
  foreach ($w in $want) {
    $h = $have | Where-Object name -eq $w.name
    if (-not $h) { Write-Host "  GONE     $($w.displayName)"; $changed++ }
    elseif ((DlpShape $h) -ne (DlpShape $w)) { Write-Host "  CHANGED  $($w.displayName)"; $changed++ }
  }
  foreach ($h in $have | Where-Object { $_.name -notin $want.name }) { Write-Host "  NEW      $($h.displayName)"; $changed++ }
  if (-not $changed) { Write-Host '  data policies: same as the snapshot' }
  $changed
}
function Dlp-Restore {
  $want = @(Load 'dlp'); $have = @(DlpAll)
  if (@($want | Where-Object { -not $_.connectorGroups }).Count) { throw "The dlp snapshot has no connector groups (taken by an older version of this script) - it can't restore a policy. Take a new snapshot BEFORE the next demonstration." }
  foreach ($w in $want) {
    $h = $have | Where-Object name -eq $w.name
    if (-not $h) { Write-Warning "  '$($w.displayName)' was deleted since the snapshot - recreate it by hand (Phase 3 for the estate's own)."; continue }
    if ((DlpShape $h) -eq (DlpShape $w)) { continue }
    $body = $w | Select-Object * -ExcludeProperty createdBy, createdTime, lastModifiedBy, lastModifiedTime
    $body.etag = $h.etag
    # v2 refuses PUT (404) and a bare definition (400); it takes PATCH {policyDefinition: ...}.
    Api PATCH "$BAP/$($w.name)?api-version=2016-11-01" $PP @{ policyDefinition = $body } | Out-Null
    Write-Host "  restored $($w.displayName)"
  }
  foreach ($h in $have | Where-Object { $_.name -notin $want.name }) {
    if ($h.displayName -match "(^|[-_ ])$([regex]::Escape($Estate))$") {
      Api DELETE "$BAP/$($h.name)?api-version=2016-11-01" $PP | Out-Null; Write-Host "  deleted  $($h.displayName) (created by the demonstration)"
    } else { Write-Warning "  '$($h.displayName)' is new but doesn't carry the estate id '$Estate' - left alone (another estate's?)." }
  }
  (Dlp-Diff) -eq 0
}

# ---- the facilitator account's own roles ------------------------------------------------------------
# To edit roles in an environment the facilitator first adds itself (Membership > Add me = System
# Administrator). That is part of the demonstration too, so each Dataverse control snapshots the facilitator
# account's roles in its environment and strips anything added. The user record may not exist until the
# first Add me; then the snapshot holds no roles and the restore removes every role the account gained.
function Self-Roles($E) {
  $u = (Dv $E GET "systemusers?`$select=systemuserid&`$filter=startswith(domainname,'$(Get-EstateAlias 'facilitator' $Estate)@')").value | Select-Object -First 1
  if (-not $u) { return @() }
  @((Dv $E GET "systemusers($($u.systemuserid))/systemuserroles_association?`$select=roleid").value | ForEach-Object roleid | Sort-Object)
}
function Self-Restore($E, $Want) {
  $u = (Dv $E GET "systemusers?`$select=systemuserid&`$filter=startswith(domainname,'$(Get-EstateAlias 'facilitator' $Estate)@')").value | Select-Object -First 1
  if (-not $u) { return }
  foreach ($r in @(Self-Roles $E) | Where-Object { $_ -notin @($Want) }) {
    Dv $E DELETE "systemusers($($u.systemuserid))/systemuserroles_association($r)/`$ref" | Out-Null; Write-Host "  facilitator: removed role $r"
  }
}

# ---- DefaultMakers -----------------------------------------------------------------------------------
function Makers-Read { $E = DefaultEnv; $rid = RootRole $E 'Environment Maker'
  [ordered]@{ role = $rid
    users = @((Dv $E GET "roles($rid)/systemuserroles_association?`$select=systemuserid,domainname").value | ForEach-Object systemuserid | Sort-Object)
    teams = @((Dv $E GET "roles($rid)/teamroles_association?`$select=teamid,name").value | ForEach-Object teamid | Sort-Object)
    self  = @(Self-Roles $E) } }
function Makers-Snapshot { $m = Makers-Read; Save 'default-makers' $m; Write-Host "  Environment Maker: $($m.users.Count) users, $($m.teams.Count) teams" }
function Makers-Diff { $w = Load 'default-makers'; $h = Makers-Read
  $d = @(Compare-Object @($w.users) @($h.users)) + @(Compare-Object @($w.teams) @($h.teams)) + @(Compare-Object @($w.self) @($h.self))
  if ($d.Count) { $d | ForEach-Object { Write-Host "  $(if ($_.SideIndicator -eq '=>') {'ADDED  '} else {'REMOVED'}) $($_.InputObject)" } } else { Write-Host '  Environment Maker (and the facilitator''s roles): same as the snapshot' }
  $d.Count }
function Makers-Restore { $E = DefaultEnv; $w = Load 'default-makers'; $h = Makers-Read; $rid = $h.role; $ref = @{ '@odata.id' = "$($E.Org)/api/data/v9.2/roles($rid)" }
  foreach ($u in @($w.users) | Where-Object { $_ -notin $h.users }) { Dv $E POST "systemusers($u)/systemuserroles_association/`$ref" $ref | Out-Null }
  foreach ($u in @($h.users) | Where-Object { $_ -notin $w.users }) { Dv $E DELETE "systemusers($u)/systemuserroles_association($rid)/`$ref" | Out-Null }
  foreach ($t in @($w.teams) | Where-Object { $_ -notin $h.teams }) { Dv $E POST "teams($t)/teamroles_association/`$ref" $ref | Out-Null }
  foreach ($t in @($h.teams) | Where-Object { $_ -notin $w.teams }) { Dv $E DELETE "teams($t)/teamroles_association($rid)/`$ref" | Out-Null }
  Self-Restore $E $w.self
  (Makers-Diff) -eq 0 }

# ---- ClaimsRoles -------------------------------------------------------------------------------------
function Claims-Read { $E = Env (Get-EstateName 'Claims-Test' $Estate)
  $su = (Dv $E GET "systemusers?`$select=systemuserid&`$filter=startswith(domainname,'$(Get-EstateAlias 'svc-claims' $Estate)@')").value[0].systemuserid
  if (-not $su) { throw "svc-claims not found in Claims-Test." }
  [ordered]@{ user = $su
    roles = @((Dv $E GET "systemusers($su)/systemuserroles_association?`$select=roleid").value | ForEach-Object roleid | Sort-Object)
    teams = @((Dv $E GET "systemusers($su)/teammembership_association?`$select=teamid").value | ForEach-Object teamid | Sort-Object)
    custom = @((Dv $E GET 'roles?$select=roleid&$filter=ismanaged eq false').value | ForEach-Object roleid | Sort-Object)
    self   = @(Self-Roles $E) } }
function Claims-Snapshot { $c = Claims-Read; Save 'claims-roles' $c; Write-Host "  svc-claims: $($c.roles.Count) roles, $($c.teams.Count) teams; $($c.custom.Count) unmanaged roles in Claims-Test" }
function Claims-Diff { $w = Load 'claims-roles'; $h = Claims-Read
  $d = @(Compare-Object @($w.roles) @($h.roles)) + @(Compare-Object @($w.teams) @($h.teams)) + @(Compare-Object @($w.custom) @($h.custom)) + @(Compare-Object @($w.self) @($h.self))
  if ($d.Count) { $d | ForEach-Object { Write-Host "  $(if ($_.SideIndicator -eq '=>') {'ADDED  '} else {'REMOVED'}) $($_.InputObject)" } } else { Write-Host '  svc-claims roles: same as the snapshot' }
  $d.Count }
function Claims-Restore { $E = Env (Get-EstateName 'Claims-Test' $Estate); $w = Load 'claims-roles'; $h = Claims-Read; $su = $w.user
  foreach ($r in @($w.roles) | Where-Object { $_ -notin $h.roles }) { Dv $E POST "systemusers($su)/systemuserroles_association/`$ref" @{ '@odata.id' = "$($E.Org)/api/data/v9.2/roles($r)" } | Out-Null }
  foreach ($r in @($h.roles) | Where-Object { $_ -notin $w.roles }) { Dv $E DELETE "systemusers($su)/systemuserroles_association($r)/`$ref" | Out-Null }
  foreach ($t in @($h.teams) | Where-Object { $_ -notin $w.teams }) { Dv $E DELETE "teams($t)/teammembership_association($su)/`$ref" | Out-Null }
  foreach ($t in @($w.teams) | Where-Object { $_ -notin $h.teams }) { Dv $E POST "teams($t)/teammembership_association/`$ref" @{ '@odata.id' = "$($E.Org)/api/data/v9.2/systemusers($su)" } | Out-Null }
  Self-Restore $E $w.self
  # Roles the demonstration created (the scoped role), once nobody holds them.
  foreach ($r in @((Claims-Read).custom) | Where-Object { $_ -notin $w.custom }) { try { Dv $E DELETE "roles($r)" | Out-Null; Write-Host "  deleted role $r (created by the demonstration)" } catch { Write-Warning "  could not delete role $r : $($_.Exception.Message.Split([char]10)[0])" } }
  (Claims-Diff) -eq 0 }

# ---- run ---------------------------------------------------------------------------------------------
$controls = if ($Control -eq 'All') { 'Dlp', 'DefaultMakers', 'ClaimsRoles' } else { @($Control) }
$ok = $true
foreach ($c in $controls) {
  Write-Host "== $c ($Action)"
  $prefix = @{ Dlp = 'Dlp'; DefaultMakers = 'Makers'; ClaimsRoles = 'Claims' }[$c]
  switch ($Action) {
    'Snapshot' { & "$prefix-Snapshot" }
    'Diff'     { [void](& "$prefix-Diff") }
    'Restore'  { if (-not (& "$prefix-Restore")) { $ok = $false; Write-Warning "  $c does NOT match its snapshot after restore - see the lines above." } else { Write-Host "  $c matches its snapshot." } }
  }
}
if (-not $ok) { exit 1 }
