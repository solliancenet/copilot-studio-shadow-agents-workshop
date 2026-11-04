<#
FACILITATOR-ONLY. Phase 9 - Teardown. Removes ONE estate (setup/scripts/_estate.ps1) and nothing another
estate owns. Runs on Linux/macOS/Windows: it drives the Power Platform admin API, Graph and SharePoint with
`az`'s saved sign-in (+ the Phase 4 PnP app for SharePoint) - no Windows-only PowerApps module.

Order matters (dependencies): default-env agents + flow (as their owners) -> SharePoint sites -> the three
estate environments (their Dataverse/agents/connections go with them) + DLP + billing unlink. Then, opt-in,
the Phase 2 personas/groups (-RemovePersonas) and the shared per-tenant infra (-RemoveShared: authors group,
PnP app). KEEPS Phase 0 (tenant, CA baseline, security defaults) and the default environment.

Azure (Phase 1) is NOT this estate's to remove: one deployment serves every estate (ADR-0005). Only its
owner tears it down, and only when the last estate is gone (RUNBOOK Phase 9 -> Shared Azure deployment).
An estate built before ADR-0005 still has its OWN deployment (rg-halcourt-<estate>-lab): remove that one
with `azd down --purge --force`, its azd env selected - nothing else will.

  pwsh setup/scripts/99_teardown.ps1                              # estate from HALCOURT_ESTATE
  pwsh setup/scripts/99_teardown.ps1 -RemovePersonas -RemoveShared
#>
param(
  [string]$Estate      = $env:HALCOURT_ESTATE,
  [string]$TenantId,
  [string]$DomainSuffix,
  [string]$LabPassword,                                 # default: Get-LabPassword (_estate.ps1), only when signing in as a persona
  [string]$PnpClientId = $env:ENTRAID_APP_ID,          # Phase 4 PnP app (for SharePoint site removal)
  [string]$PnpCertPfx  = $env:HALCOURT_PNP_CERT_PFX,   # app-only cert; omit to skip site removal
  [string]$PnpCertPw   = $env:HALCOURT_PNP_CERT_PW,
  [switch]$RemovePersonas,
  [switch]$RemoveShared,
  [switch]$Force                                        # skip the type-the-estate-id confirmation
)
$ErrorActionPreference = 'Continue'
. (Join-Path $PSScriptRoot '_estate.ps1')
$Estate = Resolve-Estate $Estate
$AzClient = '04b07795-8ddb-461a-bbee-02f9e1bf7b46'
if (-not $TenantId)     { $TenantId = az account show --query tenantId -o tsv }
if (-not $DomainSuffix) { $DomainSuffix = az rest --method GET --url 'https://graph.microsoft.com/v1.0/organization?$select=verifiedDomains' --query "value[0].verifiedDomains[?isDefault].name | [0]" -o tsv }
# Fail fast on an unusable sign-in. A revoked or expired `az` login (InteractionRequired /
# TokenIssuedBeforeRevocationTimestamp) otherwise prints its error and the script carries on into the
# destructive steps with a blank tenant, domain and token.
$tokCheck = az account get-access-token --resource https://graph.microsoft.com --query accessToken -o tsv 2>&1
if ($LASTEXITCODE -ne 0 -or -not $TenantId -or -not $DomainSuffix) {
  # Quote az only when the token call failed: on success $tokCheck IS the access token, never print it.
  $azErr = if ($LASTEXITCODE -ne 0) { (@($tokCheck) | Where-Object { "$_".Trim() } | Select-Object -First 1) }
           else { 'a Graph token was issued, but the tenant or default-domain lookup came back empty' }
  throw "The az sign-in is unusable (no Graph token, tenant or domain). az said: $azErr (az profile: $env:AZURE_CONFIG_DIR). This can also be a transient network error, so re-running may be enough; otherwise sign in again, then re-run: az logout; az login --use-device-code --allow-no-subscriptions"
}
$estateEnvNames = 'Halcourt-Prod','Claims-Test','Maker-Sandbox' | ForEach-Object { Get-EstateName $_ $Estate }
function Get-Upn([string]$Alias) { "$(Get-EstateAlias $Alias $Estate)@$DomainSuffix" }
Write-SignInBanner
Write-Host "`nTearing down estate '$Estate' on $DomainSuffix. This will delete:"
Write-Host "  - the estate's agents, the auto-approve flow and connections in the shared default environment"
Write-Host "  - SharePoint sites $(@('HR-Benefits','Claims-Knowledge' | ForEach-Object { Get-EstateName $_ $Estate }) -join ', ') and the maker OneDrives"
Write-Host "  - environments $($estateEnvNames -join ', ') and the DLP policy $(Get-EstateName 'Halcourt-Prod-DLP' $Estate)"
if ($RemovePersonas) { Write-Host "  - the personas (*.$Estate@$DomainSuffix) and every group named *-$Estate" }
if ($RemoveShared)   { Write-Host "  - SHARED, every estate in the tenant: the Halcourt-Copilot-Authors group and the Halcourt PnP app" }
if (-not $Force) {
  if ((Read-Host "`nType the estate id ('$Estate') to confirm") -ne $Estate) { Write-Host 'Aborted.'; return }
}

# --- tokens / helpers (as the engine) -------------------------------------------------------------------
$script:AdminTokens = @{}
function Get-AdminToken([string]$r) { if (-not $script:AdminTokens[$r]) { $script:AdminTokens[$r] = az account get-access-token --resource $r --query accessToken -o tsv }; $script:AdminTokens[$r] }
function Get-PersonaToken([string]$a, [string]$r) {
  $body = @{ client_id = $AzClient; grant_type = 'password'; username = (Get-Upn $a); password = (Get-LabPassword $LabPassword); scope = "$($r.TrimEnd('/'))/.default" }
  # A persona that cannot sign in returns $null and sets $script:PersonaTokenError; callers skip, not retry.
  $script:PersonaTokenError = $null
  try { (Invoke-RestMethod -Method POST -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Body $body).access_token }
  catch { $script:PersonaTokenError = "$($_.ErrorDetails.Message) $($_.Exception.Message)"; $null }
}
function Invoke-Json([string]$m, [string]$u, [string]$tok, $body) {
  $h = @{ Authorization = "Bearer $tok"; Accept = 'application/json' }
  try { if ($null -ne $body) { Invoke-RestMethod -Method $m -Uri $u -Headers $h -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 20) } else { Invoke-RestMethod -Method $m -Uri $u -Headers $h } }
  catch { Write-Host "    ! $m $($u.Split('?')[0]) : $($_.Exception.Message.Split([char]10)[0])"; $null }
}
$BapHost = 'https://api.bap.microsoft.com'
$BAP = "$BapHost/providers/Microsoft.BusinessAppPlatform"
function Bap([string]$m, [string]$path, $body, [string]$api = '2021-04-01') { $sep = if ($path.Contains('?')) {'&'} else {'?'}; Invoke-Json $m ("$BAP/$path" + $sep + "api-version=$api") (Get-AdminToken 'https://service.powerapps.com/') $body }
function Graph([string]$m, [string]$path, $body, [switch]$Eventual) {
  $h = @{ Authorization = "Bearer $(Get-AdminToken 'https://graph.microsoft.com/')"; Accept = 'application/json' }
  if ($Eventual) { $h['ConsistencyLevel'] = 'eventual' }
  try { if ($null -ne $body) { Invoke-RestMethod -Method $m -Uri "https://graph.microsoft.com/v1.0/$path" -Headers $h -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 20) } else { Invoke-RestMethod -Method $m -Uri "https://graph.microsoft.com/v1.0/$path" -Headers $h } }
  catch { Write-Host "    ! graph $m $path : $($_.Exception.Message.Split([char]10)[0])"; $null }
}

$allEnvs = (Bap GET 'scopes/admin/environments').value
$defaultEnv = $allEnvs | Where-Object { $_.properties.displayName -eq 'Halcourt (default)' } | Select-Object -First 1

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
  $orphanRisk = @(); $skippedOwners = @()
  # Delete one agent with the given token; the three attempts and the read-back are the same for admin and owner.
  function Remove-DefaultEnvBot($b, [string]$tok, [string]$who) {
    Write-Host "  agent '$($b.name)' ($who)"
    $gone = $false
    foreach ($attempt in 'direct', 'after-components', 'after-deactivate') {
      if ($attempt -eq 'after-components') {
        foreach ($c in @((Invoke-Json GET "$org/api/data/v9.2/botcomponents?`$select=botcomponentid&`$filter=_parentbotid_value eq $($b.botid)" $tok).value)) {
          try { Invoke-Json DELETE "$org/api/data/v9.2/botcomponents($($c.botcomponentid))" $tok | Out-Null } catch { }
        }
      } elseif ($attempt -eq 'after-deactivate') {
        try { Invoke-Json PATCH "$org/api/data/v9.2/bots($($b.botid))" $tok @{ statecode = 1; statuscode = 2 } | Out-Null } catch { }
      }
      # Invoke-Json reports a failure and returns $null - it never throws - so read the agent back to know.
      Invoke-Json DELETE "$org/api/data/v9.2/bots($($b.botid))" $tok | Out-Null
      # Gone only if the read SUCCEEDS and finds nothing: a failed read (token, throttling) proves nothing.
      $chk = Invoke-Json GET "$org/api/data/v9.2/bots?`$select=botid&`$filter=botid eq $($b.botid)" $tok
      if ($null -ne $chk -and -not $chk.value) { $gone = $true; break }
    }
    if ($gone) { Write-Host "    deleted" }
    $gone
  }
  # The admin's own Dataverse token lists and deletes these even after the owner personas are gone (seen
  # 2026-11-02), so delete as the admin. Select by EXACT schema name (06: <committed schema><estate>): estate ids
  # are 2-12 chars, so one can be a suffix of another and endswith/contains would hit another estate's agent.
  # An agent the admin cannot see, or could not delete, falls back to its owner persona.
  $admTok = Get-AdminToken $org
  # The committed schema comes from the agent's workspace, as 06 reads it. An estate built before #33 kept the
  # committed (unsuffixed) schema: 06 accepts that one only under THIS estate's display name, and so do we.
  $AgentsDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'agents'
  function Get-CommittedSchema([string]$slug) {
    ((Select-String -Path (Join-Path $AgentsDir "$slug/settings.mcs.yml") -Pattern '^\s*schemaName:\s*(\S+)' | Select-Object -First 1).Matches.Groups[1].Value)
  }
  function Find-EstateBots($a, [string]$tok) {
    $cur = @((Invoke-Json GET "$org/api/data/v9.2/bots?`$select=botid,name&`$filter=schemaname eq '$($a.schema)'" $tok).value)
    $old = @((Invoke-Json GET "$org/api/data/v9.2/bots?`$select=botid,name&`$filter=schemaname eq '$($a.committed)'" $tok).value |
             Where-Object { $_.name -eq $a.display })
    @($cur) + @($old)
  }
  $agents = @(
    @{ label = 'Onboarding'; owner = 'tom.dean';  slug = 'onboarding-guide'; display = "Onboarding Guide ($Estate)" },
    @{ label = 'Expense';    owner = 'sam.olsen'; slug = 'expense-helper';   display = "Expense Helper ($Estate)" }
  )
  foreach ($a in $agents) {
    $a.committed = Get-CommittedSchema $a.slug
    $a.schema = "$($a.committed)$Estate"
    $found = @(Find-EstateBots $a $admTok)
    # Admin first; whatever the admin can't delete falls through to the owner, like an agent it can't see.
    $left = @(foreach ($b in $found) { if (-not (Remove-DefaultEnvBot $b $admTok 'as admin')) { $b } })
    if ($found -and -not $left) { continue }
    $owner = $a.owner
    $tok = Get-PersonaToken $owner $org
    if (-not $tok) {
      # No token means every call below would 401. AADSTS50034 = the owner is already gone from the directory.
      if ($script:PersonaTokenError -match 'AADSTS50034') {
        Write-Warning "Skipping the $($a.label) agent: the admin cannot see it and its owner $(Get-Upn $owner) no longer exists. In PPAC give the admin System Administrator on the default environment and delete the agent there (reference/runbook-errata.md, Teardown default-environment-agents)."
      } else {
        # The owner exists but we cannot be them (wrong lab password, locked, MFA). Carrying on would delete the
        # personas next and strand the agent, so stop here.
        throw "Cannot sign in as the $($a.label) agent's owner $(Get-Upn $owner): $($script:PersonaTokenError.Trim().Split([char]10)[0]). Fix the sign-in (lab password: Phase 0b step 5) and re-run; nothing after this point has run."
      }
      $skippedOwners += $owner
      foreach ($b in $left) { $orphanRisk += "$($b.name) ($($b.botid))" }
      continue
    }
    foreach ($b in @(Find-EstateBots $a $tok)) {
      if (-not (Remove-DefaultEnvBot $b $tok "owner $owner")) { $orphanRisk += "$($b.name) ($($b.botid))" }
    }
  }
  if ($orphanRisk) {
    Write-Warning "These default-environment agents could NOT be deleted: $($orphanRisk -join '; ')."
    Write-Warning "Delete them in Copilot Studio (as their owner) BEFORE re-running Phase 2, or the rebuilt"
    Write-Warning "personas will be new principals, the agents will be orphaned, and Phase 6 will fail to"
    Write-Warning "recreate them ('does not have WriteAccess ... entity Agent')."
  }
  if ($skippedOwners) { Write-Warning "Agents owned by $($skippedOwners -join ', ') were NOT deleted (owner cannot sign in) - see the warning above before re-running Phase 2." }
  $stok = if ($skippedOwners -contains 'sam.olsen') { $null } else { Get-PersonaToken 'sam.olsen' $org }
  if (-not $stok) { Write-Warning "The auto-approve flow ('Submit and auto-approve...') was NOT deleted: sam.olsen cannot sign in. It stays in the shared default environment; delete it there as an admin." }
  foreach ($w in @(if ($stok) { (Invoke-Json GET "$org/api/data/v9.2/workflows?`$select=workflowid,name&`$filter=category eq 5 and startswith(name,'Submit and auto-approve')" $stok).value })) {
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
# Order: billing links first - an environment that has finished deleting can't be unlinked, and its link
# stays on the shared plan (08 -Destroy learned the same). Each step reads back what it changed, because
# Invoke-Json reports a failure and returns $null rather than throwing.
$estateEnvs = @($estateEnvNames | ForEach-Object { $n = $_; $allEnvs | Where-Object { $_.properties.displayName -eq $n } | Select-Object -First 1 })
$estateEnvIds = @($estateEnvs.name)
if ($estateEnvIds) {
  $ppApi = 'api-version=2022-03-01-preview'; $pp = 'https://api.powerplatform.com/licensing/billingPolicies'
  foreach ($bp in @((Invoke-Json GET "$pp`?$ppApi" (Get-AdminToken 'https://api.powerplatform.com/')).value)) {
    # By id: the plan's name (e.g. ppccdevcanada) answers 403 here. The /environments sub-resource is the
    # authoritative list; the policy's own environmentIds is always null.
    $read = { (Invoke-Json GET "$pp/$($bp.id)/environments?$ppApi" (Get-AdminToken 'https://api.powerplatform.com/')) }
    $r = & $read
    if ($null -eq $r) { Write-Warning "could not read billing plan $($bp.name)'s environments - check it for this estate's links"; continue }
    $linked = @($r.value.environmentId | Where-Object { $_ -in $estateEnvIds })
    if (-not $linked) { continue }
    Invoke-Json POST "$pp/$($bp.id)/environments/remove?$ppApi" (Get-AdminToken 'https://api.powerplatform.com/') @{ environmentIds = $linked } | Out-Null
    $left = @((& $read).value.environmentId | Where-Object { $_ -in $estateEnvIds })
    if ($left) { Write-Warning "billing plan $($bp.name) still links $($left.Count) of this estate's environment(s): $($left -join ', ')" }
    else { Write-Host "  unlinked $($linked.Count) env(s) from billing plan $($bp.name)" }
  }
}
Write-Host "Removing environments $($estateEnvNames -join ', ') + DLP..."
foreach ($e in $estateEnvs) {
  Bap DELETE "scopes/admin/environments/$($e.name)" $null | Out-Null
  Write-Host "  deleting $($e.properties.displayName)"
}
# The policy API hangs off the bare BAP host, not $BAP's Microsoft.BusinessAppPlatform provider: that address
# answers 404, and the DLP survived every teardown until 2026-10-22, then blocked the next Phase 3 by name.
$dlp = Get-EstateName 'Halcourt-Prod-DLP' $Estate
$policyApi = "$BapHost/providers/PowerPlatform.Governance/v1/policies"
$findDlp = { (Invoke-Json GET "$policyApi`?api-version=2016-11-01" (Get-AdminToken 'https://service.powerapps.com/')) }
$all = & $findDlp
if ($null -eq $all) { Write-Warning "could not list DLP policies - check for $dlp by hand" }
elseif ($pol = $all.value | Where-Object { $_.displayName -eq $dlp } | Select-Object -First 1) {
  Invoke-Json DELETE "$policyApi/$($pol.name)?api-version=2016-11-01" (Get-AdminToken 'https://service.powerapps.com/') | Out-Null
  if ((& $findDlp).value | Where-Object { $_.displayName -eq $dlp }) { Write-Warning "DLP $dlp still exists after DELETE - remove it in PPAC" }
  else { Write-Host "  deleted DLP $dlp" }
} else { Write-Host "  no DLP named $dlp found" }

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
Write-Host "Azure (Phase 1) kept: it is shared by every estate. Only its owner removes it, after the last estate (RUNBOOK Phase 9)."
if (-not $RemovePersonas) { Write-Host "Personas/groups kept - pass -RemovePersonas to remove them." }
if (-not $RemoveShared)   { Write-Host "Shared authors group + PnP app kept - pass -RemoveShared to remove them." }
