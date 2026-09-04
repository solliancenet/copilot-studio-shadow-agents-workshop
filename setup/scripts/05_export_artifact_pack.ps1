<#
FACILITATOR-ONLY. Phase 7 — Export the artifact pack.

Pulls the estate from the Power Platform admin APIs + Microsoft Graph and writes the five canonical CSVs
that attendees analyze offline. The committed files in ../worksheets/artifact-pack/ ARE the expected
output for the canonical estate — diff against them after any change.

Requires: Microsoft.PowerApps.Administration.PowerShell, Microsoft.Graph.
Lines marked [verify] depend on evolving 2026 admin/Graph surfaces (agent + workload identity listings).
#>
param(
  [string]$OutDir = (Join-Path (Split-Path -Parent (Split-Path -Parent $PSCommandPath)) 'worksheets/artifact-pack')
)
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
Add-PowerAppsAccount | Out-Null
Connect-MgGraph -Scopes 'User.Read.All','Application.Read.All' | Out-Null

Write-Host "Writing artifact pack to $OutDir"

# Enumerate environments once; reused by the agent, connection and environment exports.
$environments = Get-AdminPowerAppEnvironment

# Helper: acquire a Dataverse bearer token for an environment's org URL so we can read the `bot` table.
function Get-DataverseToken {
  param([string]$ResourceUrl)
  # [verify] Copilot Studio agents live in the Dataverse `bot` table; there is no stable first-party
  # cmdlet to list agents across environments in 2026, so we read the table directly over the Web API.
  (Get-MgContext) | Out-Null
  return (Get-PowerAppsAccount).AccessToken  # [verify] token brokering for Dataverse per-env resource
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
  $uri = "$orgUrl/api/data/v9.2/bots?`$select=$select&`$expand=ownerid(`$select=domainname)"
  $resp = Invoke-RestMethod -Method Get -Uri $uri -Headers @{
    Authorization        = "Bearer $token"
    Accept               = 'application/json'
    'OData-MaxVersion'   = '4.0'
    'OData-Version'      = '4.0'
    Prefer               = 'odata.include-annotations="*"'
  }
  foreach ($bot in $resp.value) {
    [pscustomobject]@{
      display_name      = $bot.name
      environment       = $env.DisplayName
      owner_upn         = $bot.ownerid.domainname
      status            = if ($bot.statecode -eq 0) { 'Active' } else { 'Inactive' }
      published         = if ($bot.publishedon) { 'Yes' } else { 'No' }
      created_utc       = if ($bot.createdon)  { ([datetime]$bot.createdon).ToString('yyyy-MM-dd') } else { '' }
      last_modified_utc = if ($bot.modifiedon) { ([datetime]$bot.modifiedon).ToString('yyyy-MM-dd') } else { '' }
      description       = $bot.description
    }
  }
}
$agents |
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
$connections |
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
  [pscustomobject]@{
    agent               = if ($matchAgent) { $matchAgent.display_name } else { $sp.DisplayName }
    entra_identity      = $sp.DisplayName
    app_id              = $sp.AppId
    identity_created_utc = if ($created) { ([datetime]$created).ToString('yyyy-MM-dd') } else { '' }
  }
}
$identities |
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
$users |
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
$envRows |
  Select-Object environment,type,dlp_policy,managed,maker_access |
  Export-Csv -NoTypeInformation -Encoding UTF8 (Join-Path $OutDir 'environments-export.csv')

Write-Host 'Phase 7 complete. Diff the output against the committed artifact pack; investigate any drift.'
