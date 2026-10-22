<#
FACILITATOR-ONLY. Phase 6 - provision the Copilot Studio agents from committed workspaces.

Reads setup/agents/manifest.json and, for the whole estate:
  1. verifies each agent owner is licensed and is a user in its environment with a maker role;
  2. ensures each OAuth connection exists and is authenticated as its owner (headless consent);
  3. for each agent with a committed workspace, pushes it AS ITS OWNER (so owner/createdby are the persona),
     retargets the publisher prefix to the environment, binds connection references, sets the chat audience,
     publishes, and records the Entra agent identity.

Agents are DATA: the pac workspace under setup/agents/<slug>/ holds instructions/knowledge/tools; the
manifest holds owner/environment/connections/audience. Benign agents are authored+committed here; the six
planted agents are captured once with `pac copilot clone` and committed (capture:"clone").

Prerequisites (run first): the shared Phase 1 values (setup/lab-endpoints.local.json, from the deployment's
owner), 01 (personas+groups), 03/03b (SharePoint+OneDrive grounding), 04 (Dataverse), owner licenses,
default-environment Dataverse, and a billing plan on Prod+Claims-Test. See RUNBOOK Phase 6.

Auth: az's admin sign-in for BAP/Graph/Dataverse admin calls; per-owner password sign-in (ROPC + a pac
auth profile) so each agent is built as its persona. The CA baseline only MFAs admins, so persona
password sign-in works. Lab-only password.

  pwsh setup/scripts/06_provision_agents.ps1 -VerifyOnly            # resolve + report, change nothing
  pwsh setup/scripts/06_provision_agents.ps1                        # full run
  pwsh setup/scripts/06_provision_agents.ps1 -Agents hr-faq-v2      # one agent
#>
param(
  [string]$Estate      = $env:HALCOURT_ESTATE,
  [string]$TenantId,                                   # default: from az account
  [string]$DomainSuffix,                               # default: tenant's default verified domain
  [string]$LabPassword = 'Lab-Only-Passw0rd!',
  [string[]]$Agents,                                   # slugs to limit to; default: all with a workspace
  [string]$TargetEnvironment,                          # build into THIS environment instead of the manifest's
                                                       # (per-student slices, Phase 8c); use with -Agents
  [string]$DisplayNameSuffix,                          # slice builds: keeps each slice's agent - and so its
                                                       # tenant-wide Entra identity - distinguishable.
                                                       # APPLIES ON FIRST BUILD ONLY: a rebuild pushes the
                                                       # committed workspace's own name and renames nothing
  [switch]$SkipConnections,
  [switch]$SkipPrereqs,
  [switch]$VerifyOnly
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_estate.ps1')
$Estate = Resolve-Estate $Estate
$AgentsDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'agents'
$DataDir   = Join-Path (Split-Path $PSScriptRoot -Parent) 'data'
$manifest  = Get-Content (Join-Path $AgentsDir 'manifest.json') -Raw | ConvertFrom-Json
$realPac   = if (Test-Path "$HOME/.dotnet/tools/pac") { "$HOME/.dotnet/tools/pac" } else { 'pac' }

# Committed agent workspaces carry NO secrets/endpoints - they use ${VAR} tokens (e.g. ${POLICY_API_FQDN},
# ${POLICY_API_KEY}, ${UNDERWRITING_MCP_FQDN}, ${MCP_BEARER}) that are substituted at provision time from the
# ONE shared Phase 1 deployment (_lab_endpoints.ps1: the owner's setup/lab-endpoints.local.json, else azd).
# So the planted key lives in the LIVE agent (that IS the vulnerability) but never in git.
. (Join-Path $PSScriptRoot '_lab_endpoints.ps1')
$lab = Get-LabEndpoints
$AzdValues = $lab.Values
if ($lab.Missing.Count) {
  $msg = "Phase 1 values missing from $($lab.Source): $($lab.Missing -join ', '). Get setup/lab-endpoints.local.json from the shared deployment's owner (RUNBOOK Phase 1)."
  if ($VerifyOnly) { Write-Warning $msg } else { throw $msg }
} else { Write-Host "Phase 1 endpoints from $($lab.Source)" }
$AzClient  = '04b07795-8ddb-461a-bbee-02f9e1bf7b46'   # Azure CLI public client (for persona ROPC)

# ---- identity / tenant --------------------------------------------------------------------------------
if (-not $TenantId)     { $TenantId = az account show --query tenantId -o tsv }
if (-not $DomainSuffix) {
  $DomainSuffix = az rest --method GET --url 'https://graph.microsoft.com/v1.0/organization?$select=verifiedDomains' `
    --query "value[0].verifiedDomains[?isDefault].name | [0]" -o tsv
}
# SharePoint hosts come from the tenant's INITIAL domain (<prefix>.onmicrosoft.com -> <prefix>.sharepoint.com),
# which is what the committed knowledge sources reference as ${SP_HOST} / ${SP_MY_HOST}.
$SpPrefix = (az rest --method GET --url 'https://graph.microsoft.com/v1.0/organization?$select=verifiedDomains' `
  --query "value[0].verifiedDomains[?isInitial].name | [0]" -o tsv).Split('.')[0]
function Get-Upn([string]$Alias) { "$(Get-EstateAlias $Alias $Estate)@$DomainSuffix" }

# ---- tokens -------------------------------------------------------------------------------------------
$script:AdminTokens = @{}
function Get-AdminToken([string]$Resource) {
  if (-not $script:AdminTokens[$Resource]) {
    $script:AdminTokens[$Resource] = az account get-access-token --resource $Resource --query accessToken -o tsv
  }
  $script:AdminTokens[$Resource]
}
$script:PersonaTokens = @{}
function Get-PersonaToken([string]$Alias, [string]$Resource) {
  $key = "$Alias|$Resource"
  if (-not $script:PersonaTokens[$key]) {
    $body = @{ client_id = $AzClient; grant_type = 'password'; username = (Get-Upn $Alias); password = $LabPassword; scope = "$($Resource.TrimEnd('/'))/.default" }
    $script:PersonaTokens[$key] = (Invoke-RestMethod -Method POST -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Body $body).access_token
  }
  $script:PersonaTokens[$key]
}
function Invoke-Json([string]$Method, [string]$Uri, [string]$Token, $Body) {
  $h = @{ Authorization = "Bearer $Token"; Accept = 'application/json' }
  if ($null -ne $Body) { Invoke-RestMethod -Method $Method -Uri $Uri -Headers $h -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 30) }
  else                 { Invoke-RestMethod -Method $Method -Uri $Uri -Headers $h }
}
$BAP = 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform'
function Invoke-Bap([string]$Method, [string]$Path, $Body, [string]$Api = '2021-04-01') {
  $sep = if ($Path.Contains('?')) { '&' } else { '?' }
  Invoke-Json $Method ("$BAP/$Path" + $sep + "api-version=$Api") (Get-AdminToken 'https://service.powerapps.com/') $Body
}

# ---- resolve environments, groups, publisher prefixes -------------------------------------------------
Write-Host "Estate '$Estate' on $DomainSuffix - resolving environments..."
$allEnvs = (Invoke-Bap GET 'scopes/admin/environments').value
function Resolve-Env([string]$Canonical) {
  # -TargetEnvironment redirects EVERY canonical name to one environment. Phase 8c uses it to build an
  # agent and its connections into a per-student slice; the manifest still says Claims-Test, but the
  # slice is where it lands. Only sensible together with -Agents.
  $name = if ($TargetEnvironment) { $TargetEnvironment }
          elseif ($manifest.environments.$Canonical -eq 'shared') { $Canonical }
          else { Get-EstateName $Canonical $Estate }
  $e = $allEnvs | Where-Object { $_.properties.displayName -eq $name } | Select-Object -First 1
  if (-not $e) { throw "Environment '$name' not found (canonical '$Canonical')." }
  [pscustomobject]@{ Name = $name; Id = $e.name; Org = $e.properties.linkedEnvironmentMetadata.instanceUrl.TrimEnd('/') }
}
$envCache = @{}
function Env([string]$Canonical) { if (-not $envCache[$Canonical]) { $envCache[$Canonical] = Resolve-Env $Canonical }; $envCache[$Canonical] }
function Get-GroupId([string]$Canonical) {
  $g = Get-EstateName $Canonical $Estate
  (Invoke-Json GET "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$g'&`$select=id" (Get-AdminToken 'https://graph.microsoft.com/')).value[0].id
}
function Get-Prefix([object]$E) {
  $tok = Get-AdminToken $E.Org
  (Invoke-Json GET "$($E.Org)/api/data/v9.2/publishers?`$select=customizationprefix&`$filter=friendlyname eq 'CDS Default Publisher'" $tok).value[0].customizationprefix
}

# ---- Dataverse (as admin, or as a persona) ------------------------------------------------------------
function Invoke-BindWithTempRole([object]$E, [string]$Owner, [string]$CrefId, [string]$ConnId) {
  # Privileges the connection reference PATCH checks on the caller (each named, in turn, by its 403).
  $need = 'prvReadconnectionreference', 'prvWriteconnectionreference', 'prvReadAsyncOperation'
  $bu   = (Dv $E GET 'businessunits?$select=businessunitid&$filter=parentbusinessunitid eq null').value[0].businessunitid
  $name = "Lab-Bind-Temp-$([guid]::NewGuid().ToString('N').Substring(0,6))"
  $rid  = $null; $su = $null
  try {
    # Created inside the try, so a failure at any point still reaches the cleanup below.
    Dv $E POST 'roles' @{ name = $name; 'businessunitid@odata.bind' = "/businessunits($bu)" } | Out-Null
    $rid  = (Dv $E GET "roles?`$select=roleid&`$filter=name eq '$name'").value[0].roleid
    if (-not $rid) { throw "temporary role '$name' was not found after creating it" }
    $privs = foreach ($n in $need) { @{ PrivilegeId = (Dv $E GET "privileges?`$select=privilegeid&`$filter=name eq '$n'").value[0].privilegeid; Depth = 'Global' } }
    Dv $E POST "roles($rid)/Microsoft.Dynamics.CRM.AddPrivilegesRole" @{ Privileges = @($privs) } | Out-Null
    $su = (Dv $E GET "systemusers?`$select=systemuserid&`$filter=domainname eq '$(Get-Upn $Owner)'").value[0].systemuserid
    Dv $E POST "systemusers($su)/systemuserroles_association/`$ref" @{ '@odata.id' = "$($E.Org)/api/data/v9.2/roles($rid)" } | Out-Null
    for ($i = 0; $i -lt 6; $i++) {
      Start-Sleep 20
      try { DvAs $E $Owner PATCH "connectionreferences($CrefId)" @{ connectionid = $ConnId } | Out-Null; return $true } catch { }
    }
    return $false
  } finally {
    if ($su -and $rid) { try { Dv $E DELETE "systemusers($su)/systemuserroles_association($rid)/`$ref" | Out-Null } catch { } }
    # Look the role up by name, not by $rid: the create can succeed and the lookup still come back empty.
    $left = @((Dv $E GET "roles?`$select=roleid&`$filter=name eq '$name'").value)
    foreach ($r in $left) { try { Dv $E DELETE "roles($($r.roleid))" | Out-Null } catch { Write-Warning "    remove the temporary role '$name' by hand" } }
  }
}
function Dv([object]$E, [string]$Method, [string]$Path, $Body) {
  Invoke-Json $Method "$($E.Org)/api/data/v9.2/$Path" (Get-AdminToken $E.Org) $Body
}
function DvAs([object]$E, [string]$Alias, [string]$Method, [string]$Path, $Body) {
  Invoke-Json $Method "$($E.Org)/api/data/v9.2/$Path" (Get-PersonaToken $Alias $E.Org) $Body
}
# Admin first (the norm), falling back to the owner in an owner-managed Developer environment (Maker-Sandbox)
# where the admin has NO Dataverse role, so admin calls throw a security exception (0x80042f09 / prvRead...).
# The owner is at least Environment Maker there (System Administrator in a dev env), so it can do these ops.
function DvAuto([object]$E, [string]$Alias, [string]$Method, [string]$Path, $Body) {
  try { return Dv $E $Method $Path $Body }
  catch {
    if ("$_" -match 'prvRead|prvWrite|prvCreate|has not been assigned any roles|0x80042f09') { return DvAs $E $Alias $Method $Path $Body }
    throw
  }
}

# ---- prereq: owner is a user in its environment with a maker role -------------------------------------
function Ensure-EnvUserRole([object]$E, [string]$Alias, [string]$RoleName) {
  $upn = Get-Upn $Alias
  $oid = az ad user show --id $upn --query id -o tsv
  # Systemuser/role queries run as ADMIN. But a Developer environment (Maker-Sandbox) has the admin with NO
  # Dataverse role - its owner (dev.kim) is the sole System Administrator - so the admin call throws a security
  # exception (0x80042f09 / prvReadUser). There the owner already holds the role by construction and the admin
  # can do nothing, so verify through the OWNER's own token instead.
  $adminCanRead = $true; $u = $null
  try { $u = (Dv $E GET "systemusers?`$select=systemuserid&`$filter=azureactivedirectoryobjectid eq $oid").value }
  catch { if ("$_" -match 'prvReadUser|has not been assigned any roles|0x80042f09') { $adminCanRead = $false } else { throw } }
  if (-not $adminCanRead) {
    try {
      $suid = (DvAs $E $Alias GET 'WhoAmI').UserId
      $have = (DvAs $E $Alias GET "systemusers($suid)/systemuserroles_association?`$select=name").value.name
      if ($have -contains $RoleName) { return "ok ($RoleName, owner-managed env)" }
      return "NEEDS $RoleName - owner-managed env, assign as the env owner"
    } catch { return 'UNVERIFIABLE - admin has no role here and the owner token failed' }
  }
  if (-not $u) {
    if ($VerifyOnly) { return "MISSING (would add + $RoleName)" }
    for ($i=0; $i -lt 4 -and -not $u; $i++) {
      try { Invoke-Bap POST "scopes/admin/environments/$($E.Id)/addUser" @{ ObjectId = $oid } '2020-10-01' | Out-Null } catch { if ($i -eq 3) { throw } ; Start-Sleep 15 }
      Start-Sleep 5
      $u = (Dv $E GET "systemusers?`$select=systemuserid&`$filter=azureactivedirectoryobjectid eq $oid").value
    }
  }
  if (-not $u) { return 'NOT ADDED' }
  $suid = $u[0].systemuserid
  $root = (Dv $E GET "businessunits?`$select=businessunitid&`$filter=_parentbusinessunitid_value eq null").value[0].businessunitid
  $role = (Dv $E GET "roles?`$select=roleid&`$filter=name eq '$RoleName' and _businessunitid_value eq $root").value[0].roleid
  $have = (Dv $E GET "systemusers($suid)/systemuserroles_association?`$select=roleid").value.roleid
  if ($have -contains $role) { return "ok ($RoleName)" }
  if ($VerifyOnly) { return "would assign $RoleName" }
  Dv $E POST "systemusers($suid)/systemuserroles_association/`$ref" @{ '@odata.id' = "$($E.Org)/api/data/v9.2/roles($role)" } | Out-Null
  "assigned $RoleName"
}

# ---- connections (create + headless consent + confirm) ------------------------------------------------
$PA = 'https://api.powerapps.com/providers/Microsoft.PowerApps'
function Pa([string]$Alias, [string]$Method, [string]$Path, $Body, [string]$EnvId) {
  $q = "?api-version=2016-11-01"
  if ($EnvId) { $q += "&`$filter=environment eq '$EnvId'" }
  Invoke-Json $Method "$PA/$Path$q" (Get-PersonaToken $Alias 'https://service.powerapps.com/') $Body
}
# ---- custom connectors (the Underwriting MCP server as a Copilot Studio MCP tool) ---------------------
# Copilot Studio caps a connector's display name at 30 characters and silently truncates; do the same, so a
# rerun finds the connector it made (Halcourt-Underwriting-MCP-<estate> -> ...-mgra for estate mgray).
function Get-CustomConnectorDisplay([object]$Def) { $n = Get-EstateName $Def.customConnector.name $Estate; if ($n.Length -gt 30) { $n.Substring(0, 30) } else { $n } }
$script:CustomConnectors = @{}
function Find-CustomConnector([object]$Def) {
  $E = Env $Def.environment; $want = Get-CustomConnectorDisplay $Def
  $all = (Invoke-Json GET "$PA/apis?api-version=2016-11-01&`$filter=environment eq '$($E.Id)' and IsCustomApi eq 'True'" (Get-PersonaToken $Def.owner 'https://service.powerapps.com/') $null).value
  ($all | Where-Object { $_.properties.displayName -eq $want } | Select-Object -First 1).name
}
function Ensure-CustomConnector([string]$Name, [object]$Def) {
  if ($script:CustomConnectors[$Name]) { return $script:CustomConnectors[$Name] }
  $id = Find-CustomConnector $Def
  if (-not $id -and -not $VerifyOnly) {
    # The MCP wizard's own output, committed (setup/agents/<ws>/mcp-connector): one POST operation marked
    # x-ms-agentic-protocol mcp-streamable-1.0, API-key auth in the Authorization header. Created as the
    # connection's owner with pac, so the connector, its connection and the agent all belong to one maker.
    $src = Join-Path $AgentsDir $Def.customConnector.workspace
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "halcourt-connector/$Name"; New-Item -ItemType Directory -Force $tmp | Out-Null
    $host_ = ([Uri]$AzdValues['UNDERWRITING_MCP_FQDN']).Host
    (Get-Content (Join-Path $src 'apiDefinition.swagger.json') -Raw).Replace('${UNDERWRITING_MCP_HOST}', $host_).Replace('${MCP_CONNECTOR_NAME}', (Get-CustomConnectorDisplay $Def)) |
      Set-Content (Join-Path $tmp 'apiDefinition.swagger.json') -NoNewline
    Copy-Item (Join-Path $src 'apiProperties.json') $tmp -Force
    $E = Env $Def.environment
    $env:XDG_DATA_HOME = Get-PacHome $Def.owner
    & $realPac auth clear 2>&1 | Out-Null
    & $realPac auth create --name $Def.owner --username (Get-Upn $Def.owner) --password $LabPassword --environment $E.Org 2>&1 | Out-Null
    $out = & $realPac connector create --api-definition-file (Join-Path $tmp 'apiDefinition.swagger.json') --api-properties-file (Join-Path $tmp 'apiProperties.json') --environment $E.Org 2>&1
    for ($i = 0; $i -lt 6 -and -not $id; $i++) { Start-Sleep 10; $id = Find-CustomConnector $Def }
    if (-not $id) { throw "custom connector for $Name not created: $(($out | Select-Object -Last 2) -join ' ')" }
  }
  $script:CustomConnectors[$Name] = $id; $id
}
function Get-ConnectorId([string]$Name) {   # the shared_* id, or the generated id of a custom connector
  $def = $manifest.connections.$Name
  if ($def.connector -eq 'custom') { Ensure-CustomConnector $Name $def } else { $def.connector }
}

$script:ConnIds = @{}
function Get-ConnId([string]$Name) {
  if ($script:ConnIds[$Name]) { return $script:ConnIds[$Name] }
  $def = $manifest.connections.$Name; $E = Env $def.environment
  $c = (Pa $def.owner GET "apis/$(Get-ConnectorId $Name)/connections" $null $E.Id).value |
    Where-Object { $_.properties.displayName -eq $Name -and $_.properties.createdBy.userPrincipalName -eq (Get-Upn $def.owner) } | Select-Object -First 1
  if ($c) { $script:ConnIds[$Name] = $c.name }
  $script:ConnIds[$Name]
}
function Ensure-Connection([string]$Name, [object]$Def) {
  $E = Env $Def.environment; $alias = $Def.owner; $connector = Get-ConnectorId $Name
  $upn = Get-Upn $alias
  # -VerifyOnly doesn't create a missing custom connector, so there is nothing to list connections under.
  if (-not $connector) { return 'MISSING (would create the custom connector + connection)' }
  $mine = @((Pa $alias GET "apis/$connector/connections" $null $E.Id).value | Where-Object {
    $_.properties.createdBy.userPrincipalName -eq $upn -and $_.properties.displayName -eq $Name })
  $ok = $mine | Where-Object { @($_.properties.statuses.status) -notcontains 'Error' -and @($_.properties.statuses.status) -contains 'Connected' } | Select-Object -First 1
  if ($ok) { $script:ConnIds[$Name] = $ok.name; return "ok ($($ok.name))" }
  if ($VerifyOnly) { return 'MISSING (would create + consent)' }
  $c = if ($mine) { $mine[0] } else {
    $props = @{ environment = @{ id = "/providers/Microsoft.PowerApps/environments/$($E.Id)"; name = $E.Id }; displayName = $Name }
    if ($Def.params) { $props.connectionParameters = $Def.params }
    if ($Def.apiKeyFrom) { $props.connectionParameters = @{ api_key = "Bearer $($AzdValues[$Def.apiKeyFrom])" } }
    Pa $alias PUT "apis/$connector/connections/$([guid]::NewGuid().ToString('N'))" @{ properties = $props } $E.Id
  }
  if ($Def.apiKeyFrom) {
    # An API-key connection has no OAuth consent: it is Connected (or not) as soon as it exists.
    $st = @((Pa $alias GET "apis/$connector/connections/$($c.name)" $null $E.Id).properties.statuses.status)
    if ($st -contains 'Error') { throw "connection $Name is in Error: $($st -join ',')" }
    $script:ConnIds[$Name] = $c.name; return "created ($($c.name), API key)"
  }
  $link = (Pa $alias POST "apis/$connector/connections/$($c.name)/getConsentLink" @{ redirectUrl = 'https://global.consent.azure-apim.net/redirect' } $E.Id).consentLink
  $out = python3 (Join-Path $PSScriptRoot 'lib/consent_browser.py') --upn $upn --password $LabPassword --consent-url $link 2>&1
  # Some connectors (SharePoint, Dataverse) hand back a short connection code that must be posted to
  # confirmConsentCode; others (Office 365 Outlook) complete the OAuth entirely through the redirect and
  # never yield a code. So post the code when there is one, then verify the connection actually reached
  # 'Connected' rather than trusting the code alone - that is the real success signal for either flow.
  $m = $out | Select-String '^CODE='
  if ($m) {
    $code = $m.ToString() -replace '^CODE='
    # Best effort: a stale or already-redeemed code throws here, but the status check below is what decides.
    try { Pa $alias POST "apis/$connector/connections/$($c.name)/confirmConsentCode" @{ code = $code } $E.Id | Out-Null }
    catch { Write-Host "    (confirmConsentCode rejected the code; checking the connection status instead)" }
  }
  $connected = $false
  for ($i = 0; $i -lt 8 -and -not $connected; $i++) {
    $st = @((Pa $alias GET "apis/$connector/connections/$($c.name)" $null $E.Id).properties.statuses.status)
    if ($st -contains 'Connected' -and $st -notcontains 'Error') { $connected = $true; break }
    Start-Sleep 5
  }
  if (-not $connected) { throw "consent failed for $Name (owner $upn): $($out -join [Environment]::NewLine)" }
  $script:ConnIds[$Name] = $c.name
  "created ($($c.name))"
}

# ---- agent replay -------------------------------------------------------------------------------------
function Get-SchemaName([string]$Workspace) {
  # Anchored so it does NOT also match 'defaultSchemaName:' (Select-String is case-insensitive by default).
  ((Select-String -Path (Join-Path $Workspace 'settings.mcs.yml') -Pattern '^\s*schemaName:\s*(\S+)' | Select-Object -First 1).Matches.Groups[1].Value)
}
function Get-PacHome([string]$Alias) {
  $h = Join-Path ([System.IO.Path]::GetTempPath()) "halcourt-pac/$Alias"
  New-Item -ItemType Directory -Force -Path $h | Out-Null; $h
}
# Each agent keeps its committed publisher prefix; we never rewrite the workspace (that mutates the source
# and can duplicate agents). Instead we ensure a publisher with that prefix EXISTS in the environment, so
# push works on a fresh rebuild too (a torn-down/recreated env has a new random CDS prefix, but the agent's
# own prefix is stable). No-op when the publisher already exists (same-estate replay).
function Ensure-Publisher([object]$E, [string]$Prefix, [string]$Alias) {
  $p = (DvAuto $E $Alias GET "publishers?`$select=publisherid&`$filter=customizationprefix eq '$Prefix'").value
  if ($p) { return }
  # Measure-Object -Sum yields a [double]; ConvertTo-Json would then emit e.g. 10419.0, which Dataverse
  # rejects for the Int32 customizationoptionvalueprefix (0x80048d19). Cast to [int].
  $ovp = [int](10000 + (((([int[]][char[]]$Prefix) | Measure-Object -Sum).Sum) % 80000))
  DvAuto $E $Alias POST 'publishers' @{ uniquename = "halcourt$Prefix"; friendlyname = "Halcourt ($Prefix)"; customizationprefix = $Prefix; customizationoptionvalueprefix = $ovp } | Out-Null
}
# ---- flows (Copilot-triggered cloud flows agents invoke; created before the agents) -------------------
function Ensure-Flow([object]$F) {
  $E = Env $F.environment; $alias = $F.owner
  $tok = Get-PersonaToken $alias $E.Org
  $q = "workflows?`$select=workflowid&`$filter=name eq '" + $F.name.Replace("'", "''") + "' and category eq 5"
  if ((Invoke-Json GET "$($E.Org)/api/data/v9.2/$q" $tok).value) { return "ok" }
  if ($VerifyOnly) { return "MISSING (would create)" }
  $def = Get-Content (Join-Path $DataDir $F.definition) -Raw | ConvertFrom-Json
  $def.PSObject.Properties.Remove('_comment')
  $clientdata = @{ properties = @{ connectionReferences = @{}; definition = $def }; schemaVersion = '1.0.0.0' } | ConvertTo-Json -Depth 40
  Invoke-Json POST "$($E.Org)/api/data/v9.2/workflows" $tok @{ name = $F.name; description = 'Lab flow.'; category = 5; type = 1; primaryentity = 'none'; clientdata = $clientdata } | Out-Null
  $w = (Invoke-Json GET "$($E.Org)/api/data/v9.2/$q" $tok).value | Select-Object -First 1
  if ($w) { Invoke-Json PATCH "$($E.Org)/api/data/v9.2/workflows($($w.workflowid))" $tok @{ statecode = 1; statuscode = 2 } | Out-Null; return "created" }
  "created (not activated)"
}
function Provision-Agent([object]$A) {
  $E = Env $A.environment; $alias = $A.owner
  $ws = Join-Path $AgentsDir $A.workspace
  if (-not (Test-Path (Join-Path $ws 'agent.mcs.yml'))) { return "SKIP (no workspace; capture=$($A.capture))" }
  if ($VerifyOnly) { return "would (re)create in $($E.Name) as $alias" }

  $committedSchema = Get-SchemaName $ws             # keep the committed prefix
  $schema = $committedSchema
  $prefix = $schema.Split('_')[0]
  Ensure-Publisher $E $prefix $alias                # make sure its publisher exists (create on a fresh env)

  $env:XDG_DATA_HOME = Get-PacHome $alias
  # Re-auth fresh every time. pac caches the OAuth token under XDG_DATA_HOME, which persists across runs;
  # a stale/expired refresh token (>12h idle) makes init/clone/push fail with AADSTS700082 even though the
  # ROPC password is still valid. Clear first so `auth create` actually re-authenticates with the password.
  & $realPac auth clear 2>&1 | Out-Null
  & $realPac auth create --name $alias --username (Get-Upn $alias) --password $LabPassword --environment $E.Org 2>&1 | Out-Null

  # The committed workspace is the source of truth. `pac copilot push` only UPDATES an existing agent and
  # needs a *synced* local workspace (matching .mcs state) - which a committed workspace (gitignored .mcs)
  # never has, and which `init` alone doesn't reliably leave behind. The robust, proven pattern:
  #   1. ensure the agent exists - `init` the shell with the exact committed schema if it's absent;
  #   2. `clone` it into a temp dir (this ALWAYS yields a synced workspace);
  #   3. make the committed config authoritative - drop the clone's server-state knowledge/tools/conn-refs
  #      and overlay the committed ones (schema-prefixed to match);
  #   4. push. Preserves the agent identity (no delete) and is conflict-free.
  # Agent DISPLAY NAMES are the only thing distinguishing the Entra identities Copilot Studio creates, and
  # those identities are TENANT-wide. Two builds of the same agent therefore produce two principals called
  # "<name> (Microsoft Copilot Studio)" - verified: building claims-copilot into one slice already gave the
  # tenant two. At 20 slices that is 21, which breaks Lab 01-02's identity matching and makes Phase 7's
  # newest-per-name dedupe pick an arbitrary student's slice. So a slice build suffixes the name.
  # A slice suffix REPLACES the estate suffix rather than stacking on it - appending produced
  # "Onboarding Guide (mgray) (mgray-01)", which is just noise in the identity list.
  $display = if ($DisplayNameSuffix)   { "$($A.display) ($DisplayNameSuffix)" }
             elseif ($A.estateSuffixName) { "$($A.display) ($Estate)" }        # shared default env
             else                      { $A.display }
  # The shared default environment holds every estate's copy of these agents, and a schema name is unique per
  # environment - so there the schema carries the estate id too (cr458_ExpenseHelper -> cr458_ExpenseHelperjsmith),
  # or the second estate's init fails and its lookups could reach another estate's agent (issue #33). An estate
  # built before that has the committed schema: keep using it when THIS estate's owner sees an agent with it
  # under THIS estate's display name. Slices are their own environments and keep the committed schema.
  if ($A.estateSuffixName -and -not $TargetEnvironment) {
    $schema = "$committedSchema$Estate"
    $legacy = (DvAs $E $alias GET "bots?`$select=name&`$filter=schemaname eq '$committedSchema'").value | Select-Object -First 1
    if ($legacy -and $legacy.name -eq $display) { $schema = $committedSchema; Write-Host "    (keeping pre-#33 schema $committedSchema)" }
  }
  $tmp = Join-Path ([System.IO.Path]::GetTempPath()) "halcourt-ws/$($A.slug)"
  # Get a synced workspace via clone - pac's OWN existence view (the Dataverse `bots` table can disagree,
  # e.g. a soft-deleted ghost that pac still sees). If clone finds nothing, the agent truly is absent:
  # init the shell, then clone it. Retry init because the solution import lags.
  function Clone-ToTemp {
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    & $realPac copilot clone --bot $schema --environment $E.Org --output-dir $tmp 2>&1 | Out-Null
    (Get-ChildItem $tmp -Directory -ErrorAction SilentlyContinue | Select-Object -First 1).FullName
  }
  $wsdir = Clone-ToTemp
  if (-not $wsdir) {
    $initDir = Join-Path ([System.IO.Path]::GetTempPath()) "halcourt-init/$($A.slug)"
    # The FIRST agent in a freshly provisioned environment is the slowest and flakiest: init triggers a CDS
    # solution import that can take well over a minute and occasionally fails transiently, and the bot can
    # lag a few seconds behind a successful init before clone sees it. Retry generously and keep the last pac
    # output so a real failure is diagnosable (the engine otherwise swallows pac's stderr).
    $lastInit = ''
    for ($k = 0; $k -lt 6 -and -not $wsdir; $k++) {
      if (Test-Path $initDir) { Remove-Item $initDir -Recurse -Force }
      New-Item -ItemType Directory -Force -Path (Split-Path $initDir) | Out-Null
      $lastInit = (& $realPac copilot init --name $display --publisher-prefix $prefix --schema-name $schema --project-dir $initDir --environment $E.Org 2>&1) -join [Environment]::NewLine
      Start-Sleep 20
      $wsdir = Clone-ToTemp
    }
    Remove-Item $initDir -Recurse -Force -ErrorAction SilentlyContinue
    if (-not $wsdir) { return "CREATE FAILED (init did not produce a cloneable agent '$schema'): " + (($lastInit -split [Environment]::NewLine | Select-Object -Last 3) -join ' | ') }
  }
  foreach ($d in 'knowledge','actions') { $p = Join-Path $wsdir $d; if (Test-Path $p) { Remove-Item $p -Recurse -Force } }
  Remove-Item (Join-Path $wsdir 'connectionreferences.mcs.yml') -Force -ErrorAction SilentlyContinue
  # knowledge/actions/conn-refs: committed is authoritative (cleaned above). topics: MERGE committed custom
  # topics onto the clone's system topics (Greeting/Fallback/... must stay), so don't clean topics/.
  foreach ($item in 'agent.mcs.yml','knowledge','actions','connectionreferences.mcs.yml','topics') {
    $src = Join-Path $ws $item
    if (Test-Path $src) { Copy-Item $src (Join-Path $wsdir $item) -Recurse -Force }
  }
  # The merge keeps any topic the clone has, so a custom topic that left the committed workspace survives a
  # re-provision. Name retired ones here: Underwriting Assistant's three MCP-call topics became one MCP tool
  # (actions/UnderwritingMCP.mcs.yml), and an estate built before that would otherwise keep both.
  $retiredTopics = @{ 'underwriting-assistant' = @('GetQuote', 'GetRiskScore', 'RunQuery') }
  foreach ($t in @($retiredTopics[(Split-Path $ws -Leaf)])) {
    if (-not $t) { continue }
    $p = Join-Path $wsdir "topics/$t.mcs.yml"
    if (Test-Path $p) { Remove-Item $p -Force; Write-Host "    removed retired topic $t" }
  }
  # Inject the shared Phase 1 endpoints/secrets into ${VAR} tokens, and resolve ${FLOW:<name>} to a live flow
  # id (as the owner - flows are estate-specific record ids, not secrets, so they stay out of git too).
  Get-ChildItem $wsdir -Recurse -Include *.mcs.yml | ForEach-Object {
    $c = Get-Content $_.FullName -Raw; $changed = $false
    foreach ($k in $AzdValues.Keys) { $tok = '${' + $k + '}'; if ($c.Contains($tok)) { $c = $c.Replace($tok, $AzdValues[$k]); $changed = $true } }
    # The agent's own environment URL, for Dataverse tools that must name it (claims-copilot's List rows).
    if ($c.Contains('${ENV_ORG_URL}')) { $c = $c.Replace('${ENV_ORG_URL}', $E.Org); $changed = $true }
    # Topics, actions and connection references name the agent's schema; follow an estate-scoped one. The
    # lookahead keeps an already-scoped name (cr458_ExpenseHelperjsmith.topic...) from being scoped twice.
    if ($schema -ne $committedSchema) {
      $n = [regex]::Replace($c, [regex]::Escape($committedSchema) + '(?=[.\s"]|$)', $schema)
      if ($n -ne $c) { $c = $n; $changed = $true }
    }
    # Tenant- and estate-specific names (knowledge sites, OneDrive paths, the default environment's display
    # names) are tokens in the committed workspace, never this build's literal values.
    foreach ($kv in @(@('${ESTATE}', $Estate), @('${SP_HOST}', "$SpPrefix.sharepoint.com"), @('${SP_MY_HOST}', "$SpPrefix-my.sharepoint.com"))) {
      if ($c.Contains($kv[0])) { $c = $c.Replace($kv[0], $kv[1]); $changed = $true }
    }
    # ${UPN_PATH:<alias>}: a persona's OneDrive path segment (dev.kim.<estate>@<domain> -> dev_kim_<estate>_<domain_with_underscores>).
    foreach ($x in [regex]::Matches($c, '\$\{UPN_PATH:([^}]+)\}')) { $c = $c.Replace($x.Value, ((Get-Upn $x.Groups[1].Value) -replace '[.@]', '_').ToLower()); $changed = $true }
    # A custom connector's generated id, and its display name (the MCP tool's name in Copilot Studio).
    foreach ($x in [regex]::Matches($c, '\$\{CONNECTOR:([^}]+)\}')) { $c = $c.Replace($x.Value, (Get-ConnectorId $x.Groups[1].Value)); $changed = $true }
    if ($c.Contains('${MCP_CONNECTOR_NAME}')) {
      $mcpDef = $manifest.connections.PSObject.Properties | Where-Object { $_.Value.connector -eq 'custom' } | Select-Object -First 1
      $c = $c.Replace('${MCP_CONNECTOR_NAME}', (Get-CustomConnectorDisplay $mcpDef.Value)); $changed = $true
    }
    foreach ($x in [regex]::Matches($c, '\$\{FLOW:([^}]+)\}')) {
      $fn = $x.Groups[1].Value
      $fid = (DvAs $E $alias GET ("workflows?`$select=workflowid&`$filter=name eq '" + $fn.Replace("'","''") + "' and category eq 5")).value | Select-Object -First 1
      if ($fid) { $c = $c.Replace($x.Value, $fid.workflowid); $changed = $true } else { Write-Host "    (flow '$fn' not found - run the flow-creation step first)" }
    }
    if ($changed) { Set-Content $_.FullName -Value $c -NoNewline }
  }
  # `pac copilot push` only POINTS at connection references - one the workspace declares but Dataverse lacks
  # fails the push ("A record with the specified key values does not exist in connectionreference entity").
  # Every reference before the MCP tool predated the push workflow, so this never showed. Create any that
  # are missing, as the owner, before pushing.
  $crFile = Join-Path $wsdir 'connectionreferences.mcs.yml'
  if (Test-Path $crFile) {
    foreach ($m in [regex]::Matches((Get-Content $crFile -Raw), 'connectionReferenceLogicalName:\s*(\S+)\s+connectorId:\s*(\S+)')) {
      $ln = $m.Groups[1].Value; $cid = $m.Groups[2].Value
      $have = (DvAuto $E $alias GET "connectionreferences?`$select=connectionreferenceid&`$filter=connectionreferencelogicalname eq '$ln'").value
      if (-not $have) {
        DvAs $E $alias POST 'connectionreferences' @{ connectionreferencelogicalname = $ln; connectionreferencedisplayname = $ln.Split('.')[-1]; connectorid = $cid } | Out-Null
        Write-Host "    created connection reference $ln"
      }
    }
  }
  $push = & $realPac copilot push --project-dir $wsdir 2>&1
  if ($LASTEXITCODE -ne 0) { return "PUSH FAILED: " + (($push | Select-Object -Last 1) -join ' ') }

  # Look up + PATCH the bot AS THE OWNER, not admin: in the shared default environment the admin has no read
  # on `bots` (it returns empty), so admin-token bot ops silently fail there. The owner always sees its own.
  $bot = $null
  for ($i = 0; $i -lt 6 -and -not $bot; $i++) {
    $bot = (DvAs $E $alias GET "bots?`$select=botid&`$filter=schemaname eq '$schema'").value | Select-Object -First 1
    if (-not $bot) { Start-Sleep 5 }
  }
  if (-not $bot) { return "PUSHED but bot '$schema' not found - nothing published" }

  if ($A.chatAudience -ne 'Owner') {
    $gid = Get-GroupId $A.chatAudience
    DvAs $E $alias PATCH "bots($($bot.botid))" @{ accesscontrolpolicy = 2; authorizedsecuritygroupids = $gid } | Out-Null
  } else {
    DvAs $E $alias PATCH "bots($($bot.botid))" @{ accesscontrolpolicy = 1 } | Out-Null
  }

  # Bind each of the agent's connection references to this estate's live connection id (clone doesn't
  # capture the binding, and push leaves it unset). Match the agent's schema-prefixed connection references
  # to the manifest connection by connector.
  foreach ($cn in $A.connections) {
    if (-not $manifest.connections.$cn) { continue }
    $cid = Get-ConnId $cn
    if (-not $cid) { Write-Host "    (no live connection for $cn)"; continue }
    $connOwner = $manifest.connections.$cn.owner       # the connection's owner can bind it; the agent owner may not
    $connector = Get-ConnectorId $cn
    $cref = (DvAuto $E $alias GET "connectionreferences?`$select=connectionreferenceid,connectionid,connectorid&`$filter=startswith(connectionreferencelogicalname,'$schema')").value |
      Where-Object { $_.connectorid -like "*/$connector" } | Select-Object -First 1
    if ($cref -and $cref.connectionid -ne $cid) {
      try { DvAs $E $connOwner PATCH "connectionreferences($($cref.connectionreferenceid))" @{ connectionid = $cid } | Out-Null; Write-Host "    bound $cn -> $cid" }
      catch {
        # Only the connection's owner may bind it (a Dataverse OAuth connection can't be shared), but a
        # service-account owner holds just its scenario role, which lacks the reads the bind checks
        # (claims-copilot: svc-claims). Lend it a throwaway role for the PATCH, then take it away again so
        # the scenario role attendees inspect is unchanged. Measured 2026-10-18.
        Write-Host "    (bind as $connOwner refused - retrying with a temporary role)"
        $bound = $false
        try { $bound = Invoke-BindWithTempRole $E $connOwner $cref.connectionreferenceid $cid }
        catch { Write-Host "    (could not bind $cn as $connOwner`: $($_.Exception.Message.Split([char]10)[0]))" }
        if ($bound) { Write-Host "    bound $cn -> $cid (via temporary role, now removed)" }
        else        { Write-Warning "    $cn is NOT bound - the agent's tools on it will fail (ConnectionNotFound). Bind it in Copilot Studio as $connOwner." }
      }
    }
  }

  # Co-owners: Copilot Studio's own editor share needs the sharer to hold prvAssignRole, which a maker doesn't,
  # so add them to the agent's owning team (<botid>_1) directly - which is all an editor share does.
  foreach ($co in @($A.coOwners)) {
    if (-not $co) { continue }
    try {
      $team = (Dv $E GET "teams?`$select=teamid&`$filter=name eq '$($bot.botid.Replace('-',''))_1'").value | Select-Object -First 1
      $su = (Dv $E GET "systemusers?`$select=systemuserid&`$filter=domainname eq '$(Get-Upn $co)'").value | Select-Object -First 1
      if ($team -and $su) {
        Dv $E POST "teams($($team.teamid))/Microsoft.Dynamics.CRM.AddMembersTeam" @{ Members = @(@{ '@odata.type' = 'Microsoft.Dynamics.CRM.systemuser'; systemuserid = $su.systemuserid }) } | Out-Null
        Write-Host "    co-owner $co"
      } else { Write-Host "    (co-owner ${co}: team or user not found)" }
    } catch { Write-Host "    (co-owner ${co} not added: $($_.Exception.Message.Split([char]10)[0]))" }
  }

  # Teams channel: attendees chat with the scenario agents in Teams (Lab 04), and an agent published with
  # Microsoft authentication is reachable only through it. No headless API - added in the browser as the owner.
  # The bot record is the judge, not the browser script: its configuration lists the channel once added.
  if ($A.teamsChannel) {
    $hasTeams = {
      $cfg = (DvAs $E $alias GET "bots($($bot.botid))?`$select=configuration").configuration
      $cfg -and @(($cfg | ConvertFrom-Json).channels | ForEach-Object { $_.channelId }) -contains 'msteams'
    }
    $before = & $hasTeams
    # Run it even when the channel is on: it also reads the agent's Teams INSTALL link (Availability options >
    # Copy link), the one attendees open - a plain chat link is refused ("You do not have permission").
    $r = python3 (Join-Path $PSScriptRoot 'lib/enable_teams_channel.py') --upn (Get-Upn $alias) --password $LabPassword --env $E.Id --bot $bot.botid 2>&1
    $code = $LASTEXITCODE
    if (& $hasTeams) { Write-Host "    teams channel: $(if ($before) { 'already on' } else { 'added' })" }
    else { Write-Warning "    teams channel NOT added (exit $code): $($r | Select-Object -Last 1) - attendees can't chat with $($A.display) in Teams. Screenshot: /tmp/enable_teams_channel_error.png" }
    $link = ($r | Select-String '^LINK=' | Select-Object -First 1)
    if ($link) {
      $url = "$link" -replace '^LINK='
      $links = Join-Path (Split-Path $PSScriptRoot -Parent) "teams-links-$Estate.local.csv"   # gitignored (*.local.csv)
      # Keyed by $display, not $A.display: per-student slices share the manifest entry but not the agent.
      # (A shared build also drops a row an earlier version keyed by $A.display.)
      $rows = @(if (Test-Path $links) { Import-Csv $links | Where-Object { $_.agent -ne $display -and ($DisplayNameSuffix -or $_.agent -ne $A.display) } })
      @($rows) + [pscustomobject]@{ agent = $display; teams_link = $url } | Export-Csv -NoTypeInformation $links
      Write-Host "    teams link -> $links"
    } else {
      $why = ($r | Select-String '^LINKERROR=' | Select-Object -First 1)
      Write-Warning "    no Teams install link read for $display$(if ($why) { " ($("$why" -replace '^LINKERROR='))" }) - copy it by hand: Channels > Teams > Availability options > Copy link"
    }
  }

  # publishing right after create can be too soon; retry and confirm success.
  $published = $false
  for ($i = 0; $i -lt 5 -and -not $published; $i++) {
    $pub = & $realPac copilot publish --bot $schema --environment $E.Org 2>&1
    if ($pub -match 'Published successfully') { $published = $true; break }
    Start-Sleep 15
  }
  if ($published) { "created+published ($schema)" } else { "created, PUBLISH NOT confirmed ($schema)" }
}

# ---- run ----------------------------------------------------------------------------------------------
$roleByEnv = @{ 'Halcourt-Prod' = 'Environment Maker'; 'Claims-Test' = 'Environment Maker'; 'Halcourt (default)' = 'Environment Maker'; 'Maker-Sandbox' = 'System Administrator' }
$ownerRoleOverride = @{ 'tom.dean|Halcourt-Prod' = 'System Administrator' }   # Sales Nudge: Tom's broad CRM reach

# `pwsh <script> -Agents a,b` passes ONE string "a,b" (only -Command splits it), so split here; and stop on an
# unknown slug rather than build nothing and still report success.
$Agents = @($Agents | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$unknown = @($Agents | Where-Object { $_ -notin $manifest.agents.slug })
if ($unknown) { throw "Unknown agent slug(s): $($unknown -join ', '). Known: $($manifest.agents.slug -join ', ')" }
$targets = $manifest.agents | Where-Object { -not $Agents -or $Agents -contains $_.slug }

if (-not $SkipPrereqs) {
  # Dataverse will not add a sign-in-disabled user to an environment; it fails with an opaque Kepler
  # 'instanceNotFound' rather than saying so. it.helpdesk hits this every build: it is a SHARED MAILBOX, and
  # Exchange creates those disabled, so enable it here (reference/agents-build.md). Any OTHER disabled owner
  # is reported, never auto-enabled: a disabled persona is a decision someone made (tom.dean is departed but
  # stays ENABLED - see Phase 6.5 - so a disabled Tom means someone ran the Ex05 fix and didn't undo it).
  Write-Host "`n== Owner sign-in =="
  foreach ($alias in ($targets.owner | Select-Object -Unique)) {
    $upn = Get-Upn $alias
    $u = Invoke-Json GET "https://graph.microsoft.com/v1.0/users/$upn`?`$select=accountEnabled" (Get-AdminToken 'https://graph.microsoft.com/')
    if ($u.accountEnabled) { continue }
    if ($alias -eq 'it.helpdesk') {
      if ($VerifyOnly) { Write-Host ("{0,-12} -> disabled (would enable: shared mailbox)" -f $alias); continue }
      Invoke-Json PATCH "https://graph.microsoft.com/v1.0/users/$upn" (Get-AdminToken 'https://graph.microsoft.com/') @{
        accountEnabled = $true
        passwordProfile = @{ password = $LabPassword; forceChangePasswordNextSignIn = $false }
      } | Out-Null
      Write-Host ("{0,-12} -> enabled (shared mailbox; Exchange creates it disabled)" -f $alias)
      Start-Sleep 10   # let the sign-in change reach Dataverse before addUser
    } else {
      Write-Warning "$alias is sign-in disabled - Dataverse cannot add it. Enable it (tom.dean stays enabled by design - Phase 6.5)."
    }
  }

  Write-Host "`n== Owner environment roles =="
  $seen = @{}
  foreach ($a in $targets) {
    $key = "$($a.owner)|$($a.environment)"
    if ($seen[$key]) { continue }; $seen[$key] = $true
    $role = $ownerRoleOverride[$key]; if (-not $role) { $role = $roleByEnv[$a.environment] }
    "{0,-12} in {1,-20} -> {2}" -f $a.owner, $a.environment, (Ensure-EnvUserRole (Env $a.environment) $a.owner $role) | Write-Host
  }
}

if (-not $SkipConnections) {
  Write-Host "`n== Connections =="
  $need = $targets.connections | Where-Object { $manifest.connections.$_ } | Select-Object -Unique
  foreach ($n in $need) {
    "{0,-26} -> {1}" -f $n, (Ensure-Connection $n $manifest.connections.$n) | Write-Host
    $def = $manifest.connections.$n
    if ($def.shareWith -and -not $VerifyOnly) { Write-Host "    (shareWith $($def.shareWith): OAuth connections often refuse sharing - verify in PPAC)" }
  }
}

if (-not $SkipConnections -and $manifest.flows) {
  Write-Host "`n== Flows =="
  foreach ($f in $manifest.flows) {
    # One flow must not end the run. A slice build (-TargetEnvironment) targets a brand-new environment
    # where the flow's owner holds no Dataverse role yet, so the read throws 0x80042f09 - report it and
    # carry on to the agents, which are what the slice is for.
    try   { "{0,-42} -> {1}" -f $f.name, (Ensure-Flow $f) | Write-Host }
    catch {
      $msg = $_.Exception.Message.Split([char]10)[0]
      if ($TargetEnvironment) {
        # Slice build only: the flow owner holds no Dataverse role in a brand-new environment yet.
        "{0,-42} -> SKIPPED ({1})" -f $f.name, $msg | Write-Host
      } else {
        # Ordinary estate build: an agent that needs this flow would be provisioned with its
        # ${FLOW:...} placeholder unresolved, which fails silently at run time instead of here.
        throw "Flow '$($f.name)' failed in an ordinary estate build: $msg"
      }
    }
  }
}

Write-Host "`n== Agents =="
foreach ($a in $targets) { "{0,-24} -> {1}" -f $a.slug, (Provision-Agent $a) | Write-Host }
Write-Host "`nPhase 6 pass complete for estate '$Estate'."
