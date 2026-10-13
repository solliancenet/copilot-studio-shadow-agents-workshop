<#
FACILITATOR-ONLY. Phase 8b - Lab (attendee) accounts. Creates N native accounts in the lab tenant so you
can hand out a username and password per attendee, and removes them again after the delivery (-Destroy).

Native accounts, NOT guest invites: an attendee signs in to the lab tenant itself, so they see the estate
the way a reviewer inside Halcourt Mutual would. Nothing here touches the Phase 2 personas - the estate's
own accounts (marcus.webb, priya.nair, ...) are canon and are built by 01_provision_entra.ps1.

Runs anywhere `az` runs (Linux included): Graph over REST with az's saved sign-in, like 99_teardown.ps1.

WHY ATTENDEES GET AN ADMIN ROLE, AND WHAT THAT COSTS

  Lab 01-01 has attendees enumerate an environment's connections. Only the tenant-admin Power Platform
  endpoints under /scopes/admin/ can do that, and only Power Platform Administrator reaches them.
  Verified live 2026-10-13: nothing weaker works, and the weaker options were not guesses -

  - Global Reader gets HTTP 404 CRMRequestFailed where a tenant admin gets 200. Those endpoints hide
    themselves from an unauthorized caller instead of returning 403, so the attendee sees an empty
    estate rather than an error.
  - A per-environment role does not help either. The maker-facing connections API is caller-scoped: a
    maker who owns one of an environment's two connections sees exactly that one, and environment
    members who own none see zero. No environment role enumerates another person's connections.

  So the role is necessary. It is also MFA-gated: Power Platform Administrator sits in
  CA-Require-MFA-Admins (00_conditional_access_baseline.ps1), and an account holding it cannot sign in
  with a handed-out password at all - AADSTS50079, "must enroll in multi-factor authentication".

  This script resolves that by excluding ONE group from that policy: Lab-Students-<estate>, holding only
  this delivery's attendee accounts. The exclusion is added to the policy's excludeGroups without
  touching any exclusion another estate added, and -Destroy removes only this estate's group id.

  THE COST, STATED PLAINLY. An attendee account is a tenant-wide Power Platform admin that is exempt
  from the admin MFA policy. It can change or delete any environment in the tenant, including another
  facilitator's estate. Run a delivery in its own tenant where you can. Nothing here is appropriate
  outside an isolated, disposable training tenant.

  Attendees still do not need a LICENCE: Entra reads and the admin APIs both work unlicensed.

LICENSES ARE BEST EFFORT BY DESIGN. A Dev Program sandbox has 25 E5 seats and the estate itself needs
eight (RUNBOOK -> Phase 2); the content-pack sample users hold the rest. Assignment is attempted, never
fatal, and the end-of-run table says who actually got one. Attendees do not need a seat for the tasks
above - only for anything that opens Copilot Studio, which Lab 01-01 step 6 already says requires being
an agent's owner or co-author, so attendees do not do it.

Estate (setup/scripts/_estate.ps1): accounts carry this build's estate id, so two facilitators can run
deliveries in one tenant without adopting each other's attendees - student01.<estate>@<domain>.

  pwsh setup/scripts/07_provision_lab_users.ps1 -Count 20
  pwsh setup/scripts/07_provision_lab_users.ps1 -Count 20 -UniquePasswords
  pwsh setup/scripts/07_provision_lab_users.ps1 -Destroy

Safe to re-run: accounts that already exist are left alone and still listed in the handout table.
ASCII only.
#>
param(
  [int]$Count                = 10,                     # how many attendee accounts
  [string]$Estate            = $env:HALCOURT_ESTATE,   # this build's estate id, e.g. mgray (_estate.ps1)
  [string]$Prefix            = 'student',              # student01.<estate>, student02.<estate>, ...
  [string]$TenantId,                                   # default: the tenant az is signed in to
  [string]$DomainSuffix,                               # default: the tenant's default verified domain
  [string]$InitialPassword   = 'Lab-Only-Passw0rd!',   # one shared password; rotate per delivery
  [switch]$UniquePasswords,                            # instead: a distinct typed-by-hand password each
  [string[]]$Roles           = @('Power Platform Administrator'),  # see the header: needed for Lab 01-01
  [string]$LabGroup,                                   # CA-exclusion group; default Lab-Students-<estate>
  [switch]$NoCaExclusion,                              # skip the CA exclusion (sign-in will then fail)
  [switch]$NoDataverseRole,                            # skip the per-environment Dataverse read role
  [string[]]$LicenseSku      = @('DEVELOPERPACK_V2_E5'),  # skuPartNumber(s), best effort, in order
  [switch]$NoLicense,                                  # skip licensing entirely
  [string]$CredentialCsv,                              # default: setup/lab-users-<estate>.local.csv
  [switch]$Destroy,                                    # delete AND purge this estate's attendee accounts
  [switch]$Force                                       # -Destroy without the confirmation prompt
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_estate.ps1')
$Estate = Resolve-Estate $Estate

if (-not (Get-Command az -ErrorAction SilentlyContinue)) { throw 'This script needs the Azure CLI (az) - see scripts/env.sh.' }
if (-not $TenantId)     { $TenantId     = az account show --query tenantId -o tsv }
if (-not $DomainSuffix) { $DomainSuffix = az rest --method GET --url 'https://graph.microsoft.com/v1.0/organization?$select=verifiedDomains' --query "value[0].verifiedDomains[?isDefault].name | [0]" -o tsv }
if (-not $DomainSuffix) { throw 'Could not read the tenant domain from Graph - is az signed in to the lab tenant?' }

# --- Graph over az's sign-in (same helper shape as 99_teardown.ps1) --------------------------------------
$script:Tokens = @{}
function Get-AdminToken([string]$r) { if (-not $script:Tokens[$r]) { $script:Tokens[$r] = az account get-access-token --resource $r --query accessToken -o tsv }; $script:Tokens[$r] }
function Graph([string]$m, [string]$path, $body) {
  $h = @{ Authorization = "Bearer $(Get-AdminToken 'https://graph.microsoft.com/')"; Accept = 'application/json' }
  $uri = "https://graph.microsoft.com/v1.0/$path"
  if ($null -ne $body) { Invoke-RestMethod -Method $m -Uri $uri -Headers $h -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 20) }
  else                 { Invoke-RestMethod -Method $m -Uri $uri -Headers $h }
}
# Same call, but a failure is data rather than a terminating error: returns $null and the reason.
function Try-Graph([string]$m, [string]$path, $body, [ref]$Err) {
  try { $Err.Value = $null; Graph $m $path $body }
  catch {
    $msg = $_.Exception.Message
    # Graph puts the useful part in the response body, not the status line.
    if ($_.ErrorDetails.Message) {
      try { $msg = ($_.ErrorDetails.Message | ConvertFrom-Json).error.message } catch { $msg = $_.ErrorDetails.Message }
    }
    $Err.Value = ($msg -split "`n")[0].Trim(); $null
  }
}

function Get-LabUpn([int]$N) { "$(Get-EstateAlias ("{0}{1:d2}" -f $Prefix, $N) $Estate)@$DomainSuffix" }

# Typed by hand off a slip of paper, so skip characters that are read wrong: O/0, I/l/1, S/5.
function New-LabPassword {
  $upper = 'ABCDEFGHJKMNPQRTUVWXYZ'; $lower = 'abcdefghjkmnpqrtuvwxyz'; $digit = '23467892346789'; $sym = '!@#$%*-+='
  $pick  = { param($set, $n) -join (1..$n | ForEach-Object { $set[(Get-Random -Maximum $set.Length)] }) }
  # One of each class first so the result always satisfies Entra complexity, then shuffle.
  $core = (& $pick $upper 1) + (& $pick $lower 1) + (& $pick $digit 1) + (& $pick $sym 1) + (& $pick ($upper+$lower+$digit) 8)
  -join ($core.ToCharArray() | Sort-Object { Get-Random })
}

if (-not $LabGroup) { $LabGroup = Get-EstateName 'Lab-Students' $Estate }

# Returns this delivery's CA-exclusion group, creating it on first use. Estate-scoped, so two deliveries
# in one tenant never share a group - which is the whole point: the exclusion must name only these users.
function Get-LabGroupId([switch]$CreateIfMissing) {
  $g = @((Graph GET "groups?`$filter=displayName eq '$LabGroup'&`$select=id,displayName").value) | Select-Object -First 1
  if ($g) { return $g.id }
  if (-not $CreateIfMissing) { return $null }
  Write-Host "Creating group $LabGroup (Conditional Access exclusion for this delivery)"
  (Graph POST 'groups' @{
      displayName     = $LabGroup
      mailNickname    = $LabGroup
      mailEnabled     = $false
      securityEnabled = $true
      description     = "Attendee accounts for estate '$Estate'. Excluded from $CaPolicyName. Delete after the delivery."
    }).id
}

# --- Conditional Access exclusion ------------------------------------------------------------------------
# The attendee role is MFA-gated (see the header), so these accounts must be excluded from the admin MFA
# policy or they cannot sign in at all.
#
# This needs no extra sign-in. 00_conditional_access_baseline.ps1 connects separately because it needs
# Policy.ReadWrite.ConditionalAccess, but az's delegated Directory.AccessAsUser.All already covers reading
# and patching Conditional Access for a Global Administrator - verified 2026-10-13 (GET 200, PATCH 204).
$CaPolicyName = 'CA-Require-MFA-Admins'
$CaUri        = 'identity/conditionalAccess/policies'
# Graph replaces 'conditions' wholesale on PATCH, so the policy is read, ONE field is changed, and the whole
# conditions object goes back. Nulls are stripped because Graph rejects some of them on write.
function Remove-NullKeys($o) {
  if ($o -is [System.Collections.IDictionary]) {
    $clean = @{}
    foreach ($k in $o.Keys) { if ($null -ne $o[$k]) { $clean[$k] = Remove-NullKeys $o[$k] } }
    return $clean
  }
  if ($o -is [object[]]) { return @($o | ForEach-Object { Remove-NullKeys $_ }) }
  return $o
}
function Set-CaExclusion([string]$GroupId, [string]$Action) {   # Action: 'add' | 'remove'
  $policy = @((Graph GET $CaUri).value) |
            Where-Object { $_.displayName -eq $CaPolicyName } | Select-Object -First 1
  if (-not $policy) { throw "No '$CaPolicyName' policy in this tenant - run 00_conditional_access_baseline.ps1 first." }

  # Additive both ways: every exclusion another estate added stays, only this group id moves.
  $current = @($policy.conditions.users.excludeGroups | Where-Object { $_ })
  $updated = if ($Action -eq 'add') { @($current) + $GroupId | Select-Object -Unique }
             else                   { @($current | Where-Object { $_ -ne $GroupId }) }
  if (($current -join ',') -eq ((@($updated)) -join ',')) {
    Write-Host "  $CaPolicyName already has this estate's exclusion as it should be."
    return
  }
  $roleCountBefore = @($policy.conditions.users.includeRoles).Count
  $conditions = Remove-NullKeys $policy.conditions
  $conditions.users.excludeGroups = @($updated)
  Graph PATCH "$CaUri/$($policy.id)" @{ conditions = $conditions } | Out-Null

  # Never take the write on trust: this policy is what keeps MFA on the tenant's real admins.
  $after = @((Graph GET $CaUri).value) |
           Where-Object { $_.displayName -eq $CaPolicyName } | Select-Object -First 1
  $roleCountAfter = @($after.conditions.users.includeRoles).Count
  $nowExcluded    = @($after.conditions.users.excludeGroups | Where-Object { $_ })
  Write-Host "  ${CaPolicyName}: excludeGroups $($current.Count) -> $($nowExcluded.Count), state $($after.state)"
  if ($roleCountAfter -ne $roleCountBefore) {
    Write-Warning "  $CaPolicyName now targets $roleCountAfter admin roles, was $roleCountBefore - CHECK IT in Entra before delivering."
  }
  if ($Action -eq 'add'    -and $GroupId -notin $nowExcluded) { Write-Warning "  the exclusion did not take - attendees will hit AADSTS50079." }
  if ($Action -eq 'remove' -and $GroupId -in    $nowExcluded) { Write-Warning "  the exclusion is still in place - remove $LabGroup from $CaPolicyName by hand." }
}

Write-Host "Estate: $Estate   Tenant: $TenantId   Domain: $DomainSuffix"
Write-Host "Accounts: $(Get-LabUpn 1) .. $(Get-LabUpn $Count)"

# --- Destroy ---------------------------------------------------------------------------------------------
# Only ever this estate's attendee accounts: '<prefix><digits>.<estate>@'. The personas (no digits before
# the estate id) and another facilitator's attendees (a different estate id) can't match.
if ($Destroy) {
  $pattern = "^$([regex]::Escape($Prefix))\d+\.$([regex]::Escape($Estate))@"
  $found = @((Graph GET "users?`$select=id,userPrincipalName&`$top=999").value | Where-Object { $_.userPrincipalName -match $pattern })
  $groupId = Get-LabGroupId
  if (-not $found -and -not $groupId) { Write-Host "Nothing to remove for estate '$Estate'."; return }

  Write-Host "`nAbout to remove, for estate '$Estate':"
  Write-Host "  $($found.Count) attendee account(s), deleted and purged"
  $found | Sort-Object userPrincipalName | ForEach-Object { Write-Host "    $($_.userPrincipalName)" }
  if ($groupId) { Write-Host "  the group $LabGroup, and its exclusion from $CaPolicyName" }
  if (-not $Force) {
    $answer = Read-Host "`nType the estate id ('$Estate') to confirm"
    if ($answer -ne $Estate) { Write-Host 'Aborted - nothing was removed.'; return }
  }

  $err = $null
  foreach ($u in $found) {
    # Deleting only SOFT-deletes: the account sits in directory/deletedItems for 30 days and keeps its UPN
    # and mailNickname reserved, so the next delivery's student01 would collide. Purge it too (see the same
    # lesson in 99_teardown.ps1).
    Try-Graph DELETE "users/$($u.id)" $null ([ref]$err) | Out-Null
    if ($err) { Write-Warning "  $($u.userPrincipalName): delete failed - $err"; continue }
    Start-Sleep -Seconds 2
    Try-Graph DELETE "directory/deletedItems/$($u.id)" $null ([ref]$err) | Out-Null
    if ($err) { Write-Warning "  $($u.userPrincipalName): deleted but NOT purged - $err"; Write-Host "    purge by hand: az rest --method DELETE --url https://graph.microsoft.com/v1.0/directory/deletedItems/$($u.id)" }
    else      { Write-Host "  removed and purged $($u.userPrincipalName)" }
  }

  # The exclusion weakens the admin MFA policy, so it goes before the group does - and it only ever drops
  # THIS estate's group id, leaving any other delivery's exclusion in place.
  if ($groupId) {
    if ($NoCaExclusion) { Write-Host "Leaving $CaPolicyName alone (-NoCaExclusion)." }
    else {
      Write-Host "`nRemoving $LabGroup from $CaPolicyName..."
      try { Set-CaExclusion -GroupId $groupId -Action 'remove' }
      catch { Write-Warning "  could not update ${CaPolicyName}: $($_.Exception.Message.Split([char]10)[0])"
              Write-Warning "  REMOVE $LabGroup FROM $CaPolicyName BY HAND - until you do, the policy has a stale exclusion." }
    }
    Try-Graph DELETE "groups/$groupId" $null ([ref]$err) | Out-Null
    if ($err) { Write-Warning "  could not delete $LabGroup - $err" }
    else {
      Start-Sleep -Seconds 2
      Try-Graph DELETE "directory/deletedItems/$groupId" $null ([ref]$err) | Out-Null
      Write-Host "  removed group $LabGroup$(if ($err) { ' (soft-deleted; purge by hand)' } else { ' (purged)' })"
    }
  }
  Write-Host "`nDone. Licenses the accounts held are returned to the tenant pool."
  return
}

# --- Preflight: usage location, roles, seats --------------------------------------------------------------
if ($Count -lt 1 -or $Count -gt 99) { throw "-Count must be 1-99 (got $Count); the alias is zero-padded to two digits." }

# A license cannot be assigned to an account with no usage location, so stamp the tenant's country.
$org = (Graph GET 'organization?$select=countryLetterCode').value[0]
$usageLocation = if ($org.countryLetterCode) { $org.countryLetterCode } else { 'US' }

# Resolve each requested role to an ACTIVATED directoryRole, and track whether any of them is MFA-gated.
# These template ids are in CA-Require-MFA-Admins (00_conditional_access_baseline.ps1): hold one and a
# handed-out password stops working (AADSTS50079) unless the account sits in the excluded group.
$mfaRoleTemplates = @(
  '62e90394-69f5-4237-9190-012177145e10','9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3','c4e39bd9-1100-46d3-8c65-fb160da0071f',
  'b0f54661-2d74-4c50-afa3-1ec803f12efe','158c047a-c907-4556-b7ef-446551a6b5f7','b1be1c3e-b65d-4f19-8427-f6fa0d97feb9',
  '29232cdf-9323-42fd-ade2-1d097af3e4de','729827e3-9c14-49f7-bb1b-9608f156bbb8','966707d0-3269-4727-9be2-8c3a10f19b9d',
  '7be44c8a-adaf-4e2a-84d6-ab2649e08a13','e8611ab8-c189-46e8-94e1-60213ab1f814','194ae4cb-b126-40b2-bd5b-6091b380977d',
  'f28a1f50-f6e7-4571-818b-6a12f2af6b6c','fe930be7-5e62-47db-91af-98c3a49a38b1','11648597-926c-4cf3-9c36-bcebb0ba8dcc'
)
$templates = (Graph GET 'directoryRoleTemplates?$select=id,displayName').value
$roleTargets = @()
$needsCaExclusion = $false
foreach ($roleName in $Roles) {
  $t = $templates | Where-Object { $_.displayName -eq $roleName } | Select-Object -First 1
  if (-not $t) { throw "No directory role template named '$roleName'. Check the spelling against the Entra portal." }
  if ($t.id -in $mfaRoleTemplates) {
    $needsCaExclusion = $true
    Write-Warning "'$roleName' is tenant-wide admin and is covered by $CaPolicyName."
    if ($NoCaExclusion) {
      Write-Warning "  -NoCaExclusion was passed, so these accounts will NOT be able to sign in (AADSTS50079)."
    } else {
      Write-Warning "  These accounts get it anyway (Lab 01-01 needs it) and are excluded from that policy via $LabGroup."
      Write-Warning "  They can change or delete ANY environment in this tenant. Isolated training tenants only."
    }
  }
  # A role has no id until it is activated in the tenant; activate on first use.
  $role = $null
  try { $role = Graph GET "directoryRoles(roleTemplateId='$($t.id)')" } catch { $role = $null }
  if (-not $role.id) {
    Write-Host "Activating directory role '$roleName' in this tenant..."
    $role = Graph POST 'directoryRoles' @{ roleTemplateId = $t.id }
  }
  $roleTargets += [pscustomobject]@{ Name = $roleName; RoleId = $role.id }
  Write-Host "Role: $roleName (directoryRole $($role.id))"
}

# Seats, up front: this is the number that decides whether licensing is even possible today.
$skuPlan = @()
if (-not $NoLicense) {
  $subscribed = (Graph GET 'subscribedSkus?$select=skuId,skuPartNumber,prepaidUnits,consumedUnits').value
  foreach ($part in $LicenseSku) {
    $s = $subscribed | Where-Object { $_.skuPartNumber -eq $part } | Select-Object -First 1
    if (-not $s) { Write-Warning "SKU '$part' is not in this tenant - skipping it."; continue }
    $free = [int]$s.prepaidUnits.enabled - [int]$s.consumedUnits
    $skuPlan += [pscustomobject]@{ Part = $part; SkuId = $s.skuId; Free = $free }
    Write-Host "License: $part  $($s.consumedUnits)/$($s.prepaidUnits.enabled) used, $free free"
  }
  if ($skuPlan.Count -and -not ($skuPlan | Where-Object { $_.Free -gt 0 })) {
    Write-Warning "No seats free in: $(($skuPlan.Part) -join ', '). Accounts are still created and still do"
    Write-Warning '  every task that needs only Entra read. Free seats in M365 admin center -> Billing -> Licenses.'
  }
}

# --- Create ---------------------------------------------------------------------------------------------
# The CA-exclusion group is only needed when a requested role is MFA-gated; make it before the accounts so
# every one of them can be added as it is created.
$labGroupId = $null
if ($needsCaExclusion -and -not $NoCaExclusion) { $labGroupId = Get-LabGroupId -CreateIfMissing }

$report = @()
$provisioned = @()        # upn + object id per account, for the Dataverse role grant
foreach ($i in 1..$Count) {
  $upn   = Get-LabUpn $i
  $alias = Get-EstateAlias ("{0}{1:d2}" -f $Prefix, $i) $Estate
  $pw    = if ($UniquePasswords) { New-LabPassword } else { $InitialPassword }
  $err   = $null
  $row   = [ordered]@{ upn = $upn; password = $pw; created = ''; roles = ''; group = ''; license = '' }

  $existing = (Try-Graph GET "users?`$filter=userPrincipalName eq '$upn'&`$select=id,userPrincipalName" $null ([ref]$err)).value
  $u = $existing | Select-Object -First 1
  if ($u) {
    # Left as it is - including its password, which this script cannot read back.
    Write-Host "Exists:   $upn - leaving it as is."
    $row.created = 'existing'
    # Never print a password for an account this run did not create. The script cannot read one back, and
    # the first run may have used -UniquePasswords - claiming the shared default here would put a wrong
    # credential on the handout.
    $row.password = '(unchanged - from the run that created it)'
  } else {
    $body = @{
      accountEnabled    = $true
      displayName       = (Get-EstateDisplayName ("Lab Student {0:d2}" -f $i) $Estate)
      mailNickname      = $alias
      userPrincipalName = $upn
      usageLocation     = $usageLocation
      passwordProfile   = @{ password = $pw; forceChangePasswordNextSignIn = $false }
    }
    $u = Try-Graph POST 'users' $body ([ref]$err)
    if ($err) {
      Write-Warning "$upn - NOT created: $err"
      $row.created = "FAILED: $err"; $report += [pscustomobject]$row; continue
    }
    Write-Host "Creating $upn"
    $row.created = 'created'
  }

  # Roles. "already exist" on re-run is success, not a failure.
  $roleResults = @()
  foreach ($rt in $roleTargets) {
    Try-Graph POST "directoryRoles/$($rt.RoleId)/members/`$ref" @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$($u.id)" } ([ref]$err) | Out-Null
    if (-not $err -or $err -match 'already exist|added object references already exist') { $roleResults += $rt.Name }
    else { $roleResults += "$($rt.Name) FAILED"; Write-Warning "  $upn - role '$($rt.Name)': $err" }
  }
  $row.roles = $roleResults -join '; '

  # Group membership is what the Conditional Access exclusion actually resolves to, so a failure here
  # means that account cannot sign in. Report it per-account rather than failing the run.
  if (-not $labGroupId) { $row.group = if ($NoCaExclusion) { 'skipped (-NoCaExclusion)' } else { 'not needed' } }
  else {
    Try-Graph POST "groups/$labGroupId/members/`$ref" @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$($u.id)" } ([ref]$err) | Out-Null
    if (-not $err -or $err -match 'already exist') { $row.group = $LabGroup }
    else { $row.group = 'FAILED'; Write-Warning "  $upn - could not join $LabGroup (sign-in will fail): $err" }
  }

  # Licensing: attempt, record, never stop the run. This is the column Jim asked for.
  if ($NoLicense)            { $row.license = 'skipped (-NoLicense)' }
  elseif (-not $skuPlan)     { $row.license = 'skipped (no matching SKU)' }
  else {
    $target = $skuPlan | Where-Object { $_.Free -gt 0 } | Select-Object -First 1
    if (-not $target) { $row.license = "none free ($(($skuPlan.Part) -join '/'))" }
    else {
      Try-Graph POST "users/$($u.id)/assignLicense" @{ addLicenses = @(@{ skuId = $target.SkuId; disabledPlans = @() }); removeLicenses = @() } ([ref]$err) | Out-Null
      if ($err) { $row.license = "FAILED: $err" ; Write-Warning "  $upn - license '$($target.Part)': $err" }
      else      { $row.license = $target.Part; $target.Free -= 1 }
    }
  }
  $provisioned += [pscustomobject]@{ Upn = $upn; Id = $u.id }
  $report += [pscustomobject]$row
}

# --- Dataverse read-only role -------------------------------------------------------------------------------
# Lab 03-02 and 03-04 send attendees to read the acting identity's SECURITY ROLE inside an environment. Power
# Platform Administrator is a TENANT role and grants nothing in Dataverse, so without this the read fails with
# 0x80042f09 "has not been assigned any roles" (verified 2026-10-13). The fix is a purpose-built role with
# organization-scope READ on the few tables the exercise needs - never System Administrator, which would hand
# attendees write access to the estate they are reviewing.
$DvRoleName       = 'Lab Reviewer (read-only)'
$DvPrivilegeNames = @('prvReadUser', 'prvReadRole', 'prvReadOrganization', 'prvReadBusinessUnit', 'prvReadConnector')

function Invoke-Dv([string]$OrgUrl, [string]$Method, [string]$Path, $Body) {
  $h = @{ Authorization = "Bearer $(Get-AdminToken $OrgUrl)"; Accept = 'application/json'
          'OData-MaxVersion' = '4.0'; 'OData-Version' = '4.0' }
  $uri = "$OrgUrl/api/data/v9.2/$Path"
  if ($null -ne $Body) { Invoke-RestMethod -Method $Method -Uri $uri -Headers $h -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 10) }
  else                 { Invoke-RestMethod -Method $Method -Uri $uri -Headers $h }
}
function Get-DvFilter([string]$Set, [string]$Select, [string]$Filter) {
  "$Set`?`$select=$Select&`$filter=" + [uri]::EscapeDataString($Filter)
}

function Get-EstateDataverseEnvironments {
  $tok  = Get-AdminToken 'https://service.powerapps.com/'
  $envs = (Invoke-RestMethod -Method GET -Headers @{ Authorization = "Bearer $tok" } `
            -Uri 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2021-04-01').value
  $names = 'Halcourt-Prod', 'Claims-Test', 'Maker-Sandbox' | ForEach-Object { Get-EstateName $_ $Estate }
  @($envs | Where-Object { $_.properties.displayName -in $names } | ForEach-Object {
      [pscustomobject]@{ Name = $_.properties.displayName; Id = $_.name
                         OrgUrl = $_.properties.linkedEnvironmentMetadata.instanceApiUrl } } |
    Where-Object { $_.OrgUrl })
}

function Grant-DvReader($TargetEnv, [object[]]$Users) {
  # 1. The account must exist in the environment before it can hold a role there. This admin endpoint adds it
  #    WITHOUT a licence - Dataverse's usual userNotLicensed rule does not apply on this path (verified).
  $bapTok = Get-AdminToken 'https://service.powerapps.com/'
  foreach ($u in $Users) {
    # Already there? Adding again answers 400, so check first and keep the output quiet on a re-run.
    $have = $null
    try { $have = (Invoke-Dv $TargetEnv.OrgUrl GET (Get-DvFilter 'systemusers' 'systemuserid' "azureactivedirectoryobjectid eq $($u.Id)") $null).value | Select-Object -First 1 } catch { }
    if ($have) { continue }
    try {
      Invoke-RestMethod -Method POST -Headers @{ Authorization = "Bearer $bapTok" } -ContentType 'application/json' `
        -Uri "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/$($TargetEnv.Id)/addUser?api-version=2021-04-01" `
        -Body (@{ objectId = $u.Id } | ConvertTo-Json) | Out-Null
    } catch {
      Write-Warning "  $($TargetEnv.Name): could not add $($u.Upn) - $($_.Exception.Message.Split([char]10)[0])"
    }
  }
  # 2. The role, created once per environment and reused on re-runs.
  $esc  = $DvRoleName.Replace("'", "''")
  $role = (Invoke-Dv $TargetEnv.OrgUrl GET (Get-DvFilter 'roles' 'roleid,name' "name eq '$esc'") $null).value | Select-Object -First 1
  if (-not $role) {
    $bu = (Invoke-Dv $TargetEnv.OrgUrl GET 'businessunits?$select=businessunitid&$top=1' $null).value[0].businessunitid
    Invoke-Dv $TargetEnv.OrgUrl POST 'roles' @{ name = $DvRoleName; 'businessunitid@odata.bind' = "/businessunits($bu)" } | Out-Null
    $role = (Invoke-Dv $TargetEnv.OrgUrl GET (Get-DvFilter 'roles' 'roleid,name' "name eq '$esc'") $null).value | Select-Object -First 1
    $privs = @(foreach ($p in $DvPrivilegeNames) {
      $pv = (Invoke-Dv $TargetEnv.OrgUrl GET (Get-DvFilter 'privileges' 'privilegeid' "name eq '$p'") $null).value | Select-Object -First 1
      if ($pv) { @{ PrivilegeId = $pv.privilegeid; Depth = 'Global' } }
      else     { Write-Warning "  $($TargetEnv.Name): privilege $p not found - skipped." }
    })
    Invoke-Dv $TargetEnv.OrgUrl POST "roles($($role.roleid))/Microsoft.Dynamics.CRM.AddPrivilegesRole" @{ Privileges = $privs } | Out-Null
    Write-Host "  $($TargetEnv.Name): created '$DvRoleName' ($($privs.Count) read privileges)"
  }
  # 3. Assign it. Dataverse provisions the user record asynchronously, so give it a few seconds to appear.
  $granted = 0
  foreach ($u in $Users) {
    $su = $null
    foreach ($try in 1..6) {
      # Match on the ENTRA OBJECT ID, never the UPN. A destroy/recreate cycle leaves the old, dead
      # systemuser record behind under the same UPN, and granting the role to that one looks like it
      # worked while the live account still gets 0x80042f09.
      $su = (Invoke-Dv $TargetEnv.OrgUrl GET (Get-DvFilter 'systemusers' 'systemuserid' "azureactivedirectoryobjectid eq $($u.Id)") $null).value | Select-Object -First 1
      if ($su) { break }
      Start-Sleep -Seconds 5
    }
    if (-not $su) { Write-Warning "  $($TargetEnv.Name): no user record for $($u.Upn) yet - re-run to finish the grant."; continue }
    try {
      Invoke-Dv $TargetEnv.OrgUrl POST "systemusers($($su.systemuserid))/systemuserroles_association/`$ref" `
        @{ '@odata.id' = "$($TargetEnv.OrgUrl)/api/data/v9.2/roles($($role.roleid))" } | Out-Null
      $granted++
    } catch {
      if ("$($_.Exception.Message)" -match 'duplicate|already|Cannot insert duplicate') { $granted++ }
      else { Write-Warning "  $($TargetEnv.Name): role grant failed for $($u.Upn) - $($_.Exception.Message.Split([char]10)[0])" }
    }
  }
  Write-Host "  $($TargetEnv.Name): $granted of $($Users.Count) account(s) hold '$DvRoleName'"
}

if (-not $NoDataverseRole -and $provisioned.Count) {
  Write-Host "`nGranting '$DvRoleName' in the estate's Dataverse environments (Lab 03-02 and 03-04 need it)..."
  $dvEnvs = @(Get-EstateDataverseEnvironments)
  if (-not $dvEnvs) { Write-Warning '  no estate environments with Dataverse found - skipping.' }
  foreach ($e in $dvEnvs) { Grant-DvReader $e $provisioned }
}

# --- Conditional Access exclusion -------------------------------------------------------------------------
# Last, so every account is already in the group when the policy starts honouring it.
if ($labGroupId) {
  Write-Host "`nExcluding $LabGroup from $CaPolicyName so these accounts can sign in with a password..."
  Set-CaExclusion -GroupId $labGroupId -Action 'add'
} elseif ($needsCaExclusion) {
  Write-Warning "`nNo CA exclusion was made (-NoCaExclusion). These accounts hold an MFA-gated role and will"
  Write-Warning '  fail to sign in with AADSTS50079 until they are excluded or the role is removed.'
}

# --- Handout ---------------------------------------------------------------------------------------------
Write-Host "`n================ attendee accounts (estate '$Estate') ================"
$report | Format-Table -AutoSize -Property upn, password, created, roles, group, license | Out-String -Width 400 | Write-Host

$licensed = @($report | Where-Object { $_.license -and $_.license -notmatch '^(skipped|none free|FAILED)' })
$failed   = @($report | Where-Object { $_.created -like 'FAILED*' })
$noGroup  = @($report | Where-Object { $_.group -eq 'FAILED' })
Write-Host "Created/present: $($report.Count - $failed.Count) of $Count     Licensed: $($licensed.Count)     Not licensed: $($report.Count - $failed.Count - $licensed.Count)"
if ($failed.Count)   { Write-Warning "$($failed.Count) account(s) could not be created - see the table." }
if ($noGroup.Count)  { Write-Warning "$($noGroup.Count) account(s) are NOT in $LabGroup and will fail to sign in - see the table." }
if ($licensed.Count -lt ($report.Count - $failed.Count)) {
  Write-Host 'Unlicensed accounts still sign in and still do every task in Ex 00-02: Entra reads and the'
  Write-Host '  Power Platform admin APIs both work without a seat.'
}

if (-not $CredentialCsv) { $CredentialCsv = Join-Path (Split-Path $PSScriptRoot -Parent) "lab-users-$Estate.local.csv" }
$report | Export-Csv -Path $CredentialCsv -NoTypeInformation -UseQuotes AsNeeded
Write-Host "`nHandout written to $CredentialCsv"
Write-Warning 'That file holds PLAINTEXT passwords. It is gitignored (*.local.csv); delete it after the delivery.'
Write-Host "Tell attendees the domain ($DomainSuffix) and the estate id ($Estate) - Lab 00-01 expects both."
Write-Host "After the delivery: pwsh setup/scripts/07_provision_lab_users.ps1 -Estate $Estate -Destroy"
