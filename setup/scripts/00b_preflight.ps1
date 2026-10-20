<#
FACILITATOR-ONLY. Preflight: does THIS tenant and THIS estate support the exercises as written?

Run it before a delivery - the day before, so there is time to act on it. Every check names the exercise
steps it protects, so a WARN tells you which steps lose their live path (each has an artifact-pack
fallback) and a FAIL tells you what will not work at all. Exit code 1 on any FAIL.

Reads only. Needs az signed in to the lab tenant (source scripts/env.sh in any shell that is not a VS Code
terminal on this repo or the dev container).

  pwsh setup/scripts/00b_preflight.ps1 -Attendees 20
  pwsh setup/scripts/00b_preflight.ps1 -Estate jsmith -Attendees 1

Why this exists: three modules in a row had their live path blocked by something the kit assumed and nobody
checked - a Dataverse privilege, a licence, a service plan the tenant never had. The access model
(_access_model.ps1) declares what the exercises need; this script verifies it against the tenant.
#>
param(
  [string]$Estate        = $env:HALCOURT_ESTATE,
  [int]$Attendees        = 1,            # how many attendee accounts the delivery will use
  [string]$StudentPrefix = 'student'
)
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot '_estate.ps1')
. (Join-Path $PSScriptRoot '_access_model.ps1')
$Estate = Resolve-Estate $Estate

if (-not (Get-Command az -ErrorAction SilentlyContinue)) { throw 'This script needs the Azure CLI (az) - see scripts/env.sh.' }
$tenant = az account show --query tenantId -o tsv 2>$null
if (-not $tenant) { throw 'az is not signed in - run "az login" in a shell that sources scripts/env.sh.' }
$domain = az rest --method GET --url 'https://graph.microsoft.com/v1.0/organization?$select=verifiedDomains' --query "value[0].verifiedDomains[?isDefault].name | [0]" -o tsv
$spHost = ($domain -replace '\.onmicrosoft\.com$', '') + '.sharepoint.com'
Write-Host "Preflight for estate '$Estate' in tenant $tenant ($domain), $Attendees attendee(s)`n"

# --- helpers -----------------------------------------------------------------------------------------------
$script:Tokens = @{}
function Tok([string]$Resource) {
  if (-not $script:Tokens[$Resource]) { $script:Tokens[$Resource] = az account get-access-token --resource $Resource --query accessToken -o tsv 2>$null }
  $script:Tokens[$Resource]
}
function Get-Json([string]$Uri, [string]$Resource) {
  Invoke-RestMethod -Method GET -Uri $Uri -Headers @{ Authorization = "Bearer $(Tok $Resource)"; Accept = 'application/json' }
}
function Result([string]$Status, [string]$Detail) { [pscustomobject]@{ Status = $Status; Detail = $Detail } }
$rows = @()
function Check([string]$Name, [string]$Protects, [scriptblock]$Body) {
  try   { $r = & $Body }
  catch { $r = Result 'FAIL' $_.Exception.Message.Split([char]10)[0] }
  if (-not $r) { $r = Result 'FAIL' 'check returned nothing' }
  $script:rows += [pscustomobject]@{ Check = $Name; Status = $r.Status; Detail = $r.Detail; Protects = $Protects }
  $tag = switch ($r.Status) { 'PASS' { '  ok  ' } 'WARN' { ' WARN ' } default { ' FAIL ' } }
  Write-Host ("[{0}] {1,-52} {2}" -f $tag, $Name, $r.Detail)
}
function Http-Status($err) { try { [int]$err.Exception.Response.StatusCode } catch { 0 } }

# --- 1. licensing ------------------------------------------------------------------------------------------
$skus = @()
try { $skus = (Get-Json 'https://graph.microsoft.com/v1.0/subscribedSkus' 'https://graph.microsoft.com').value } catch { }

Check 'E5 seats for attendee accounts' 'Teams chat with the agents (04-01, 04-02, 04-04); the access model in the shared estate (03-02 role editor, agent pages in 01, 02, 04)' {
  $e5 = $skus | Where-Object skuPartNumber -eq 'DEVELOPERPACK_V2_E5' | Select-Object -First 1
  if (-not $e5) { return Result 'WARN' 'no DEVELOPERPACK_V2_E5 SKU in this tenant' }
  $free = $e5.prepaidUnits.enabled - $e5.consumedUnits
  if ($free -ge $Attendees) { Result 'PASS' "$free free of $($e5.prepaidUnits.enabled) (need $Attendees). Assign the DAY BEFORE: Dataverse re-reads licence state hours later, not minutes." }
  else { Result 'WARN' "$free free of $($e5.prepaidUnits.enabled), $Attendees attendee(s). Unlicensed attendees cannot use Teams (no chat with the agents) and cannot open roles or agent pages in the shared estate." }
}

Check 'Agent 365 in the M365 admin center' '01-01 KT01 s3, 02-01 KT01 s1, 04-06 KT01 s1, 05-05 KT01' {
  $sp = (Get-Json "https://graph.microsoft.com/v1.0/servicePrincipals?`$filter=displayName eq 'Agent 365'&`$select=appId" 'https://graph.microsoft.com').value
  if (-not $sp) { return Result 'WARN' "no 'Agent 365' service principal - the registry steps fall back to agents-export.csv" }
  Result 'PASS' "present - attendees need the AI Reader role to see M365 admin center > Agents (checked below)"
}

Check "Attendees hold the directory roles ($($DirectoryRoles -join ', '))" 'Power Platform Administrator: 01-01 connection reads. AI Reader: the Agent 365 pages. Security Reader: CA and Defender (05-04, 05-07). Global Reader: Purview (05-06, 05-07)' {
  $who = (Get-Json ("https://graph.microsoft.com/v1.0/users?`$select=id,userPrincipalName&`$filter=" + [uri]::EscapeDataString("startswith(userPrincipalName,'$StudentPrefix')")) 'https://graph.microsoft.com').value |
         Where-Object { $_.userPrincipalName -like "$StudentPrefix*.$Estate@*" }
  if (-not $who) { return Result 'WARN' "no $StudentPrefix*.$Estate accounts yet - run 07" }
  $short = @()
  foreach ($u in $who) {
    $have = (Get-Json "https://graph.microsoft.com/v1.0/users/$($u.id)/transitiveMemberOf/microsoft.graph.directoryRole?`$select=displayName" 'https://graph.microsoft.com').value | ForEach-Object { $_.displayName }
    $lack = @($DirectoryRoles | Where-Object { $_ -notin $have })
    if ($lack.Count) { $short += "$($u.userPrincipalName.Split('@')[0]) lacks $($lack -join '+')" }
  }
  if ($short.Count) { Result 'FAIL' (($short -join '; ') + ' - re-run 07') } else { Result 'PASS' "$(@($who).Count) account(s) hold all of them" }
}

# --- 2. tenant baseline --------------------------------------------------------------------------------------
Check "Conditional Access '$CaPolicyName' present" 'attendee MFA enrolment at first sign-in (Phase 8b)' {
  $policies = (Get-Json 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies' 'https://graph.microsoft.com').value
  $p = $policies | Where-Object displayName -eq $CaPolicyName | Select-Object -First 1
  if ($p) { Result 'PASS' "state=$($p.state)" } else { Result 'FAIL' 'missing - run 00_conditional_access_baseline.ps1' }
}

# --- 3. the estate -----------------------------------------------------------------------------------------
$envs = @()
try { $envs = (Get-Json 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2021-04-01' 'https://service.powerapps.com/').value } catch { }
$wantEnvs = 'Halcourt-Prod', 'Claims-Test', 'Maker-Sandbox' | ForEach-Object { Get-EstateName $_ $Estate }
$prod = $envs | Where-Object { $_.properties.displayName -eq (Get-EstateName 'Halcourt-Prod' $Estate) } | Select-Object -First 1
$default = $envs | Where-Object { $_.properties.isDefault } | Select-Object -First 1

Check 'Estate environments' '00-02 KT01 and every later task' {
  $have = @($envs | ForEach-Object { $_.properties.displayName })
  $miss = @($wantEnvs | Where-Object { $_ -notin $have })
  if ($miss.Count) { Result 'FAIL' "missing: $($miss -join ', ') (Phase 3)" } else { Result 'PASS' (($wantEnvs + @($default.properties.displayName)) -join ', ') }
}

Check 'Connections SP-HR-Benefits and DV-CRM-Shared (Halcourt-Prod)' '04-01 KT01 s3, 04-02, 04-03, 04-04; 01-01 KT01 s3' {
  if (-not $prod) { return Result 'FAIL' 'no Halcourt-Prod environment' }
  $c = (Get-Json "https://api.powerapps.com/providers/Microsoft.PowerApps/scopes/admin/environments/$($prod.name)/connections?api-version=2020-06-01" 'https://service.powerapps.com/').value
  $byName = @{}; foreach ($x in $c) { $byName[$x.properties.displayName] = $x }
  $miss = @('SP-HR-Benefits', 'DV-CRM-Shared' | Where-Object { -not $byName.ContainsKey($_) })
  $bad  = @('SP-HR-Benefits', 'DV-CRM-Shared' | Where-Object { $byName.ContainsKey($_) -and (($byName[$_].properties.statuses | Select-Object -First 1).status -ne 'Connected') })
  if ($miss.Count) { Result 'FAIL' "missing: $($miss -join ', ') (Phase 6)" }
  elseif ($bad.Count) { Result 'FAIL' "not Connected: $($bad -join ', ') - re-consent in Phase 6" }
  else { Result 'PASS' 'both Connected' }
}

Check 'Connection DV-Claims-Shared (Claims-Test)' '04-03, 04-04 confused deputy; 05-03; 05-07 attribution (acts as svc-claims)' {
  $ct = $envs | Where-Object { $_.properties.displayName -eq (Get-EstateName 'Claims-Test' $Estate) } | Select-Object -First 1
  if (-not $ct) { return Result 'FAIL' 'no Claims-Test environment' }
  $c = (Get-Json "https://api.powerapps.com/providers/Microsoft.PowerApps/scopes/admin/environments/$($ct.name)/connections?api-version=2020-06-01" 'https://service.powerapps.com/').value |
       Where-Object { $_.properties.displayName -eq 'DV-Claims-Shared' } | Select-Object -First 1
  if (-not $c) { return Result 'FAIL' 'missing (Phase 6)' }
  $st = ($c.properties.statuses | Select-Object -First 1).status
  if ($st -eq 'Connected') { Result 'PASS' "Connected, owner $($c.properties.createdBy.userPrincipalName)" } else { Result 'FAIL' "status $st - re-consent in Phase 6" }
}

Check 'Purview label Confidential-PII + SSN info type' '05-06 (label the comp file, verify Copilot withholds it); Scenario B verdict' {
  # No phase in this kit creates them, and az's Graph token cannot read labels. AGENTS.md lists both as
  # estate components. Until a phase provisions them, this is a manual check.
  Result 'WARN' 'NOT PROVISIONED BY THE KIT - confirm in purview.microsoft.com > Information Protection > Sensitivity labels, or create it, before Module 5'
}

Check "SharePoint site HR-Benefits-$Estate" '04-01 and 04-02 grounding; 05-03; 05-06' {
  $t = Tok "https://$spHost"
  if (-not $t) { return Result 'WARN' "no SharePoint token from az for $spHost - check the site by hand" }
  $uri = "https://$spHost/sites/$(Get-EstateName 'HR-Benefits' $Estate)/_api/web?`$select=Title"
  try { Invoke-RestMethod -Uri $uri -Headers @{ Authorization = "Bearer $t"; Accept = 'application/json;odata=nometadata' } | Out-Null; Result 'PASS' 'readable' }
  catch {
    $code = Http-Status $_
    # SharePoint answers 404 for a site that does not exist and 401/403 for one this token may not read.
    if ($code -eq 404) { Result 'FAIL' '404 - the site does not exist (Phase 4)' }
    elseif ($code -in 401, 403) { Result 'PASS' "exists (HTTP $code to this token; attendees read it through the agent's connection)" }
    else { Result 'WARN' "HTTP $code" }
  }
}

Check 'Training endpoints: Policy API and Underwriting MCP' '04-03, 04-05; 05-01 retests' {
  $rg = "rg-halcourt-$Estate-lab"
  $apps = az containerapp list -g $rg --query "[].{name:name,fqdn:properties.configuration.ingress.fqdn,min:properties.template.scale.minReplicas}" -o json 2>$null | ConvertFrom-Json
  if (-not $apps) { return Result 'FAIL' "no container apps in resource group $rg (Phase 1)" }
  $out = @(); $failed = $false
  foreach ($k in 'policyapi', 'underwritingmcp') {
    $a = $apps | Where-Object name -like "ca-$k-*" | Select-Object -First 1
    if (-not $a) { $out += "$k MISSING"; $failed = $true; continue }
    try {
      $resp = Invoke-WebRequest -Uri "https://$($a.fqdn)/" -Method GET -TimeoutSec 20 -SkipHttpErrorCheck
      $out += "$k HTTP $($resp.StatusCode)" + $(if ($a.min -lt 1) { ' (minReplicas 0: expect a cold start)' } else { '' })
    } catch { $out += "$k UNREACHABLE"; $failed = $true }
  }
  if ($failed) { Result 'FAIL' ($out -join '; ') } else { Result 'PASS' ($out -join '; ') }
}

# Agents: every entry in setup/agents/manifest.json must exist in its environment, by display name.
$manifestPath = Join-Path $PSScriptRoot '..\agents\manifest.json'
$agents = @()
if (Test-Path $manifestPath) {
  $m = Get-Content $manifestPath -Raw | ConvertFrom-Json
  $agents = @(if ($m -is [array]) { $m } elseif ($m.agents) { $m.agents } else { $m })
}
Check "Estate agents present ($($agents.Count) in manifest)" '01-01 count; 02-01; every Exercise 04 scenario' {
  if (-not $agents.Count) { return Result 'WARN' "no manifest at $manifestPath" }
  $missing = @()
  foreach ($a in $agents) {
    $isDefault = "$($a.environment)" -like '*default*'
    $e = if ($isDefault) { $default } else { $envs | Where-Object { $_.properties.displayName -eq (Get-EstateName $a.environment $Estate) } | Select-Object -First 1 }
    $display = if ($isDefault) { Get-EstateDisplayName $a.display $Estate } else { $a.display }
    if (-not $e) { $missing += "$display (no environment)"; continue }
    $org = $e.properties.linkedEnvironmentMetadata.instanceApiUrl
    if (-not $org) { $missing += "$display (environment has no Dataverse)"; continue }
    try {
      $esc = $display.Replace("'", "''")
      $bots = (Get-Json "$org/api/data/v9.2/bots?`$select=name&`$filter=name eq '$esc'" $org).value
      if (-not $bots) { $missing += $display }
    } catch { $missing += "$display (read failed: $($_.Exception.Message.Split([char]10)[0]))" }
  }
  if ($missing.Count) { Result 'FAIL' "missing: $($missing -join '; ') (Phase 6)" } else { Result 'PASS' 'all present' }
}

Check "Attendees are in the agents' chat audience ($($AudienceGroups -join ', '))" '04-01, 04-02, 04-04: drive the published agents with your own lab account' {
  $short = @()
  foreach ($a in $AudienceGroups) {
    $gn = Get-EstateName $a $Estate
    $g = (Get-Json "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$gn'&`$select=id" 'https://graph.microsoft.com').value | Select-Object -First 1
    if (-not $g) { $short += "$gn missing"; continue }
    $m = @((Get-Json "https://graph.microsoft.com/v1.0/groups/$($g.id)/members?`$select=userPrincipalName&`$top=999" 'https://graph.microsoft.com').value | ForEach-Object { $_.userPrincipalName } | Where-Object { $_ -like "$StudentPrefix*.$Estate@*" })
    if (-not $m.Count) { $short += "no attendees in $gn" } else { $short += "$($m.Count) in $gn" }
  }
  if ($short -match 'missing|no attendees') { Result 'FAIL' (($short -join '; ') + ' - re-run 07') } else { Result 'PASS' ($short -join '; ') }
}

# --- 4. attendee access, per environment: the access model, enforced? ------------------------------------
foreach ($en in $wantEnvs) {
  $e = $envs | Where-Object { $_.properties.displayName -eq $en } | Select-Object -First 1
  $org = $e.properties.linkedEnvironmentMetadata.instanceApiUrl
  Check "'$DvRoleName' matches the access model ($en)" '03-02, 03-04; Copilot Studio steps of 01, 02, 04' {
    if (-not $org) { return Result 'WARN' 'environment missing or has no Dataverse' }
    $esc  = $DvRoleName.Replace("'", "''")
    $role = (Get-Json "$org/api/data/v9.2/roles?`$select=roleid&`$filter=name eq '$esc'" $org).value | Select-Object -First 1
    if (-not $role) { return Result 'FAIL' "role not created - run 07_provision_lab_users.ps1" }
    $held = @((Get-Json "$org/api/data/v9.2/RetrieveRolePrivilegesRole(RoleId=$($role.roleid))" $org).RolePrivileges | ForEach-Object { $_.PrivilegeId })
    $wantIds = @{}
    foreach ($n in $DvPrivilegeNames) {
      $pv = (Get-Json "$org/api/data/v9.2/privileges?`$select=privilegeid&`$filter=name eq '$n'" $org).value | Select-Object -First 1
      if ($pv) { $wantIds[$pv.privilegeid] = $n }
    }
    $missing = @($wantIds.Keys | Where-Object { $_ -notin $held } | ForEach-Object { $wantIds[$_] })
    $extraIds = @($held | Where-Object { -not $wantIds.ContainsKey($_) })
    $drift = @()
    if ($extraIds.Count) {
      $f = ($extraIds | ForEach-Object { "privilegeid eq $_" }) -join ' or '
      $names = (Get-Json ("$org/api/data/v9.2/privileges?`$select=name&`$filter=" + [uri]::EscapeDataString($f)) $org).value | ForEach-Object { $_.name }
      $drift = @($names | Where-Object { $_ -notin $DvBaselinePrivileges })
    }
    if ($missing.Count) { Result 'FAIL' "missing: $($missing -join ', ') - re-run 07" }
    elseif ($drift.Count) { Result 'WARN' "drift not in the model: $($drift -join ', ') - re-run 07 to prune" }
    else { Result 'PASS' "$($wantIds.Count) privileges, no drift" }
  }
  Check "Attendee accounts hold the role + $($DvCompanionRoles -join ', ') ($en)" 'Copilot Studio agent pages: 01-01 s2-3, 01-02, 02-01..03, 04-01/03/05/06' {
    if (-not $org) { return Result 'WARN' 'environment missing or has no Dataverse' }
    $pattern = "$StudentPrefix%.$Estate@%"
    $users = (Get-Json ("$org/api/data/v9.2/systemusers?`$select=systemuserid,domainname,accessmode,islicensed&`$filter=" + [uri]::EscapeDataString("startswith(domainname,'$StudentPrefix') and contains(domainname,'.$Estate@') and isdisabled eq false")) $org).value
    if (-not $users) { return Result 'WARN' "no $StudentPrefix*.$Estate accounts in this environment yet - run 07 before the delivery" }
    $need = @($DvRoleName) + $DvCompanionRoles
    $short = @()
    foreach ($u in $users) {
      $have = (Get-Json "$org/api/data/v9.2/systemusers($($u.systemuserid))/systemuserroles_association?`$select=name" $org).value | ForEach-Object { $_.name }
      $lack = @($need | Where-Object { $_ -notin $have })
      if ($lack.Count) { $short += "$($u.domainname.Split('@')[0]) lacks $($lack -join '+')" }
    }
    if ($short.Count) { return Result 'FAIL' (($short -join '; ') + ' - re-run 07') }
    # The roles are necessary, not sufficient: Dataverse filters a custom role for an unlicensed account
    # (accessmode 1, Administrative). Those attendees will be refused in the shared estate.
    $admin = @($users | Where-Object { $_.accessmode -eq 1 } | ForEach-Object { $_.domainname.Split('@')[0] })
    if ($admin.Count) { Result 'WARN' "$($users.Count) hold the roles, but $($admin.Count) run in Administrative mode (unlicensed or not yet re-synced): $($admin -join ', ') - the custom role is filtered for them here" }
    else { Result 'PASS' "$($users.Count) account(s) hold all of: $($need -join ', '); all licensed (accessmode 0)" }
  }
}

# --- summary -------------------------------------------------------------------------------------------------
Write-Host ''
$rows | Format-Table -AutoSize -Wrap -Property Status, Check, Detail, Protects | Out-String -Width 220 | Write-Host
$fails = @($rows | Where-Object Status -eq 'FAIL').Count
$warns = @($rows | Where-Object Status -eq 'WARN').Count
Write-Host ("{0} checks: {1} pass, {2} warn, {3} fail" -f $rows.Count, (@($rows | Where-Object Status -eq 'PASS').Count), $warns, $fails)
if ($warns) { Write-Host 'WARN = a live path is unavailable; the named steps fall back to the artifact pack. Tell the room before you start.' }
if ($fails) { Write-Host 'FAIL = the named steps will not work. Fix before the delivery.'; exit 1 }
