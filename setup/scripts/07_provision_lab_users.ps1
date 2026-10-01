<#
FACILITATOR-ONLY. Phase 8b - Lab (attendee) accounts. Creates N native accounts in the lab tenant so you
can hand out a username and password per attendee, and removes them again after the delivery (-Destroy).

Native accounts, NOT guest invites: an attendee signs in to the lab tenant itself, so they see the estate
the way a reviewer inside Halcourt Mutual would. Nothing here touches the Phase 2 personas - the estate's
own accounts (marcus.webb, priya.nair, ...) are canon and are built by 01_provision_entra.ps1.

Runs anywhere `az` runs (Linux included): Graph over REST with az's saved sign-in, like 99_teardown.ps1.

WHAT AN ATTENDEE ACCOUNT CAN AND CANNOT DO (verified live 2026-10-01 on 0zwdt94t.onmicrosoft.com)

  Default role is Global Reader, and that is a deliberate ceiling, not a guess:

  - WORKS, unlicensed, password-only (no MFA prompt): sign-in; Entra read; Graph /users, /groups and
    signInActivity - which is every column of users-export.csv, including last_sign_in_utc.
  - DOES NOT WORK: the tenant-admin Power Platform endpoints under /scopes/admin/ (Lab 01-01 step 4).
    Global Reader gets HTTP 404 CRMRequestFailed where the build admin gets 200 - that API hides itself
    from unauthorized callers instead of returning 403. Attendees take the connections step from the
    artifact pack, or the facilitator drives it on the projector.
  - DO NOT "FIX" THAT WITH Power Platform Administrator. It is in CA-Require-MFA-Admins
    (00_conditional_access_baseline.ps1), so the account can no longer sign in with a handed-out
    password at all: AADSTS50079, "must enroll in multi-factor authentication". It would also hand
    every attendee write access to the estate they are supposed to be reviewing. This script warns if
    you ask for such a role.

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
  [string[]]$Roles           = @('Global Reader'),     # directory roles; see the header before widening
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

Write-Host "Estate: $Estate   Tenant: $TenantId   Domain: $DomainSuffix"
Write-Host "Accounts: $(Get-LabUpn 1) .. $(Get-LabUpn $Count)"

# --- Destroy ---------------------------------------------------------------------------------------------
# Only ever this estate's attendee accounts: '<prefix><digits>.<estate>@'. The personas (no digits before
# the estate id) and another facilitator's attendees (a different estate id) can't match.
if ($Destroy) {
  $pattern = "^$([regex]::Escape($Prefix))\d+\.$([regex]::Escape($Estate))@"
  $found = @((Graph GET "users?`$select=id,userPrincipalName&`$top=999").value | Where-Object { $_.userPrincipalName -match $pattern })
  if (-not $found) { Write-Host "No attendee accounts match '$Prefix<NN>.$Estate@$DomainSuffix' - nothing to remove."; return }

  Write-Host "`nAbout to delete and purge $($found.Count) attendee account(s):"
  $found | Sort-Object userPrincipalName | ForEach-Object { Write-Host "  $($_.userPrincipalName)" }
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
  Write-Host "`nDone. Licenses the accounts held are returned to the tenant pool."
  return
}

# --- Preflight: usage location, roles, seats --------------------------------------------------------------
if ($Count -lt 1 -or $Count -gt 99) { throw "-Count must be 1-99 (got $Count); the alias is zero-padded to two digits." }

# A license cannot be assigned to an account with no usage location, so stamp the tenant's country.
$org = (Graph GET 'organization?$select=countryLetterCode').value[0]
$usageLocation = if ($org.countryLetterCode) { $org.countryLetterCode } else { 'US' }

# Resolve each requested role to an ACTIVATED directoryRole, and refuse to walk into the MFA trap quietly.
# These template ids are in CA-Require-MFA-Admins (00_conditional_access_baseline.ps1): hold one and a
# handed-out password stops working (AADSTS50079), which defeats the point of this script.
$mfaRoleTemplates = @(
  '62e90394-69f5-4237-9190-012177145e10','9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3','c4e39bd9-1100-46d3-8c65-fb160da0071f',
  'b0f54661-2d74-4c50-afa3-1ec803f12efe','158c047a-c907-4556-b7ef-446551a6b5f7','b1be1c3e-b65d-4f19-8427-f6fa0d97feb9',
  '29232cdf-9323-42fd-ade2-1d097af3e4de','729827e3-9c14-49f7-bb1b-9608f156bbb8','966707d0-3269-4727-9be2-8c3a10f19b9d',
  '7be44c8a-adaf-4e2a-84d6-ab2649e08a13','e8611ab8-c189-46e8-94e1-60213ab1f814','194ae4cb-b126-40b2-bd5b-6091b380977d',
  'f28a1f50-f6e7-4571-818b-6a12f2af6b6c','fe930be7-5e62-47db-91af-98c3a49a38b1','11648597-926c-4cf3-9c36-bcebb0ba8dcc'
)
$templates = (Graph GET 'directoryRoleTemplates?$select=id,displayName').value
$roleTargets = @()
foreach ($roleName in $Roles) {
  $t = $templates | Where-Object { $_.displayName -eq $roleName } | Select-Object -First 1
  if (-not $t) { throw "No directory role template named '$roleName'. Check the spelling against the Entra portal." }
  if ($t.id -in $mfaRoleTemplates) {
    Write-Warning "'$roleName' is covered by CA-Require-MFA-Admins: these accounts will be REQUIRED to enroll in MFA"
    Write-Warning "  and a handed-out password alone will fail with AADSTS50079. See this script's header."
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
$report = @()
foreach ($i in 1..$Count) {
  $upn   = Get-LabUpn $i
  $alias = Get-EstateAlias ("{0}{1:d2}" -f $Prefix, $i) $Estate
  $pw    = if ($UniquePasswords) { New-LabPassword } else { $InitialPassword }
  $err   = $null
  $row   = [ordered]@{ upn = $upn; password = $pw; created = ''; roles = ''; license = '' }

  $existing = (Try-Graph GET "users?`$filter=userPrincipalName eq '$upn'&`$select=id,userPrincipalName" $null ([ref]$err)).value
  $u = $existing | Select-Object -First 1
  if ($u) {
    # Left as it is - including its password, which this script cannot read back.
    Write-Host "Exists:   $upn - leaving it as is."
    $row.created = 'existing'
    $row.password = if ($UniquePasswords) { '(unchanged - set on first run)' } else { $pw }
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
  $report += [pscustomobject]$row
}

# --- Handout ---------------------------------------------------------------------------------------------
Write-Host "`n================ attendee accounts (estate '$Estate') ================"
$report | Format-Table -AutoSize -Property upn, password, created, roles, license | Out-String -Width 400 | Write-Host

$licensed = @($report | Where-Object { $_.license -and $_.license -notmatch '^(skipped|none free|FAILED)' })
$failed   = @($report | Where-Object { $_.created -like 'FAILED*' })
Write-Host "Created/present: $($report.Count - $failed.Count) of $Count     Licensed: $($licensed.Count)     Not licensed: $($report.Count - $failed.Count - $licensed.Count)"
if ($failed.Count)   { Write-Warning "$($failed.Count) account(s) could not be created - see the table." }
if ($licensed.Count -lt ($report.Count - $failed.Count)) {
  Write-Host 'Unlicensed accounts still sign in and still do every task that needs only Entra read'
  Write-Host '  (users-export.csv, groups, sign-in activity). See this script header for what needs a seat.'
}

if (-not $CredentialCsv) { $CredentialCsv = Join-Path (Split-Path $PSScriptRoot -Parent) "lab-users-$Estate.local.csv" }
$report | Export-Csv -Path $CredentialCsv -NoTypeInformation -UseQuotes AsNeeded
Write-Host "`nHandout written to $CredentialCsv"
Write-Warning 'That file holds PLAINTEXT passwords. It is gitignored (*.local.csv); delete it after the delivery.'
Write-Host "Tell attendees the domain ($DomainSuffix) and the estate id ($Estate) - Lab 00-01 expects both."
Write-Host "After the delivery: pwsh setup/scripts/07_provision_lab_users.ps1 -Estate $Estate -Destroy"
