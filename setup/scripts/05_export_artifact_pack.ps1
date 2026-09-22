<#
FACILITATOR-ONLY. Phase 7 — Export the artifact pack.

Pulls the estate from the Power Platform admin APIs + Microsoft Graph and writes the five canonical CSVs
that attendees analyze offline. The committed files in ../worksheets/artifact-pack/ ARE the expected
output for the canonical estate — diff against them after any change.

Estate (setup/scripts/_estate.ps1): exports only this build's estate - its <name>-<estate> environments,
plus agents/connections in the shared default environment owned by its <alias>.<estate>@ accounts, and only
those accounts (no admins or sample users). -Canonicalize rewrites live names to the canon's (strips the
estate id, restores @halcourtmutual.onmicrosoft.com), so the output diffs cleanly against the committed pack:

  pwsh setup/scripts/05_export_artifact_pack.ps1 -Estate mgray -Canonicalize
  git diff worksheets/artifact-pack

Without -Canonicalize it refuses to write into the committed (published) pack - pass -OutDir.

Requires: Microsoft.PowerApps.Administration.PowerShell, Microsoft.Graph.
Lines marked [verify] depend on evolving 2026 admin/Graph surfaces (agent + workload identity listings).
#>
param(
  [string]$Estate = $env:HALCOURT_ESTATE,     # this build's estate id, e.g. mgray (see _estate.ps1)
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
Add-PowerAppsAccount | Out-Null
# AuditLog.Read.All: users-export reads signInActivity, which Graph refuses without it.
. (Join-Path $PSScriptRoot '_auth.ps1')
Connect-LabGraph -Scopes 'User.Read.All','Application.Read.All','AuditLog.Read.All'
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
  $select = 'name,statecode,createdon,modifiedon,publishedon,description,_ownerid_value'
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
      description       = $bot.description
    }
  }
}
ConvertTo-Canon $agents |
  Select-Object display_name,environment,owner_upn,status,published,created_utc,last_modified_utc,description |
  Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutDir 'agents-export.csv')

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
  Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutDir 'connections-export.csv')

# --------------------------------------------------------------------------------------------------
# 3) agent-identities-export.csv
#    Each agent's auto-created Entra identity (the "since March 2026" cs-agent-* principals).
# --------------------------------------------------------------------------------------------------
Write-Host 'Exporting agent identities -> agent-identities-export.csv'
# [verify] Copilot Studio auto-provisions a service principal per published agent named cs-agent-*;
# the SP-to-agent link is by naming convention (no first-party join API confirmed for 2026).
$agentSps = Get-MgServicePrincipal -All -Filter "startswith(displayName,'cs-agent-')" `
              -Property 'displayName,appId,additionalProperties' |
            Sort-Object displayName
$identities = foreach ($sp in $agentSps) {
  # createdDateTime is not returned on servicePrincipal by default — read the backing application.
  $created = $null
  try {
    $app = Get-MgApplication -Filter "appId eq '$($sp.AppId)'" -Property 'createdDateTime' -Top 1
    $created = $app.CreatedDateTime
  } catch { }  # [verify] SP->application creation-date join
  # Map identity back to an agent display name via the cs-agent-<slug> naming convention.
  $matchAgent = $agents | Where-Object {
    $sp.DisplayName -like ('cs-agent-*' + (($_.display_name -replace '[^a-zA-Z0-9]+','-').ToLower()) + '*')
  } | Select-Object -First 1
  # cs-agent-* identities are tenant-wide; one that matches none of this estate's agents is another estate's.
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
  Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutDir 'agent-identities-export.csv')

# --------------------------------------------------------------------------------------------------
# 4) users-export.csv  (reveals the disabled owner + service/shared accounts)
# --------------------------------------------------------------------------------------------------
Write-Host 'Exporting users -> users-export.csv'
$mailboxTypeByUpn = @{}
# [verify] shared-mailbox flag is an Exchange attribute, not a Graph user property; join if EXO is available.
try {
  Get-Mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited -ErrorAction Stop |
    ForEach-Object { $mailboxTypeByUpn[$_.UserPrincipalName] = $true }
} catch { }
$users = Get-MgUser -All -Property 'userPrincipalName,displayName,accountEnabled,signInActivity' |
  Where-Object { Test-EstatePrincipal $_.UserPrincipalName } |   # this estate's accounts only
  ForEach-Object {
    $last = $_.SignInActivity.LastSignInDateTime
    [pscustomobject]@{
      upn               = $_.UserPrincipalName
      display_name      = $_.DisplayName
      account_enabled   = ([string]$_.AccountEnabled).ToUpper()
      last_sign_in_utc  = if ($last) { ([datetime]$last).ToString('yyyy-MM-dd') } else { '' }
      # Heuristic classification — the estate uses svc-* / *service* for service accounts.
      is_service_account = (($_.UserPrincipalName -like 'svc-*') -or ($_.DisplayName -match 'Service Account')).ToString().ToUpper()
      is_shared_mailbox  = ([bool]$mailboxTypeByUpn[$_.UserPrincipalName]).ToString().ToUpper()
    }
  }
ConvertTo-Canon $users |
  Select-Object upn,display_name,account_enabled,last_sign_in_utc,is_service_account,is_shared_mailbox |
  Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutDir 'users-export.csv')

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
ConvertTo-Canon $envRows |
  Select-Object environment,type,dlp_policy,managed,maker_access |
  Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutDir 'environments-export.csv')

if ($Canonicalize -and $OutDir -eq $committedPack) {
  Write-Host 'Phase 7 complete. Review the drift with: git diff worksheets/artifact-pack'
} else {
  Write-Host "Phase 7 complete: $OutDir$(if (-not $Canonicalize) { ' (live names - add -Canonicalize to compare with the committed pack)' })"
}
