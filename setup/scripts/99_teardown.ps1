<#
FACILITATOR-ONLY. Phase 9 - Teardown. Removes ONE estate (setup/scripts/_estate.ps1) and nothing another
estate owns. Runs on Linux/macOS/Windows: it drives the Power Platform admin API, Graph and SharePoint with
`az`'s saved sign-in (+ the Phase 4 PnP app for SharePoint) - no Windows-only PowerApps module.

Order matters (dependencies): default-env agents + flow (as their owners) -> SharePoint sites -> the three
estate environments (their Dataverse/agents/connections go with them) + DLP + billing unlink. Then, opt-in,
the Phase 2 personas/groups (-RemovePersonas) and the shared per-tenant infra (-RemoveShared: authors group,
PnP app). KEEPS Phase 0 (tenant, CA baseline, security defaults) and the default environment.

Azure (Phase 1) is separate - run it after this:
  azd down --purge --force        # from the repo root, with the estate's azd env selected

  pwsh setup/scripts/99_teardown.ps1                              # estate from HALCOURT_ESTATE
  pwsh setup/scripts/99_teardown.ps1 -RemovePersonas -RemoveShared
#>
param(
  [string]$Estate      = $env:HALCOURT_ESTATE,
  [string]$TenantId,
  [string]$DomainSuffix,
  [string]$LabPassword = 'Lab-Only-Passw0rd!',
  [string]$PnpClientId = $env:ENTRAID_APP_ID,          # Phase 4 PnP app (for SharePoint site removal)
  [string]$PnpCertPfx  = $env:HALCOURT_PNP_CERT_PFX,   # app-only cert; omit to skip site removal
  [string]$PnpCertPw   = $env:HALCOURT_PNP_CERT_PW,
  [switch]$RemovePersonas,
  [switch]$RemoveShared
)
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot '_estate.ps1')
$Estate = Resolve-Estate $Estate
$AzClient = '04b07795-8ddb-461a-bbee-02f9e1bf7b46'
if (-not $TenantId)     { $TenantId = az account show --query tenantId -o tsv }
if (-not $DomainSuffix) { $DomainSuffix = az rest --method GET --url 'https://graph.microsoft.com/v1.0/organization?$select=verifiedDomains' --query "value[0].verifiedDomains[?isDefault].name | [0]" -o tsv }
function Get-Upn([string]$Alias) { "$(Get-EstateAlias $Alias $Estate)@$DomainSuffix" }
Write-Host "Tearing down estate '$Estate' on $DomainSuffix"

# --- tokens / helpers (as the engine) -------------------------------------------------------------------
$script:AdminTokens = @{}
function Get-AdminToken([string]$r) { if (-not $script:AdminTokens[$r]) { $script:AdminTokens[$r] = az account get-access-token --resource $r --query accessToken -o tsv }; $script:AdminTokens[$r] }
function Get-PersonaToken([string]$a, [string]$r) {
  $body = @{ client_id = $AzClient; grant_type = 'password'; username = (Get-Upn $a); password = $LabPassword; scope = "$($r.TrimEnd('/'))/.default" }
  (Invoke-RestMethod -Method POST -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Body $body).access_token
}
function Invoke-Json([string]$m, [string]$u, [string]$tok, $body) {
  $h = @{ Authorization = "Bearer $tok"; Accept = 'application/json' }
  try { if ($null -ne $body) { Invoke-RestMethod -Method $m -Uri $u -Headers $h -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 20) } else { Invoke-RestMethod -Method $m -Uri $u -Headers $h } }
  catch { Write-Host "    ! $m $($u.Split('?')[0]) : $($_.Exception.Message.Split([char]10)[0])"; $null }
}
$BAP = 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform'
function Bap([string]$m, [string]$path, $body, [string]$api = '2021-04-01') { $sep = if ($path.Contains('?')) {'&'} else {'?'}; Invoke-Json $m ("$BAP/$path" + $sep + "api-version=$api") (Get-AdminToken 'https://service.powerapps.com/') $body }
function Graph([string]$m, [string]$path, $body, [switch]$Eventual) {
  $h = @{ Authorization = "Bearer $(Get-AdminToken 'https://graph.microsoft.com/')"; Accept = 'application/json' }
  if ($Eventual) { $h['ConsistencyLevel'] = 'eventual' }
  try { if ($null -ne $body) { Invoke-RestMethod -Method $m -Uri "https://graph.microsoft.com/v1.0/$path" -Headers $h -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 20) } else { Invoke-RestMethod -Method $m -Uri "https://graph.microsoft.com/v1.0/$path" -Headers $h } }
  catch { Write-Host "    ! graph $m $path : $($_.Exception.Message.Split([char]10)[0])"; $null }
}

$allEnvs = (Bap GET 'scopes/admin/environments').value
$defaultEnv = $allEnvs | Where-Object { $_.properties.displayName -eq 'Halcourt (default)' } | Select-Object -First 1
$estateEnvNames = 'Halcourt-Prod','Claims-Test','Maker-Sandbox' | ForEach-Object { Get-EstateName $_ $Estate }

# --- 1) default-env agents (owned by this estate's personas) + the auto-approve flow --------------------
if ($defaultEnv) {
  $org = $defaultEnv.properties.linkedEnvironmentMetadata.instanceUrl.TrimEnd('/')
  Write-Host "Removing this estate's agents + flow from the shared default environment..."
  # Deleting these MUST succeed, and it is the one step in this script with a nasty failure mode. A PUBLISHED
  # agent refuses a plain DELETE with 400. If it survives, the personas are deleted a few steps below, the
  # agent is orphaned on a systemuser nobody can reach (the default environment has no human System
  # Administrator - only Microsoft service principals), and the NEXT build fails its solution import with
  # "does not have WriteAccess right(s) ... of entity Agent" for an agent it cannot see or remove.
  # So: drop the agent's components, deactivate it, then delete - and shout if it still will not go.
  $orphanRisk = @()
  foreach ($owner in 'tom.dean','sam.olsen') {                     # the default-env agent owners (Onboarding, Expense)
    $tok = Get-PersonaToken $owner $org
    foreach ($b in @((Invoke-Json GET "$org/api/data/v9.2/bots?`$select=botid,name" $tok).value)) {
      Write-Host "  agent '$($b.name)' (owner $owner)"
      $gone = $false
      foreach ($attempt in 'direct', 'after-components', 'after-deactivate') {
        if ($attempt -eq 'after-components') {
          foreach ($c in @((Invoke-Json GET "$org/api/data/v9.2/botcomponents?`$select=botcomponentid&`$filter=_parentbotid_value eq $($b.botid)" $tok).value)) {
            try { Invoke-Json DELETE "$org/api/data/v9.2/botcomponents($($c.botcomponentid))" $tok | Out-Null } catch { }
          }
        } elseif ($attempt -eq 'after-deactivate') {
          try { Invoke-Json PATCH "$org/api/data/v9.2/bots($($b.botid))" $tok @{ statecode = 1; statuscode = 2 } | Out-Null } catch { }
        }
        try { Invoke-Json DELETE "$org/api/data/v9.2/bots($($b.botid))" $tok | Out-Null; $gone = $true; break } catch { }
      }
      if ($gone) { Write-Host "    deleted" } else { $orphanRisk += "$($b.name) ($($b.botid))" }
    }
  }
  if ($orphanRisk) {
    Write-Warning "These default-environment agents could NOT be deleted: $($orphanRisk -join '; ')."
    Write-Warning "Delete them in Copilot Studio (as their owner) BEFORE re-running Phase 2, or the rebuilt"
    Write-Warning "personas will be new principals, the agents will be orphaned, and Phase 6 will fail to"
    Write-Warning "recreate them ('does not have WriteAccess ... entity Agent')."
  }
  $stok = Get-PersonaToken 'sam.olsen' $org
  foreach ($w in @((Invoke-Json GET "$org/api/data/v9.2/workflows?`$select=workflowid,name&`$filter=category eq 5 and startswith(name,'Submit and auto-approve')" $stok).value)) {
    Write-Host "  flow '$($w.name)'"; Invoke-Json PATCH "$org/api/data/v9.2/workflows($($w.workflowid))" $stok @{ statecode = 0; statuscode = 1 } | Out-Null
    Invoke-Json DELETE "$org/api/data/v9.2/workflows($($w.workflowid))" $stok | Out-Null
  }

  # Connections in the estate environments disappear with the environment; these do not. Nothing removed
  # them, so every rebuild left another set behind - four had piled up across three builds, and the
  # artifact-pack export duly reported one agent's connection three times. Match on the estate's own
  # accounts so another estate's connections in this shared environment are never touched.
  $ppAdmin = "https://api.powerapps.com/providers/Microsoft.PowerApps/scopes/admin/environments/$($defaultEnv.name)"
  $adminTok = Get-AdminToken 'https://service.powerapps.com/'
  foreach ($c in @((Invoke-Json GET "$ppAdmin/connections?api-version=2016-11-01" $adminTok).value)) {
    $upn = $c.properties.createdBy.userPrincipalName
    if ($upn -notlike "*.$Estate@*") { continue }
    $connector = ($c.properties.apiId -split '/')[-1]
    Write-Host "  connection '$($c.properties.displayName)' ($connector, $upn)"
    try { Invoke-Json DELETE "$ppAdmin/apis/$connector/connections/$($c.name)?api-version=2016-11-01" $adminTok | Out-Null }
    catch { Write-Warning "    could not delete it: $($_.Exception.Message.Split([Environment]::NewLine)[0])" }
  }
}

# --- 2) SharePoint sites (+ recycle-bin purge) via the PnP app-only cert --------------------------------
$tenantName = $DomainSuffix.Split('.')[0]
$siteSlugs = 'HR-Benefits','Claims-Knowledge' | ForEach-Object { Get-EstateName $_ $Estate }
if ($PnpClientId -and $PnpCertPfx -and (Test-Path $PnpCertPfx)) {
  Write-Host "Removing SharePoint sites $($siteSlugs -join ', ') (and purging them so the URLs are reusable)..."
  $certpw = if ($PnpCertPw) { ConvertTo-SecureString $PnpCertPw -AsPlainText -Force } else { $null }
  $ca = @{ ClientId = $PnpClientId; Tenant = $DomainSuffix; CertificatePath = $PnpCertPfx; WarningAction = 'SilentlyContinue' }
  if ($certpw) { $ca.CertificatePassword = $certpw }
  Connect-PnPOnline -Url "https://$tenantName-admin.sharepoint.com" @ca

  # These are GROUP-connected team sites, so deleting the site is really deleting its M365 group - the group
  # owns the site and re-creates/keeps it otherwise. Remove-PnPTenantSite on its own reports success and
  # leaves the site Active, which is why this used to print "removed" over a site that was still there.
  # Order matters: delete the group, wait for the cascade to put the site in the recycle bin, THEN purge it.
  # Skipping the purge leaves the URL reserved, and the next build silently lands on '<alias>9'.
  foreach ($slug in $siteSlugs) {
    $full = "https://$tenantName.sharepoint.com/sites/$slug"
    $gid = az rest --method GET --url "https://graph.microsoft.com/v1.0/groups?`$filter=mailNickname eq '$slug'&`$select=id" --query 'value[0].id' -o tsv 2>$null
    if ($gid) {
      az rest --method DELETE --url "https://graph.microsoft.com/v1.0/groups/$gid" -o none 2>$null
      az rest --method DELETE --url "https://graph.microsoft.com/v1.0/directory/deletedItems/$gid" -o none 2>$null   # free the mailNickname
      Write-Host "  deleted the M365 group behind $slug"
    }
  }

  # Deleting the group does NOT promptly delete the site - waiting for that cascade can take hours. What
  # does work: once the group is gone the site is ORPHANED, and Remove-PnPTenantSite then succeeds straight
  # away. It can still refuse for a short while until the group deletion propagates, so retry briefly.
  # Finally purge, or the URL stays reserved and the next build silently lands on '<alias>9'.
  foreach ($slug in $siteSlugs) {
    $full = "https://$tenantName.sharepoint.com/sites/$slug"
    $deadline = (Get-Date).AddMinutes(5)
    $removed = $false
    while (-not $removed -and (Get-Date) -lt $deadline) {
      if (-not (Get-PnPTenantSite -Identity $full -ErrorAction SilentlyContinue)) { $removed = $true; break }
      try { Remove-PnPTenantSite -Url $full -Force -ErrorAction Stop; $removed = $true }
      catch { Start-Sleep -Seconds 20 }
    }
    if ($removed) { Write-Host "  removed $slug" } else { Write-Warning "  could not remove $slug - remove and purge it by hand." }
    try { Remove-PnPTenantDeletedSite -Identity $full -Force -ErrorAction Stop; Write-Host "  purged $slug (URL reusable)" }
    catch { Write-Warning "  $slug is not purged - the next build may land on '${slug}9'. Purge by hand: Remove-PnPTenantDeletedSite -Identity $full -Force" }
  }

  # Maker OneDrives. These do NOT go away with the personas or the environments, so without this a
  # "greenfield" rebuild silently inherits the old personal sites and their seeded contents - which is
  # exactly why Phase 4b once reported "already online" against a site provisioned days earlier. Purge as
  # well as delete, or a re-provision lands on a suffixed URL (..._onmicrosoft_com1) while the original sits
  # in the recycle bin. Personal-site URLs carry the estate id (dev_kim_<estate>_<tenant>_onmicrosoft_com).
  Write-Host "Removing this estate's maker OneDrives..."
  $mySites = @(Get-PnPTenantSite -IncludeOneDriveSites -Filter "Url -like '-my.sharepoint.com/personal/'" -ErrorAction SilentlyContinue |
               Where-Object { $_.Url -match "_$([regex]::Escape($Estate))_" })
  if (-not $mySites) { Write-Host '  none found.' }
  foreach ($s in $mySites) {
    try { Remove-PnPTenantSite -Url $s.Url -Force -ErrorAction SilentlyContinue; Write-Host "  removed $($s.Url -replace '.*/personal/','')" } catch { }
    try { Remove-PnPTenantDeletedSite -Identity $s.Url -Force -ErrorAction SilentlyContinue } catch { }
  }
} else {
  Write-Host "SKIP SharePoint sites + maker OneDrives (no PnP app/cert). Delete the sites' M365 groups (mailNickname $($siteSlugs -join ', ')) or pass -PnpCertPfx."
}

# --- 3) the three estate environments (Dataverse/agents/connections go with them) + DLP + billing -------
Write-Host "Removing environments $($estateEnvNames -join ', ') + DLP..."
$estateEnvIds = @()
foreach ($name in $estateEnvNames) {
  $e = $allEnvs | Where-Object { $_.properties.displayName -eq $name } | Select-Object -First 1
  if (-not $e) { continue }
  $estateEnvIds += $e.name
  Bap DELETE "scopes/admin/environments/$($e.name)" $null | Out-Null
  Write-Host "  deleting $name"
}
# NOTE the '/providers' segment - without it the list call returns nothing, the policy is never found, and
# the DLP silently survives the teardown. It then outlives the environment it was scoped to, and the next
# Phase 3 sees the name already in use and leaves Prod with no DLP at all.
$dlp = Get-EstateName 'Halcourt-Prod-DLP' $Estate
# NOT under $BAP: that already ends in /providers/Microsoft.BusinessAppPlatform, and the policy API sits beside it.
# Built on $BAP the GET 404'd and the teardown reported "no DLP found" - and the policy survived (2026-10-21).
$policyApi = 'https://api.bap.microsoft.com/providers/PowerPlatform.Governance/v1/policies'
$list = Invoke-Json GET "$policyApi`?api-version=2016-11-01" (Get-AdminToken 'https://service.powerapps.com/')
if ($null -eq $list) {
  Write-Warning "  could not list DLP policies (above) - check for $dlp by hand; if it survives, Phase 3 leaves Prod without DLP"
} else {
  $pol = @($list.value) | Where-Object { $_.displayName -eq $dlp } | Select-Object -First 1
  if (-not $pol) { Write-Host "  no DLP named $dlp found" }
  elseif ($null -ne (Invoke-Json DELETE "$policyApi/$($pol.name)?api-version=2016-11-01" (Get-AdminToken 'https://service.powerapps.com/')) -or
          -not (@((Invoke-Json GET "$policyApi`?api-version=2016-11-01" (Get-AdminToken 'https://service.powerapps.com/')).value) | Where-Object { $_.name -eq $pol.name })) {
    Write-Host "  deleted DLP $dlp"
  } else { Write-Warning "  DLP $dlp still exists after DELETE - remove it by hand (PPAC -> Security -> Data and privacy -> Data policy)" }
}
# Unlink the estate envs from any billing plan (also happens as the envs finish deleting). Read the linked
# list from the /environments SUB-RESOURCE: a billing policy's own `environmentIds` property always comes
# back null, so filtering on it silently unlinked nothing.
if ($estateEnvIds) {
  $ppApi = 'api-version=2022-03-01-preview'
  foreach ($bp in @((Invoke-Json GET "https://api.powerplatform.com/licensing/billingPolicies?$ppApi" (Get-AdminToken 'https://api.powerplatform.com/')).value)) {
    $current = @((Invoke-Json GET "https://api.powerplatform.com/licensing/billingPolicies/$($bp.name)/environments?$ppApi" (Get-AdminToken 'https://api.powerplatform.com/')).value.environmentId)
    $linked = @($current | Where-Object { $_ -in $estateEnvIds })
    if ($linked) {
      Invoke-Json POST "https://api.powerplatform.com/licensing/billingPolicies/$($bp.name)/environments/remove?$ppApi" (Get-AdminToken 'https://api.powerplatform.com/') @{ environmentIds = $linked } | Out-Null
      Write-Host "  unlinked $($linked.Count) env(s) from billing plan $($bp.name)"
    }
  }
}

# --- 4) personas + groups (opt-in) ---------------------------------------------------------------------
if ($RemovePersonas) {
  Write-Host "Removing this estate's personas and groups..."
  foreach ($u in @((Graph GET "users?`$filter=endsWith(userPrincipalName,'.$Estate@$DomainSuffix')&`$select=id,userPrincipalName&`$count=true" $null -Eventual).value)) {
    Write-Host "  user $($u.userPrincipalName)"; Graph DELETE "users/$($u.id)" $null | Out-Null
  }
  # security groups (<name>-<estate>) AND the M365 site groups (mailNickname <slug>-<estate>)
  $groups = @((Graph GET "groups?`$filter=endsWith(displayName,'-$Estate') or endsWith(mailNickname,'-$Estate')&`$select=id,displayName&`$count=true" $null -Eventual).value)
  foreach ($g in ($groups | Sort-Object id -Unique)) { Write-Host "  group $($g.displayName)"; Graph DELETE "groups/$($g.id)" $null | Out-Null }

  # Deleting a user or group only SOFT-deletes it: it sits in directory/deletedItems for 30 days still
  # holding its UPN, mailNickname and proxy addresses. Re-creating the estate on top of that works, but the
  # leftovers pile up one set per rebuild, so purge them and leave the directory genuinely empty.
  Write-Host "  purging soft-deleted estate users and groups..."
  foreach ($type in 'microsoft.graph.user', 'microsoft.graph.group') {
    foreach ($d in @((Graph GET "directory/deletedItems/$type`?`$select=id,displayName,userPrincipalName,mailNickname" $null).value)) {
      $tag = "$($d.userPrincipalName)$($d.mailNickname)$($d.displayName)"
      if ($tag -match "[.\-]$([regex]::Escape($Estate))(@|$)") { Graph DELETE "directory/deletedItems/$($d.id)" $null | Out-Null }
    }
  }
}

# --- 5) shared per-tenant infra (opt-in) ---------------------------------------------------------------
if ($RemoveShared) {
  Write-Host "Removing shared per-tenant infra (authors group + PnP app)..."
  foreach ($g in @((Graph GET "groups?`$filter=displayName eq 'Halcourt-Copilot-Authors'&`$select=id,displayName" $null).value)) { Write-Host "  group $($g.displayName)"; Graph DELETE "groups/$($g.id)" $null | Out-Null }
  $app = az ad app list --display-name 'Halcourt PnP' --query '[0].appId' -o tsv
  if ($app) { az ad app delete --id $app 2>$null | Out-Null; Write-Host "  deleted PnP app $app" }
}

Write-Host ""
Write-Host "Teardown of estate '$Estate' complete (environments delete asynchronously - allow a few minutes)."
Write-Host "Azure (Phase 1) is separate:  azd down --purge --force   (repo root, estate's azd env selected)."
if (-not $RemovePersonas) { Write-Host "Personas/groups kept - pass -RemovePersonas to remove them." }
if (-not $RemoveShared)   { Write-Host "Shared authors group + PnP app kept - pass -RemoveShared to remove them." }
