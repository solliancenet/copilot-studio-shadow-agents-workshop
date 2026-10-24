<#
FACILITATOR-ONLY. Phase 8b - Lab (attendee) accounts. Creates N native accounts in the lab tenant so you
can hand out a username and password per attendee, and removes them again after the delivery (-Destroy).

Native accounts, NOT guest invites: an attendee signs in to the lab tenant itself, so they see the estate
the way a reviewer inside Halcourt Mutual would. Nothing here touches the Phase 2 personas - the estate's
own accounts (marcus.webb, priya.nair, ...) are canon and are built by 01_provision_entra.ps1.

Runs anywhere `az` runs (Linux included): Graph over REST with az's saved sign-in, like 99_teardown.ps1.

WHY ATTENDEES GET AN ADMIN ROLE, AND WHY THEY ENROL MFA

  Lab 01-01 has attendees enumerate an environment's connections. Only the tenant-admin Power Platform
  endpoints under /scopes/admin/ can do that, and only Power Platform Administrator reaches them.
  Verified live 2026-10-13, nothing weaker works:

  - Global Reader gets HTTP 404 CRMRequestFailed where a tenant admin gets 200. Those endpoints hide
    themselves from an unauthorized caller instead of returning 403, so the attendee sees an empty estate
    rather than an error.
  - A per-environment role does not help either. The maker-facing connections API is caller-scoped: a
    maker who owns one of an environment's two connections sees exactly that one, and members who own
    none see zero.

  THE ACCOUNTS ENROL MFA AT FIRST SIGN-IN. That is deliberate, and it replaces an earlier design that
  excluded them from CA-Require-MFA-Admins so a handed-out password alone would work. That exclusion was
  the wrong half of the trade: it buys PPAC and nothing else, because Entra, Microsoft 365 and Exchange
  admin centers enforce MFA for admin portals through MICROSOFT's own policy, which tenant Conditional
  Access cannot exclude. Verified by signing a lab account into each one - all three answer "Let's keep
  your account secure" with no skip offered.

  So enrolling is strictly better: every portal the labs use comes back, and CA-Require-MFA-Admins is
  left alone instead of being weakened for the delivery. Tell attendees to bring an authenticator app;
  it costs about two minutes each, once.

  -ExcludeFromAdminMfa restores the old behaviour as a fallback for a delivery that cannot use
  authenticator apps. It gives PPAC only, and the labs that need the other portals will not work.

  THE COST OF THE ROLE ITSELF, STATED PLAINLY. An attendee account is a tenant-wide Power Platform admin.
  It can change or delete any environment in the tenant, including another facilitator's estate. Run a
  delivery in its own tenant where you can. Nothing here is appropriate outside an isolated, disposable
  training tenant.

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
  [string]$Estate            = $env:HALCOURT_ESTATE,   # this build's estate id, e.g. jsmith (_estate.ps1)
  [string]$Prefix            = 'student',              # student01.<estate>, student02.<estate>, ...
  [string]$TenantId,                                   # default: the tenant az is signed in to
  [string]$DomainSuffix,                               # default: the tenant's default verified domain
  [string]$InitialPassword,                            # one shared password; default: Get-LabPassword (_estate.ps1)
  [switch]$UniquePasswords,                            # instead: a distinct typed-by-hand password each
  [string[]]$Roles           = @('Power Platform Administrator', 'AI Reader', 'Security Reader', 'Global Reader'),
                                                       # PPA: the /scopes/admin/ connection reads of Lab 01-01.
                                                       # AI Reader: read-only; opens M365 admin center > Agents
                                                       # (Agent 365) for 01-01 s3, 02-01 s4, 04-06 s1. Without it
                                                       # that page is simply absent - verified 2026-10-17.
                                                       # Security Reader: read-only; CA policies (05-04) and
                                                       # Defender alerts / AI agents (05-07) - 2026-10-18.
                                                       # Global Reader: read-only; Purview labels, classifiers,
                                                       # DSPM for AI (05-06, 05-07) - 2026-10-18.
  [string]$LabGroup,                                   # CA-exclusion group; default Lab-Students-<estate>
  [switch]$ExcludeFromAdminMfa,                        # FALLBACK ONLY: weaken CA-Require-MFA-Admins so these
                                                       # accounts sign in password-only. Buys PPAC and nothing
                                                       # else - the other portals are gated by Microsoft, not
                                                       # by us. Default: attendees enrol MFA instead.
  [switch]$NoDataverseRole,                            # skip the per-environment Dataverse read role
  [switch]$KeepExtraPrivileges,                        # report, but do not remove, privileges on the lab role that
                                                       # the access model below does not list (default: remove)
  [string[]]$LicenseSku      = @('DEVELOPERPACK_V2_E5'),  # skuPartNumber(s), best effort, in order
  [switch]$NoLicense,                                  # skip licensing entirely
  [string]$CredentialCsv,                              # default: setup/lab-users-<estate>.local.csv
  [switch]$Destroy,                                    # delete AND purge this estate's attendee accounts
  [switch]$Force                                       # -Destroy without the confirmation prompt
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_estate.ps1')
if (-not $UniquePasswords -and -not $Destroy) { $InitialPassword = Get-LabPassword $InitialPassword }
# The access model - role name, CA policy name, privileges with the exercise step each one serves,
# companion roles, and Dataverse's unremovable baseline - lives in ONE file that this script and
# 00b_preflight.ps1 both dot-source, so the enforcer and the checker cannot disagree. It is sourced here,
# before anything that prints or uses $CaPolicyName.
. (Join-Path $PSScriptRoot '_access_model.ps1')
$Estate = Resolve-Estate $Estate

if (-not (Get-Command az -ErrorAction SilentlyContinue)) { throw 'This script needs the Azure CLI (az) - see scripts/env.sh.' }

# -TenantId names the tenant this run is FOR; every token below comes from az's active sign-in. If the
# two disagree we would provision - and, with -Destroy, permanently delete - in the signed-in tenant
# while printing the requested one. Refuse rather than act on the wrong tenant.
$activeTenant = az account show --query tenantId -o tsv
if (-not $activeTenant) { throw 'az is not signed in - run "az login" in a shell that sources scripts/env.sh.' }
if ($TenantId -and $TenantId -ne $activeTenant) {
  throw ("-TenantId is $TenantId but az is signed in to $activeTenant. This script uses az's sign-in for " +
         'every call, so it would act on the signed-in tenant. Run "az login --tenant ' + $TenantId +
         '" first, or re-run without -TenantId to use the active one.')
}
if (-not $TenantId)     { $TenantId     = $activeTenant }
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
# $CaPolicyName comes from _access_model.ps1
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
function Test-CaExclusion([string]$GroupId) {
  # Is this estate's group currently excluded from the MFA policy? Used by the DEFAULT path to spot an
  # exclusion left behind by an earlier -ExcludeFromAdminMfa run, which would otherwise keep attendees
  # on password-only sign-in while this run reports that they must enrol MFA.
  $policy = @((Graph GET $CaUri).value) |
            Where-Object { $_.displayName -eq $CaPolicyName } | Select-Object -First 1
  if (-not $policy) { return $false }
  return ($GroupId -in @($policy.conditions.users.excludeGroups | Where-Object { $_ }))
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
    # Always try the removal when the group exists, whatever flags this run was given: the group may be a
    # leftover from a delivery built with -ExcludeFromAdminMfa, and skipping it would strand a weakened
    # admin MFA policy pointing at a group that is about to be deleted.
    if ($true) {
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
# PIM-eligible roles need the kit's app-only identity: the az token lacks RoleEligibilitySchedule.* scopes.
$EligibleRoleIds = [ordered]@{}; $RetiredRoleIds = [ordered]@{}; $pimToken = $null
if (($EligibleRoles -or $RetiredEligibleRoles) -and -not $Destroy) {
  . (Join-Path $PSScriptRoot '_labapp.ps1'); Ensure-LabApp -NoBilling
  $pimToken = Get-AppToken 'https://graph.microsoft.com'
  foreach ($n in $EligibleRoles) {
    $t = $templates | Where-Object { $_.displayName -eq $n } | Select-Object -First 1
    if ($t) { $EligibleRoleIds[$n] = $t.id } else { Write-Warning "No role template '$n' - not made eligible" }
  }
  foreach ($n in $RetiredEligibleRoles) {
    $t = $templates | Where-Object { $_.displayName -eq $n } | Select-Object -First 1
    if ($t) { $RetiredRoleIds[$n] = $t.id }
  }
}
# A permission granted moments ago (Ensure-LabApp on a fresh tenant) can take minutes to reach the token
# service: retry a 403 rather than fail every account.
function Invoke-Pim([hashtable]$Body) {
  for ($i = 0; ; $i++) {
    try {
      return Invoke-RestMethod -Method POST -Uri 'https://graph.microsoft.com/v1.0/roleManagement/directory/roleEligibilityScheduleRequests' `
        -Headers @{ Authorization = "Bearer $script:pimToken" } -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 5)
    } catch {
      if ($i -ge 5 -or "$_" -notmatch '403|Forbidden|Authorization_RequestDenied') { throw }
      Start-Sleep 60; $script:pimToken = Get-AppToken 'https://graph.microsoft.com'
    }
  }
}
$roleTargets = @()
$needsCaExclusion = $false
foreach ($roleName in $Roles) {
  $t = $templates | Where-Object { $_.displayName -eq $roleName } | Select-Object -First 1
  if (-not $t) { throw "No directory role template named '$roleName'. Check the spelling against the Entra portal." }
  if ($t.id -in $mfaRoleTemplates) {
    $needsCaExclusion = $true
    Write-Warning "'$roleName' is tenant-wide admin: these accounts can change or delete ANY environment in"
    Write-Warning '  this tenant. Isolated training tenants only.'
    if ($ExcludeFromAdminMfa) {
      Write-Warning "  -ExcludeFromAdminMfa: weakening $CaPolicyName so they sign in password-only. That buys"
      Write-Warning '  the PPAC shell only - its data calls, Copilot Studio, Entra, M365 and Exchange still demand MFA (AADSTS50076).'
    } else {
      Write-Host   '  Attendees enrol MFA at first sign-in; no Conditional Access policy is changed.'
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

# The handout path is resolved up front, not at write time, so a re-run can read back the passwords
# the FIRST run recorded. Without this, re-running to fix roles or privileges rewrote the password
# column as '(unchanged ...)' and destroyed the only copy of a working credential.
if (-not $CredentialCsv) { $CredentialCsv = Join-Path (Split-Path $PSScriptRoot -Parent) "lab-users-$Estate.local.csv" }
# The two strings this script itself may have written into the password column. Match them EXACTLY,
# never by a leading '(' - a password supplied through -InitialPassword is allowed to start with one,
# and a prefix test would drop it on the next run and replace it with the unknown marker.
$PwUnchangedMarker = '(unchanged - from the run that created it)'   # written by older versions
$PwUnknownMarker   = '(unknown - set by an earlier run; reset it or use -Destroy and recreate)'
$pwMarkers = @($PwUnchangedMarker, $PwUnknownMarker)
$priorPw = @{}
if (Test-Path $CredentialCsv) {
  foreach ($r in (Import-Csv $CredentialCsv)) {
    if ($r.upn -and $r.password -and $pwMarkers -notcontains $r.password) { $priorPw[$r.upn] = $r.password }
  }
  if ($priorPw.Count) { Write-Host "Handout: carrying forward $($priorPw.Count) password(s) already recorded in $(Split-Path $CredentialCsv -Leaf)" }
}

# Seats, up front: this is the number that decides whether licensing is even possible today.
$skuPlan = @()
if (-not $NoLicense) {
  # Best effort: a licensing endpoint that is unavailable must not stop accounts being created. The
  # accounts still do every task that needs only Entra read and the admin APIs.
  $subscribed = @()
  try { $subscribed = (Graph GET 'subscribedSkus?$select=skuId,skuPartNumber,prepaidUnits,consumedUnits').value }
  catch {
    Write-Warning "  could not read tenant SKUs ($($_.Exception.Message.Split([char]10)[0])) - continuing without licensing."
    $subscribed = @()
  }
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
if ($needsCaExclusion -and $ExcludeFromAdminMfa) { $labGroupId = Get-LabGroupId -CreateIfMissing }

# Resolve the agents' chat-audience groups once. They are estate groups built in Phase 2; missing ones are
# reported, not created - an audience group this script made would not be the one the agents point at.
$audienceGroupIds = @(foreach ($a in $AudienceGroups) {
  $gn = Get-EstateName $a $Estate
  $g  = @((Graph GET "groups?`$filter=displayName eq '$gn'&`$select=id").value) | Select-Object -First 1
  if ($g) { [pscustomobject]@{ Name = $gn; Id = $g.id } } else { Write-Warning "Audience group $gn not found (Phase 2) - attendees will not be able to chat with the agents." }
})

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
    # Never INVENT a password for an account this run did not create - the first run may have used
    # -UniquePasswords, so claiming the shared default would put a wrong credential on the handout.
    # But if the previous handout recorded one, carry it forward rather than overwriting it with a
    # placeholder: that placeholder is what a re-run used to leave behind, wiping the real password.
    $row.password = if ($priorPw.ContainsKey($upn)) { $priorPw[$upn] } else { $PwUnknownMarker }
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
  # PIM-eligible Exercise 05 roles (activated by the attendee, time-boxed). An existing eligibility comes back
  # as RoleAssignmentExists - success on a re-run.
  foreach ($er in $EligibleRoleIds.GetEnumerator()) {
    try {
      $b = @{ action = 'adminAssign'; principalId = $u.id; roleDefinitionId = $er.Value; directoryScopeId = '/'
              justification = 'Halcourt lab: Exercise 05 only, activated on demand'
              scheduleInfo = @{ startDateTime = (Get-Date).ToUniversalTime().ToString('o'); expiration = @{ type = 'noExpiration' } } }
      Invoke-Pim $b | Out-Null
      $roleResults += "$($er.Key) (eligible)"
    } catch {
      if ("$_" -match 'RoleAssignmentExists|already exists') { $roleResults += "$($er.Key) (eligible)" }
      else { $roleResults += "$($er.Key) (eligible) FAILED"; Write-Warning "  $upn - eligibility '$($er.Key)': $($_.Exception.Message.Split([char]10)[0])" }
    }
  }
  foreach ($er in $RetiredRoleIds.GetEnumerator()) {
    try {
      Invoke-Pim @{ action = 'adminRemove'; principalId = $u.id; roleDefinitionId = $er.Value; directoryScopeId = '/'
                    justification = 'Halcourt lab: role retired from the access model' } | Out-Null
      $roleResults += "$($er.Key) (eligibility removed)"
    } catch {
      if ("$_" -notmatch 'RoleAssignmentDoesNotExist|does not exist') { Write-Warning "  $upn - removing eligibility '$($er.Key)': $($_.Exception.Message.Split([char]10)[0])" }
    }
  }
  $row.roles = $roleResults -join '; '

  # Group membership is what the Conditional Access exclusion actually resolves to, so a failure here
  # means that account cannot sign in. Report it per-account rather than failing the run.
  $joined = @()
  if ($labGroupId) {
    Try-Graph POST "groups/$labGroupId/members/`$ref" @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$($u.id)" } ([ref]$err) | Out-Null
    if (-not $err -or $err -match 'already exist') { $joined += $LabGroup }
    else { $joined += "$LabGroup FAILED"; Write-Warning "  $upn - could not join $LabGroup (sign-in will fail): $err" }
  }
  # The agents' chat audience (see $AudienceGroups in _access_model.ps1): without it every attendee is
  # refused by the agents Exercise 04 asks them to drive.
  foreach ($ag in $audienceGroupIds) {
    Try-Graph POST "groups/$($ag.Id)/members/`$ref" @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$($u.id)" } ([ref]$err) | Out-Null
    if (-not $err -or $err -match 'already exist') { $joined += $ag.Name }
    else { $joined += "$($ag.Name) FAILED"; Write-Warning "  $upn - could not join $($ag.Name) (cannot chat with the agents): $err" }
  }
  $row.group = if ($joined.Count) { $joined -join '; ' } else { 'none' }

  # Licensing: attempt, record, never stop the run. This is the column Jim asked for.
  if ($NoLicense)            { $row.license = 'skipped (-NoLicense)' }
  elseif (-not $skuPlan)     { $row.license = 'skipped (no matching SKU)' }
  else {
    # An account that already holds one of the requested SKUs needs nothing: re-assigning it would
    # report a seat spent that the tenant never released, and on a re-run that miscount can starve a
    # later NEW account of the seat it actually needs.
    $held = @()
    try { $held = @((Graph GET "users/$($u.id)?`$select=assignedLicenses").assignedLicenses.skuId) } catch { $held = @() }
    $already = $skuPlan | Where-Object { $held -contains $_.SkuId } | Select-Object -First 1
    if ($already) {
      $row.license = "$($already.Part) (already held)"
    } else {
      $target = $skuPlan | Where-Object { $_.Free -gt 0 } | Select-Object -First 1
      if (-not $target) { $row.license = "none free ($(($skuPlan.Part) -join '/'))" }
      else {
        Try-Graph POST "users/$($u.id)/assignLicense" @{ addLicenses = @(@{ skuId = $target.SkuId; disabledPlans = @() }); removeLicenses = @() } ([ref]$err) | Out-Null
        if ($err) { $row.license = "FAILED: $err" ; Write-Warning "  $upn - license '$($target.Part)': $err" }
        else      { $row.license = $target.Part; $target.Free -= 1 }
      }
    }
  }
  $provisioned += [pscustomobject]@{ Upn = $upn; Id = $u.id }
  $report += [pscustomobject]$row
}

# Save the credentials NOW, before anything fallible runs. With -UniquePasswords these passwords exist
# only in memory and cannot be read back from Entra, so a throw in the Dataverse grants below used to
# lose them for good and leave accounts nobody could sign in to. The handout is written again at the
# end once the role results are known; this first write is the safety net.
if ($report.Count) {
  try {
    $report | Export-Csv -Path $CredentialCsv -NoTypeInformation -UseQuotes AsNeeded
    Write-Host "`nCredentials saved to $CredentialCsv before the Dataverse grants."
  } catch {
    Write-Warning "Could not write the handout to ${CredentialCsv}: $($_.Exception.Message.Split([char]10)[0])"
    Write-Warning '  The passwords below are the only copy - record them before continuing.'
    $report | Format-Table -AutoSize -Property upn, password | Out-String -Width 200 | Write-Host
  }
}

# --- Graph Explorer: tenant-wide consent for the lab's read queries ------------------------------------------
# $GraphExplorerScopes (_access_model.ps1) says which steps need it. An AllPrincipals grant; the app's
# service principal appears on first sign-in, so create it if nobody has signed in yet.
# Never fatal: the credentials are already saved and the Dataverse grants below must still run.
try {
  $geSp = @((Graph GET "servicePrincipals?`$filter=appId eq '$GraphExplorerAppId'&`$select=id").value) | Select-Object -First 1
  if (-not $geSp) { $geSp = Graph POST 'servicePrincipals' @{ appId = $GraphExplorerAppId } }
  $msGraph = @((Graph GET "servicePrincipals?`$filter=appId eq '00000003-0000-0000-c000-000000000000'&`$select=id").value)[0]
  $want = $GraphExplorerScopes -join ' '
  $grant = @((Graph GET "oauth2PermissionGrants?`$filter=clientId eq '$($geSp.id)' and consentType eq 'AllPrincipals' and resourceId eq '$($msGraph.id)'").value) | Select-Object -First 1
  if (-not $grant) {
    Graph POST 'oauth2PermissionGrants' @{ clientId = $geSp.id; consentType = 'AllPrincipals'; resourceId = $msGraph.id; scope = $want } | Out-Null
    Write-Host "Graph Explorer: consented for all users ($want)"
  } else {
    $missing = @($GraphExplorerScopes | Where-Object { $_ -notin ($grant.scope -split ' ') })
    if ($missing) {
      Graph PATCH "oauth2PermissionGrants/$($grant.id)" @{ scope = ((@($grant.scope -split ' ' | Where-Object { $_ }) + $missing) -join ' ') } | Out-Null
      Write-Host "Graph Explorer: consent extended with $($missing -join ' ')"
    } else { Write-Host 'Graph Explorer: consent already in place' }
  }
} catch {
  Write-Warning "Graph Explorer consent failed - 01-02, 02-01 and 06-01's Graph Explorer queries will be refused: $($_.Exception.Message.Split([char]10)[0]). Re-run 07."
}

# --- Dataverse read-only role -------------------------------------------------------------------------------
# Lab 03-02 and 03-04 send attendees to read the acting identity's SECURITY ROLE inside an environment. Power
# Platform Administrator is a TENANT role and grants nothing in Dataverse, so without this the read fails with
# 0x80042f09 "has not been assigned any roles" (verified 2026-10-13). The fix is a purpose-built role with
# organization-scope READ on the few tables the exercise needs - never System Administrator, which would hand
# attendees write access to the estate they are reviewing.
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
  # Plus the tenant's default environment, which every estate shares: Expense Helper and Onboarding Guide
  # live there, and Lab 04-04 KT02 s6 / 04-06 KT02 open them in Copilot Studio. Without the role an
  # attendee's agent list there is simply empty (verified 2026-10-17).
  @($envs | Where-Object { $_.properties.displayName -in $names -or $_.properties.isDefault } | ForEach-Object {
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
    # A 400 here is NOT "already there" (checked just above): it is an account the environment can't see yet.
    # Right after this run creates it, addUser answered 400 in Maker-Sandbox for 17 of 23 estates on
    # 2026-10-23, and a re-run minutes later added every one. So retry for two minutes before giving up.
    foreach ($try in 1..7) {   # six 20 s waits between seven attempts: two minutes
      try {
        Invoke-RestMethod -Method POST -Headers @{ Authorization = "Bearer $bapTok" } -ContentType 'application/json' `
          -Uri "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/$($TargetEnv.Id)/addUser?api-version=2021-04-01" `
          -Body (@{ objectId = $u.Id } | ConvertTo-Json) | Out-Null
        break
      } catch {
        $code = try { [int]$_.Exception.Response.StatusCode } catch { 0 }
        if ($code -eq 400 -and $try -lt 7) { Start-Sleep -Seconds 20; continue }
        Write-Warning "  $($TargetEnv.Name): could not add $($u.Upn) - $($_.Exception.Message.Split([char]10)[0])"
        break
      }
    }
  }
  # 2. The role is created once per environment, but its PRIVILEGES are reconciled on EVERY run.
  #    They used to be granted only in the branch that created the role, so adding a name to
  #    $DvPrivilegeNames silently did nothing in any environment that already had the role - and the
  #    script still printed a success line. That is how the live role drifted to 14 privileges while
  #    this list held 5.
  $esc  = $DvRoleName.Replace("'", "''")
  $role = (Invoke-Dv $TargetEnv.OrgUrl GET (Get-DvFilter 'roles' 'roleid,name' "name eq '$esc'") $null).value | Select-Object -First 1
  if (-not $role) {
    $bu = (Invoke-Dv $TargetEnv.OrgUrl GET 'businessunits?$select=businessunitid&$top=1' $null).value[0].businessunitid
    Invoke-Dv $TargetEnv.OrgUrl POST 'roles' @{ name = $DvRoleName; 'businessunitid@odata.bind' = "/businessunits($bu)" } | Out-Null
    $role = (Invoke-Dv $TargetEnv.OrgUrl GET (Get-DvFilter 'roles' 'roleid,name' "name eq '$esc'") $null).value | Select-Object -First 1
    Write-Host "  $($TargetEnv.Name): created '$DvRoleName'"
  }
  $held = @{}
  try {
    $rp = Invoke-Dv $TargetEnv.OrgUrl GET "RetrieveRolePrivilegesRole(RoleId=$($role.roleid))" $null
    foreach ($h in $rp.RolePrivileges) { $held["$($h.PrivilegeId)"] = $true }
  } catch {
    Write-Warning "  $($TargetEnv.Name): could not read current privileges - $($_.Exception.Message.Split([char]10)[0])"
  }
  $wantIds = @{}                                   # privilegeid -> name, for every privilege the model lists
  $privs = @(foreach ($p in (Get-DvPrivilegeNamesFor $TargetEnv.Name $Estate)) {
    $pv = (Invoke-Dv $TargetEnv.OrgUrl GET (Get-DvFilter 'privileges' 'privilegeid' "name eq '$p'") $null).value | Select-Object -First 1
    if (-not $pv) { Write-Warning "  $($TargetEnv.Name): privilege $p not found - skipped."; continue }
    $wantIds["$($pv.privilegeid)"] = $p
    if (-not $held["$($pv.privilegeid)"]) { @{ PrivilegeId = $pv.privilegeid; Depth = 'Global' } }
  })
  if ($privs.Count) {
    Invoke-Dv $TargetEnv.OrgUrl POST "roles($($role.roleid))/Microsoft.Dynamics.CRM.AddPrivilegesRole" @{ Privileges = $privs } | Out-Null
    Write-Host "  $($TargetEnv.Name): added $($privs.Count) privilege(s) to '$DvRoleName'"
  } else {
    Write-Host "  $($TargetEnv.Name): '$DvRoleName' already holds every listed privilege"
  }
  # 2b. DRIFT. Anything on the role that the access model does not name was not put there by this script,
  #     and a greenfield build will not have it - so the estate you tested is not the estate you deliver.
  #     The live role had grown SharePoint WRITE privileges this way, under a name ending "(read-only)".
  #     Report every extra by name, and remove it unless -KeepExtraPrivileges says otherwise.
  $extraIds = @($held.Keys | Where-Object { -not $wantIds[$_] })
  if ($extraIds.Count) {
    $extraNames = @()
    for ($i = 0; $i -lt $extraIds.Count; $i += 30) {
      $ids = $extraIds[$i..([math]::Min($i + 29, $extraIds.Count - 1))]
      $f   = ($ids | ForEach-Object { "privilegeid eq $_" }) -join ' or '
      try { $extraNames += @((Invoke-Dv $TargetEnv.OrgUrl GET (Get-DvFilter 'privileges' 'name,privilegeid' $f) $null).value) } catch { }
    }
    # Dataverse stamps a baseline set onto EVERY custom role and refuses (400) to remove it. Those are
    # not drift and are not this script's doing; report them once and move on.
    $baseline = @($extraNames | Where-Object { $_.name -in $DvBaselinePrivileges })
    $drift    = @($extraNames | Where-Object { $_.name -notin $DvBaselinePrivileges })
    if ($baseline.Count) { Write-Host "  $($TargetEnv.Name): $($baseline.Count) Dataverse baseline privilege(s) on the role (every custom role gets these - not drift)" }
    if ($drift.Count) {
      $label = ($drift | ForEach-Object { $_.name } | Sort-Object) -join ', '
      if ($KeepExtraPrivileges) {
        Write-Warning "  $($TargetEnv.Name): '$DvRoleName' holds $($drift.Count) privilege(s) the access model does not list - KEPT (-KeepExtraPrivileges): $label"
      } else {
        $removed = 0; $refused = @()
        foreach ($d in $drift) {
          try { Invoke-Dv $TargetEnv.OrgUrl POST "roles($($role.roleid))/Microsoft.Dynamics.CRM.RemovePrivilegeRole" @{ PrivilegeId = $d.privilegeid } | Out-Null; $removed++ }
          catch { $refused += $d.name }
        }
        if ($removed)       { Write-Host "  $($TargetEnv.Name): removed $removed drifted privilege(s) from '$DvRoleName'" }
        if ($refused.Count) { Write-Warning "  $($TargetEnv.Name): Dataverse refused to remove: $($refused -join ', ') - if these appear on every fresh build, add them to `$DvBaselinePrivileges in _access_model.ps1" }
      }
    }
  }
  # Companion built-in roles, resolved once per environment.
  $companions = @(foreach ($cn in $DvCompanionRoles) {
    $cr = (Invoke-Dv $TargetEnv.OrgUrl GET (Get-DvFilter 'roles' 'roleid,name' "name eq '$cn'") $null).value | Select-Object -First 1
    if ($cr) { $cr } else { Write-Warning "  $($TargetEnv.Name): built-in role '$cn' not found - Copilot Studio agent pages will not open." }
  })
  # 3. Assign it. Dataverse provisions the user record asynchronously, so give it up to two minutes to appear.
  $granted = 0
  foreach ($u in $Users) {
    $su = $null
    foreach ($try in 1..24) {
      # Match on the ENTRA OBJECT ID, never the UPN. A destroy/recreate cycle leaves the old, dead
      # systemuser record behind under the same UPN, and granting the role to that one looks like it
      # worked while the live account still gets 0x80042f09.
      $su = (Invoke-Dv $TargetEnv.OrgUrl GET (Get-DvFilter 'systemusers' 'systemuserid' "azureactivedirectoryobjectid eq $($u.Id)") $null).value | Select-Object -First 1
      if ($su) { break }
      Start-Sleep -Seconds 5
    }
    if (-not $su) { Write-Warning "  $($TargetEnv.Name): no user record for $($u.Upn) yet - re-run to finish the grant."; continue }
    foreach ($r in @($role) + $companions) {
      try {
        Invoke-Dv $TargetEnv.OrgUrl POST "systemusers($($su.systemuserid))/systemuserroles_association/`$ref" `
          @{ '@odata.id' = "$($TargetEnv.OrgUrl)/api/data/v9.2/roles($($r.roleid))" } | Out-Null
        if ($r.roleid -eq $role.roleid) { $granted++ }
      } catch {
        if ("$($_.Exception.Message)" -match 'duplicate|already|Cannot insert duplicate') { if ($r.roleid -eq $role.roleid) { $granted++ } }
        else { Write-Warning "  $($TargetEnv.Name): '$($r.name)' grant failed for $($u.Upn) - $($_.Exception.Message.Split([char]10)[0])" }
      }
    }
  }
  $with = if ($companions.Count) { ' + ' + (($companions | ForEach-Object { "'$($_.name)'" }) -join ', ') } else { '' }
  Write-Host "  $($TargetEnv.Name): $granted of $($Users.Count) account(s) hold '$DvRoleName'$with"
}

if (-not $NoDataverseRole -and $provisioned.Count) {
  Write-Host "`nReconciling '$DvRoleName' (+ $($DvCompanionRoles -join ', ')) in the estate's Dataverse environments to the access model..."
  $dvEnvs = @(Get-EstateDataverseEnvironments)
  if (-not $dvEnvs) { Write-Warning '  no estate environments with Dataverse found - skipping.' }
  foreach ($e in $dvEnvs) {
    # Per environment, never fatal: the build admin may hold no Dataverse role in one of them (see
    # 06_provision_agents.ps1 on Maker-Sandbox), and that must not cost the whole run.
    try { Grant-DvReader $e $provisioned }
    catch { Write-Warning "  $($e.Name): role grant skipped - $($_.Exception.Message.Split([char]10)[0])" }
  }
}

# --- Conditional Access exclusion -------------------------------------------------------------------------
# Last, so every account is already in the group when the policy starts honouring it.
if ($labGroupId) {
  Write-Host "`nExcluding $LabGroup from $CaPolicyName so these accounts can sign in with a password..."
  Set-CaExclusion -GroupId $labGroupId -Action 'add'
} elseif ($needsCaExclusion) {
  # A PREVIOUS run with -ExcludeFromAdminMfa leaves the group and the policy exclusion in place. The
  # default path used to ignore that and still announce that attendees will be asked to register MFA -
  # so a delivery could run password-only without anyone noticing. Reconcile it instead of asserting it.
  $staleGroupId = Get-LabGroupId
  $staleExcluded = $false
  if ($staleGroupId) {
    try { $staleExcluded = Test-CaExclusion -GroupId $staleGroupId } catch { $staleExcluded = $false }
  }
  if ($staleExcluded) {
    Write-Warning "`n$LabGroup is STILL excluded from $CaPolicyName, left by an earlier run with -ExcludeFromAdminMfa."
    Write-Warning '  These accounts can sign in password-only, which is NOT what this run configured.'
    Write-Host   "  Removing the exclusion so the default (attendees enrol MFA) actually holds..."
    try {
      Set-CaExclusion -GroupId $staleGroupId -Action 'remove'
      Write-Host "  $LabGroup is no longer excluded from $CaPolicyName."
    } catch {
      Write-Warning "  Could not remove it: $($_.Exception.Message.Split([char]10)[0])"
      Write-Warning "  Remove $LabGroup from $CaPolicyName by hand before the delivery."
    }
  }
  Write-Host "`nNo Conditional Access policy was weakened. These accounts hold a tenant admin role, so Entra"
  Write-Host '  will ask each attendee to register MFA on their FIRST sign-in - that is expected and is the'
  Write-Host '  point: it is what gives them the Entra, M365 and Exchange admin centers the labs use. Tell'
  Write-Host '  them to bring an authenticator app; it takes about two minutes each.'
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

$report | Export-Csv -Path $CredentialCsv -NoTypeInformation -UseQuotes AsNeeded
Write-Host "`nHandout written to $CredentialCsv"
Write-Warning 'That file holds PLAINTEXT passwords. It is gitignored (*.local.csv); delete it after the delivery.'
Write-Host "Tell attendees the domain ($DomainSuffix) and the estate id ($Estate) - Lab 00-01 expects both."
Write-Host "After the delivery: pwsh setup/scripts/07_provision_lab_users.ps1 -Estate $Estate -Destroy"
