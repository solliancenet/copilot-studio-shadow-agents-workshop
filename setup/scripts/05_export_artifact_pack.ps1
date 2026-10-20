<#
FACILITATOR-ONLY. Phase 7 — Export the artifact pack.

Pulls the estate from the Power Platform admin APIs + Microsoft Graph and writes the five canonical estate CSVs, plus files-export.csv for 05-06,
that attendees analyze offline. The committed files in ../worksheets/artifact-pack/ ARE the expected
output for the canonical estate — diff against them after any change.

Estate (setup/scripts/_estate.ps1): exports only this build's estate - its <name>-<estate> environments,
plus agents/connections in the shared default environment owned by its <alias>.<estate>@ accounts, and only
those accounts (no admins or sample users). -Canonicalize rewrites live names to the canon's (strips the
estate id, restores @halcourtmutual.onmicrosoft.com), so the output diffs cleanly against the committed pack:

  pwsh setup/scripts/05_export_artifact_pack.ps1 -Estate jsmith -Canonicalize
  git diff worksheets/artifact-pack

Without -Canonicalize it refuses to write into the committed (published) pack - pass -OutDir.

Requires: Microsoft.Graph, the lab app 03c makes (files-export.csv), and az signed in to the lab tenant (the Power Platform admin APIs and the
Dataverse bot reads both go through az, so this no longer needs the Windows-only PowerApps admin module).
Lines marked [verify] depend on evolving 2026 admin/Graph surfaces (agent + workload identity listings).
#>
param(
  [string]$Estate = $env:HALCOURT_ESTATE,     # this build's estate id, e.g. jsmith (see _estate.ps1)
  [string]$OutDir,                            # default: the committed pack (needs -Canonicalize)
  [switch]$Canonicalize                       # live names -> canon names (for diffing / regenerating the pack)
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_estate.ps1')
$Estate = Resolve-Estate $Estate
$committedPack = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) 'worksheets/artifact-pack'
if (-not $OutDir) {
  # The committed pack is published with the site: never write live tenant names into it.
  if (-not $Canonicalize) { throw "Pass -Canonicalize to write into the committed pack ($committedPack), or -OutDir for a live export." }
  $OutDir = $committedPack
}

# Is this principal one of this estate's accounts (<alias>.<estate>@<domain>)?
function Test-EstatePrincipal([string]$Upn) { $Upn -like "*.$Estate@*" }

# Copies of the rows with live names rewritten to the canon's; the originals stay live for later joins.
$estateRx = [regex]::Escape($Estate)
function ConvertTo-Canon($Rows) {
  foreach ($r in $Rows) {
    $c = $r.PSObject.Copy()
    if ($Canonicalize) {
      foreach ($prop in $c.PSObject.Properties) {
        if ($prop.Value -isnot [string]) { continue }
        $v = $prop.Value -replace "([A-Za-z0-9._-]+)\.$estateRx@[A-Za-z0-9.-]+", '$1@halcourtmutual.onmicrosoft.com'
        $v = $v -replace " \($estateRx\)", ''
        $prop.Value = $v -replace "-$estateRx\b", ''
      }
    }
    $c
  }
}
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

# --- Power Platform admin API through az ----------------------------------------------------------------
# This used to drive Microsoft.PowerApps.Administration.PowerShell, which is why Phase 7 was documented as
# "run it on the Windows build VM": Add-PowerAppsAccount needs System.Windows.Forms for its sign-in and dies
# on Linux with "Could not load file or assembly 'System.Windows.Forms'". The same data is available over
# REST with az's sign-in - the approach 02/04/99 already use - so Phase 7 now runs anywhere. These shims
# keep the shapes the exports below were written against.
$bapRoot = 'https://api.bap.microsoft.com'
$ppRoot  = 'https://api.powerapps.com/providers/Microsoft.PowerApps'
function Invoke-Pp([string]$Url) {
  $out = az rest --method GET --url $Url --resource 'https://service.powerapps.com/' 2>$null
  if ($LASTEXITCODE -or -not $out) { return $null }
  ($out | Out-String) | ConvertFrom-Json
}
function Get-AdminPowerAppEnvironment {
  foreach ($e in (Invoke-Pp "$bapRoot/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2021-04-01").value) {
    [pscustomobject]@{
      EnvironmentName = $e.name
      DisplayName     = $e.properties.displayName
      EnvironmentType = $e.properties.environmentSku      # Default / Production / Sandbox / Developer
      Internal        = $e                                 # .properties.governanceConfiguration / .linkedEnvironmentMetadata
    }
  }
}
function Get-AdminPowerAppConnection([string]$EnvironmentName) {
  foreach ($c in (Invoke-Pp "$ppRoot/scopes/admin/environments/$EnvironmentName/connections?api-version=2016-11-01").value) {
    # [verify] The module surfaced an auth type; REST does not. Derive the two values the canon uses for
    # real Power Platform connections - a service account's, or a maker's delegated sign-in.
    $upn = $c.properties.createdBy.userPrincipalName
    [pscustomobject]@{
      ConnectionName           = $c.name
      DisplayName              = $c.properties.displayName
      ConnectorName            = ($c.properties.apiId -split '/')[-1]
      CreatedBy                = $c.properties.createdBy
      ConnectionParametersType = if ($upn -like 'svc-*') { 'Service account' } else { 'User (delegated)' }
      Internal                 = $c
    }
  }
}
function Get-AdminPowerAppConnectionRoleAssignment {
  param([string]$EnvironmentName, [string]$ConnectorName, [string]$ConnectionName)
  $url = "$ppRoot/scopes/admin/environments/$EnvironmentName/apis/$ConnectorName/connections/$ConnectionName/roleAssignments?api-version=2016-11-01"
  foreach ($r in (Invoke-Pp $url).value) {
    [pscustomobject]@{
      PrincipalType        = $r.properties.principal.type
      PrincipalDisplayName = if ($r.properties.principal.displayName) { $r.properties.principal.displayName } else { $r.properties.principal.email }
    }
  }
}
function Get-DlpPolicy {
  Invoke-Pp "$bapRoot/providers/PowerPlatform.Governance/v1/policies?api-version=2016-11-01"
}
# AuditLog.Read.All: users-export reads signInActivity, which Graph refuses without it.
# employeeLeaveDateTime needs no scope of its own on the reused az token (Directory.AccessAsUser.All covers
# it for the admin); naming User-LifeCycleInfo.Read.All here would force device code on every run.
. (Join-Path $PSScriptRoot '_auth.ps1')
Connect-LabGraph -Scopes 'User.Read.All','Application.Read.All','AuditLog.Read.All' -FallbackScopes 'User-LifeCycleInfo.Read.All'
if (-not (Get-MgContext)) { throw 'Connect-MgGraph did not establish a session.' }

Write-Host "Writing artifact pack to $OutDir"

# Enumerate environments once; reused by the agent, connection and environment exports.
# This estate's: its <name>-<estate> environments plus the tenant's (shared) default environment.
$environments = Get-AdminPowerAppEnvironment |
  Where-Object { $_.EnvironmentType -eq 'Default' -or $_.DisplayName -like "*-$Estate" }
Write-Host "Estate '$Estate': $(($environments | ForEach-Object DisplayName) -join ', ')"

# Helper: acquire a Dataverse bearer token for an environment's org URL so we can read the `bot` table.
function Get-DataverseToken {
  param([string]$ResourceUrl)
  # Copilot Studio agents live in the Dataverse `bot` table; there is no stable first-party cmdlet to
  # list agents across environments, so we read the table directly over the Web API.
  # The token comes from the Azure CLI: the PowerApps admin module's sign-in app can't get Dataverse
  # tokens (AADSTS65002 - Microsoft doesn't pre-authorize it) and has no Get-PowerAppsAccount any more.
  # Needs `az login` against the lab tenant in this shell (Phase 0.4) - in the Windows build VM too.
  $token = az account get-access-token --resource $ResourceUrl --query accessToken -o tsv
  if ($LASTEXITCODE -or -not $token) { throw "az could not get a Dataverse token for $ResourceUrl - run 'az login' against the lab tenant first." }
  return $token
}

# --------------------------------------------------------------------------------------------------
# 1) agents-export.csv
#    Every Copilot Studio agent across ALL environments (incl. personal/sandbox).
# --------------------------------------------------------------------------------------------------
Write-Host 'Exporting agents -> agents-export.csv'
$agents = foreach ($env in $environments) {
  $orgUrl = $env.Internal.properties.linkedEnvironmentMetadata.instanceApiUrl
  if (-not $orgUrl) { continue }  # environment has no Dataverse (bots require Dataverse)
  # [verify] Dataverse `bot` table over the Web API — agent inventory surface still evolving (Agent 365).
  $token = Get-DataverseToken -ResourceUrl $orgUrl
  # NO 'description': the bot entity has no such column (selecting it fails with 0x80060888, "Could not
  # find a property named 'description'"). The pack's description text is CANON, written by hand - see the
  # preserve step after this loop, which keeps it rather than blanking it.
  $select = 'name,statecode,createdon,modifiedon,publishedon,_ownerid_value'
  # owninguser, not ownerid: ownerid is the polymorphic `principal` type, which has no domainname (400).
  $uri = "$orgUrl/api/data/v9.2/bots?`$select=$select&`$expand=owninguser(`$select=domainname)"
  try {
    $resp = Invoke-RestMethod -Method Get -Uri $uri -Headers @{
      Authorization        = "Bearer $token"
      Accept               = 'application/json'
      'OData-MaxVersion'   = '4.0'
      'OData-Version'      = '4.0'
      Prefer               = 'odata.include-annotations="*"'
    }
  } catch {
    # 403 "has not been assigned any roles": the admin needs a security role in every Dataverse environment.
    throw "Reading agents in '$($env.DisplayName)' failed: $($_.ErrorDetails.Message) - if the admin has no role there: pac admin assign-user --environment $($env.EnvironmentName) --user <admin UPN> --role 'System Administrator'"
  }
  foreach ($bot in $resp.value) {
    # The default environment is shared: keep only agents owned by this estate's accounts.
    if ($env.EnvironmentType -eq 'Default' -and -not (Test-EstatePrincipal $bot.owninguser.domainname)) { continue }
    [pscustomobject]@{
      display_name      = $bot.name
      environment       = $env.DisplayName
      owner_upn         = $bot.owninguser.domainname
      status            = if ($bot.statecode -eq 0) { 'Active' } else { 'Inactive' }
      published         = if ($bot.publishedon) { 'Yes' } else { 'No' }
      created_utc       = if ($bot.createdon)  { ([datetime]$bot.createdon).ToString('yyyy-MM-dd') } else { '' }
      last_modified_utc = if ($bot.modifiedon) { ([datetime]$bot.modifiedon).ToString('yyyy-MM-dd') } else { '' }
      description       = ''   # canon, not tenant data - filled in from the existing pack just below
    }
  }
}
# 'description' exists only in the pack (and AGENTS.md); no API returns it. Carry the committed text over by
# display name so regenerating the pack reports live drift WITHOUT wiping hand-written canon. A new agent
# lands with an empty description for someone to write.
$agentsCsv = Join-Path $OutDir 'agents-export.csv'
if (Test-Path $agentsCsv) {
  $priorDesc = @{}
  foreach ($row in (Import-Csv $agentsCsv)) { if ($row.description) { $priorDesc[$row.display_name] = $row.description } }
  foreach ($a in $agents) {
    $canonName = if ($Canonicalize) { ($a.display_name -replace " \($estateRx\)", '') } else { $a.display_name }
    if ($priorDesc.ContainsKey($canonName)) { $a.description = $priorDesc[$canonName] }
  }
}
ConvertTo-Canon $agents |
  Select-Object display_name,environment,owner_upn,status,published,created_utc,last_modified_utc,description |
  Export-Csv -NoTypeInformation -Encoding UTF8 -UseQuotes AsNeeded $agentsCsv

# --------------------------------------------------------------------------------------------------
# 2) connections-export.csv
#    Connections across environments joined to connector + owner + sharing + consuming agent.
# --------------------------------------------------------------------------------------------------
Write-Host 'Exporting connections -> connections-export.csv'
# Build agent -> environment lookup so we can attribute a connection to the agent that uses it.
$agentByEnv = $agents | Group-Object environment -AsHashTable -AsString

$connections = foreach ($env in $environments) {
  foreach ($conn in (Get-AdminPowerAppConnection -EnvironmentName $env.EnvironmentName)) {
    if ($env.EnvironmentType -eq 'Default' -and -not (Test-EstatePrincipal $conn.CreatedBy.userPrincipalName)) { continue }
    # Sharing principals (owner is excluded from the "shared_with" audience list).
    $shares = @()
    try {
      $shares = Get-AdminPowerAppConnectionRoleAssignment `
                  -EnvironmentName $env.EnvironmentName `
                  -ConnectorName $conn.ConnectorName `
                  -ConnectionName $conn.ConnectionName |
                Where-Object { $_.PrincipalType -ne 'Owner' } |
                ForEach-Object { $_.PrincipalDisplayName }
    } catch { }  # [verify] connection role-assignment cmdlet naming across module versions
    [pscustomobject]@{
      connection_name      = $conn.DisplayName
      connector            = $conn.ConnectorName
      environment          = $env.DisplayName
      connection_owner_upn = $conn.CreatedBy.userPrincipalName
      shared_with          = ($shares -join ';')
      used_by_agent        = ($agentByEnv[$env.DisplayName] | Select-Object -First 1).display_name  # [verify] precise conn->agent binding
      auth_type            = $conn.ConnectionParametersType  # [verify] auth-type surfacing varies by connector
    }
  }
}
ConvertTo-Canon $connections |
  Select-Object connection_name,connector,environment,connection_owner_upn,shared_with,used_by_agent,auth_type |
  Export-Csv -NoTypeInformation -Encoding UTF8 -UseQuotes AsNeeded (Join-Path $OutDir 'connections-export.csv')

# --------------------------------------------------------------------------------------------------
# 3) agent-identities-export.csv
#    Each agent's auto-created Entra identity (the "since March 2026" cs-agent-* principals).
# --------------------------------------------------------------------------------------------------
Write-Host 'Exporting agent identities -> agent-identities-export.csv'
# Copilot Studio auto-provisions a service principal per published agent. It is named
# "<agent display name> (Microsoft Copilot Studio)" - NOT the canon's cs-agent-<slug>-<env>, which was a
# guess and matched nothing, so this export silently produced an empty file (verified 2026-09-23).
# Filter client-side: Graph cannot do endswith/contains on displayName without advanced query, and a lab
# tenant's service-principal list is small.
$agentSuffix = ' (Microsoft Copilot Studio)'
$agentSps = Get-MgServicePrincipal -All -Property 'displayName,appId,createdDateTime' |
            Where-Object { $_.DisplayName -and $_.DisplayName.EndsWith($agentSuffix) } |
            Sort-Object displayName
# Publishing an agent mints a NEW identity and teardown removes none, so a rebuilt estate accumulates one
# stale principal per agent per build. Keep only the newest for each agent name - the one the live agent
# actually runs as - or the pack shows an agent three times. (The strays are real, and worth a look in their
# own right; see the teardown note in the errata.)
# The SDK does not always project createdDateTime onto the typed property even when asked for it; it then
# turns up in AdditionalProperties. Read both, or every row's date comes out blank.
function Get-SpCreated($Sp) {
  if ($Sp.CreatedDateTime) { return $Sp.CreatedDateTime }
  if ($Sp.AdditionalProperties -and $Sp.AdditionalProperties['createdDateTime']) { return $Sp.AdditionalProperties['createdDateTime'] }
  $null
}
$agentSps = $agentSps | Group-Object DisplayName | ForEach-Object {
  $_.Group | Sort-Object @{ Expression = { Get-SpCreated $_ } } -Descending | Select-Object -First 1
}
$identities = foreach ($sp in $agentSps) {
  # Read createdDateTime from the service principal itself: these agent identities have no application
  # object in the tenant, so the old SP->application join always came back empty.
  $created = Get-SpCreated $sp
  # The identity carries the agent's display name verbatim, so match on that. Identities are tenant-wide and
  # survive their agent, so one matching none of this estate's agents belongs to another estate (or to an
  # agent already deleted) - skip it.
  $spAgentName = $sp.DisplayName.Substring(0, $sp.DisplayName.Length - $agentSuffix.Length)
  $matchAgent = $agents | Where-Object { $_.display_name -eq $spAgentName } | Select-Object -First 1
  if (-not $matchAgent) { continue }
  [pscustomobject]@{
    agent               = $matchAgent.display_name
    entra_identity      = $sp.DisplayName
    app_id              = $sp.AppId
    identity_created_utc = if ($created) { ([datetime]$created).ToString('yyyy-MM-dd') } else { '' }
  }
}
ConvertTo-Canon $identities |
  Select-Object agent,entra_identity,app_id,identity_created_utc |
  Export-Csv -NoTypeInformation -Encoding UTF8 -UseQuotes AsNeeded (Join-Path $OutDir 'agent-identities-export.csv')

# --------------------------------------------------------------------------------------------------
# 4) users-export.csv  (reveals the departed-but-enabled owner + service/shared accounts)
# --------------------------------------------------------------------------------------------------
Write-Host 'Exporting users -> users-export.csv'
$mailboxTypeByUpn = @{}
# [verify] shared-mailbox flag is an Exchange attribute, not a Graph user property; join if EXO is available.
try {
  Get-Mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited -ErrorAction Stop |
    ForEach-Object { $mailboxTypeByUpn[$_.UserPrincipalName] = $true }
} catch { }
$users = Get-MgUser -All -Property 'userPrincipalName,displayName,accountEnabled,employeeLeaveDateTime,signInActivity' |
  Where-Object { Test-EstatePrincipal $_.UserPrincipalName } |   # this estate's accounts only
  ForEach-Object {
    $last = $_.SignInActivity.LastSignInDateTime
    [pscustomobject]@{
      upn               = $_.UserPrincipalName
      display_name      = $_.DisplayName
      account_enabled   = ([string]$_.AccountEnabled).ToUpper()
      # Entra's leaver record (Lifecycle Workflows act on it). Tom Dean has one and is still enabled.
      employee_leave_date = if ($_.EmployeeLeaveDateTime) { ([datetime]$_.EmployeeLeaveDateTime).ToString('yyyy-MM-dd') } else { '' }
      last_sign_in_utc  = if ($last) { ([datetime]$last).ToString('yyyy-MM-dd') } else { '' }
      # Heuristic classification — the estate uses svc-* / *service* for service accounts.
      is_service_account = (($_.UserPrincipalName -like 'svc-*') -or ($_.DisplayName -match 'Service Account')).ToString().ToUpper()
      is_shared_mailbox  = ([bool]$mailboxTypeByUpn[$_.UserPrincipalName]).ToString().ToUpper()
    }
  }
ConvertTo-Canon $users |
  Select-Object upn,display_name,account_enabled,employee_leave_date,last_sign_in_utc,is_service_account,is_shared_mailbox |
  Export-Csv -NoTypeInformation -Encoding UTF8 -UseQuotes AsNeeded (Join-Path $OutDir 'users-export.csv')

# --------------------------------------------------------------------------------------------------
# 5) environments-export.csv
# --------------------------------------------------------------------------------------------------
Write-Host 'Exporting environments -> environments-export.csv'
# DLP policies are tenant/environment scoped; build an env -> policy-name lookup.
$dlpByEnv = @{}
try {
  foreach ($p in (Get-DlpPolicy).value) {
    foreach ($e in $p.environments) { $dlpByEnv[$e.name] = $p.displayName }
  }
} catch { }  # [verify] Get-DlpPolicy shape / cmdlet name across module versions
$envRows = foreach ($env in $environments) {
  $maker = switch ($env.EnvironmentType) {
    'Default'    { 'All users' }
    'Production' { 'Makers group' }
    'Sandbox'   { 'Claims team' }
    'Developer' { 'Individual maker' }
    default     { '' }
  }  # [verify] maker_access is a security-group assignment, not a native env property — mapped by env role
  [pscustomobject]@{
    environment = $env.DisplayName
    type        = $env.EnvironmentType
    dlp_policy  = $dlpByEnv[$env.EnvironmentName]
    managed     = if ($env.Internal.properties.governanceConfiguration.protectionLevel -eq 'Standard') { 'Yes' } else { 'No' }  # [verify] managed-env flag path
    maker_access = $maker
  }
}
# Order by environment type rather than however the admin API happened to return them, so re-running the
# export produces a stable file and `git diff` shows real change instead of reshuffled rows. This order
# (Default, Production, Sandbox, Developer) is also the canon's.
$typeOrder = @{ Default = 0; Production = 1; Sandbox = 2; Developer = 3 }
ConvertTo-Canon ($envRows | Sort-Object @{ Expression = { $typeOrder[[string]$_.type] } }, environment) |
  Select-Object environment,type,dlp_policy,managed,maker_access |
  Export-Csv -NoTypeInformation -Encoding UTF8 -UseQuotes AsNeeded (Join-Path $OutDir 'environments-export.csv')

# --------------------------------------------------------------------------------------------------
# 6) files-export.csv  (the knowledge sites' files and their sensitivity labels - 05-06)
# --------------------------------------------------------------------------------------------------
# Attendees can't open Leadership/ (it drops the visitors - that is Scenario B), so the labelled and
# unlabelled comp copies are listed here. The label is the library's Sensitivity column (_DisplayName):
# the items API refuses to $select it, RenderListDataAsStream returns it. Read with the lab app 03c makes
# (Sites.FullControl.All), so Phase 4c has to have run.
Write-Host 'Exporting knowledge-site files -> files-export.csv'
. (Join-Path $PSScriptRoot '_labapp.ps1')          # its default paths: setup/lab-compliance-app.local.*
$spRoot = ([uri](Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/sites/root').webUrl).GetLeftPart('Authority')
$spHeaders = @{ Authorization = "Bearer $(Get-AppToken $spRoot)"; Accept = 'application/json;odata=nometadata' }
$view = '<View Scope="RecursiveAll"><ViewFields><FieldRef Name="FileRef"/><FieldRef Name="FSObjType"/><FieldRef Name="_DisplayName"/></ViewFields><RowLimit>1000</RowLimit></View>'
$fileRows = foreach ($canon in 'HR-Benefits', 'Claims-Knowledge') {
  $site = "$spRoot/sites/$(Get-EstateName $canon $Estate)"
  $libs = (Invoke-RestMethod -Uri "$site/_api/web/lists?`$select=Title,RootFolder/ServerRelativeUrl&`$expand=RootFolder&`$filter=BaseTemplate eq 101 and Hidden eq false" -Headers $spHeaders).value |
    Where-Object { $_.Title -notin 'Form Templates', 'Site Assets', 'Style Library' }
  foreach ($lib in $libs) {
    $body = @{ parameters = @{ RenderOptions = 2; ViewXml = $view } } | ConvertTo-Json -Depth 5
    $root = $lib.RootFolder.ServerRelativeUrl.TrimEnd('/') + '/'
    (Invoke-RestMethod -Method POST -Uri "$site/_api/web/lists/getbytitle('$($lib.Title)')/RenderListDataAsStream" -Headers $spHeaders -ContentType 'application/json' -Body $body).Row |
      Where-Object { "$($_.FSObjType)" -eq '0' } | ForEach-Object {
        [pscustomobject]@{
          site              = Get-EstateName $canon $Estate
          library           = $lib.Title
          path              = $_.FileRef.Substring($root.Length)
          sensitivity_label = "$($_._DisplayName)"
        }
      }
  }
}
ConvertTo-Canon ($fileRows | Sort-Object site, library, path) |
  Select-Object site,library,path,sensitivity_label |
  Export-Csv -NoTypeInformation -Encoding UTF8 -UseQuotes AsNeeded (Join-Path $OutDir 'files-export.csv')

if ($Canonicalize -and $OutDir -eq $committedPack) {
  Write-Host 'Phase 7 complete. Review the drift with: git diff worksheets/artifact-pack'
} else {
  Write-Host "Phase 7 complete: $OutDir$(if (-not $Canonicalize) { ' (live names - add -Canonicalize to compare with the committed pack)' })"
}
