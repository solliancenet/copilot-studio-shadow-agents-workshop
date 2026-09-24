<#
FACILITATOR-ONLY. Phase 0 - replace security defaults with the Conditional Access baseline.

Turns security defaults OFF and creates the two baseline Conditional Access policies from AGENTS.md:
  CA-Require-MFA-Admins  - MFA for the admin roles
  CA-Block-Legacy-Auth   - block legacy authentication (Exchange ActiveSync and other legacy clients)

Why (setup/RUNBOOK.md -> Phase 0, step 4): security defaults block device-code sign-in (AADSTS530035),
which the dev container and scripts 01/03/05/99 depend on; they push every persona account into MFA
registration; and Conditional Access - which Module 5 tests - can't be enabled while they are on. This
baseline keeps the two protections that matter for a lab tenant: MFA for admins and no legacy auth.

It deliberately creates NO policy targeting workload/agent identities (a Module 5 finding) and NO policy
blocking device-code flow.

Run as the lab global admin. The first time, security defaults are still on and block device codes, so run
it from the host or the Windows build VM with the default browser sign-in. Safe to re-run: it skips
policies that already exist (by name). If creating a policy fails, it deletes the ones it created and
turns security defaults back on, so admins are never left without MFA.

Requires: Microsoft.Graph.Authentication (Connect-MgGraph, Invoke-MgGraphRequest).
#>
param(
  [Parameter(Mandatory = $true)][string]$TenantId,   # lab tenant id or <name>.onmicrosoft.com
  [switch]$UseDeviceCode                             # only once security defaults are already off
)
$ErrorActionPreference = 'Stop'

$connectArgs = @{ TenantId = $TenantId; Scopes = @('Policy.ReadWrite.ConditionalAccess', 'Policy.Read.All'); NoWelcome = $true }
if ($UseDeviceCode) { $connectArgs['UseDeviceCode'] = $true }
Connect-MgGraph @connectArgs
if (-not (Get-MgContext)) { throw 'Connect-MgGraph did not establish a session.' }

$graph = 'https://graph.microsoft.com/v1.0'
$caUri = "$graph/identity/conditionalAccess/policies"
$sdUri = "$graph/policies/identitySecurityDefaultsEnforcementPolicy"
function Send-Json([string]$Method, [string]$Uri, $Body) {
  Invoke-MgGraphRequest -Method $Method -Uri $Uri -Body ($Body | ConvertTo-Json -Depth 10) -ContentType 'application/json'
}
# Turning security defaults off takes a little while to reach Conditional Access: until it does, turning a
# policy on fails with "Security Defaults is enabled in the tenant". Retry that error for up to 3 minutes.
function Send-JsonOnceDefaultsOff([string]$Method, [string]$Uri, $Body) {
  $deadline = (Get-Date).AddMinutes(3)
  while ($true) {
    try { return Send-Json $Method $Uri $Body }
    catch {
      if ("$($_.Exception.Message) $($_.ErrorDetails.Message)" -notmatch 'Security Defaults is enabled' -or (Get-Date) -gt $deadline) { throw }
      Write-Host '  security defaults change still propagating - retrying in 10 s...'
      Start-Sleep -Seconds 10
    }
  }
}

# Directory role template ids - the same in every tenant. Microsoft's "Require multifactor authentication
# for admins" template roles, plus Power Platform Administrator (this estate's platform admin role).
$adminRoles = [ordered]@{
  'Global Administrator'                    = '62e90394-69f5-4237-9190-012177145e10'
  'Application Administrator'               = '9b895d92-2cd3-44c7-9d02-a6ac2d5ea5c3'
  'Authentication Administrator'            = 'c4e39bd9-1100-46d3-8c65-fb160da0071f'
  'Billing Administrator'                   = 'b0f54661-2d74-4c50-afa3-1ec803f12efe'
  'Cloud Application Administrator'         = '158c047a-c907-4556-b7ef-446551a6b5f7'
  'Conditional Access Administrator'        = 'b1be1c3e-b65d-4f19-8427-f6fa0d97feb9'
  'Exchange Administrator'                  = '29232cdf-9323-42fd-ade2-1d097af3e4de'
  'Helpdesk Administrator'                  = '729827e3-9c14-49f7-bb1b-9608f156bbb8'
  'Password Administrator'                  = '966707d0-3269-4727-9be2-8c3a10f19b9d'
  'Privileged Authentication Administrator' = '7be44c8a-adaf-4e2a-84d6-ab2649e08a13'
  'Privileged Role Administrator'           = 'e8611ab8-c189-46e8-94e1-60213ab1f814'
  'Security Administrator'                  = '194ae4cb-b126-40b2-bd5b-6091b380977d'
  'SharePoint Administrator'                = 'f28a1f50-f6e7-4571-818b-6a12f2af6b6c'
  'User Administrator'                      = 'fe930be7-5e62-47db-91af-98c3a49a38b1'
  'Power Platform Administrator'            = '11648597-926c-4cf3-9c36-bcebb0ba8dcc'
}

$baseline = @(
  @{
    displayName   = 'CA-Require-MFA-Admins'
    state         = 'enabled'
    conditions    = @{
      users          = @{ includeRoles = @($adminRoles.Values) }
      applications   = @{ includeApplications = @('All') }
      clientAppTypes = @('all')
    }
    grantControls = @{ operator = 'OR'; builtInControls = @('mfa') }
  }
  @{
    displayName   = 'CA-Block-Legacy-Auth'
    state         = 'enabled'
    conditions    = @{
      users          = @{ includeUsers = @('All') }
      applications   = @{ includeApplications = @('All') }
      clientAppTypes = @('exchangeActiveSync', 'other')
    }
    grantControls = @{ operator = 'OR'; builtInControls = @('block') }
  }
)

$existing = @((Invoke-MgGraphRequest -Method GET -Uri $caUri).value)
$toCreate = @($baseline | Where-Object { $_.displayName -notin $existing.displayName })
# A baseline policy that already exists keeps its settings, but it must be on.
$toEnable = @($existing | Where-Object { $_.displayName -in $baseline.displayName -and $_.state -ne 'enabled' })
$existing | Where-Object { $_.displayName -in $baseline.displayName -and $_.state -eq 'enabled' } |
  ForEach-Object { Write-Host "$($_.displayName) already exists and is on - leaving it as is." }

$sdWasOn = [bool](Invoke-MgGraphRequest -Method GET -Uri $sdUri).isEnabled
if ($sdWasOn) {
  Write-Host 'Turning security defaults off...'
  Send-Json PATCH $sdUri @{ isEnabled = $false } | Out-Null
}

$created = @(); $enabled = @()
try {
  foreach ($p in $toCreate) {
    Write-Host "Creating $($p.displayName)..."
    $created += (Send-JsonOnceDefaultsOff POST $caUri $p).id
  }
  foreach ($p in $toEnable) {
    Write-Host "Turning on existing $($p.displayName) (was $($p.state))..."
    Send-JsonOnceDefaultsOff PATCH "$caUri/$($p.id)" @{ state = 'enabled' } | Out-Null
    $enabled += $p
  }
} catch {
  Write-Warning "Creating the baseline failed: $($_.Exception.Message)"
  foreach ($id in $created) { Invoke-MgGraphRequest -Method DELETE -Uri "$caUri/$id" | Out-Null }
  foreach ($p in $enabled) { Send-Json PATCH "$caUri/$($p.id)" @{ state = $p.state } | Out-Null }
  if ($sdWasOn) {
    Write-Warning 'Rolled back: undid the policy changes made here and turned security defaults back on.'
    Send-Json PATCH $sdUri @{ isEnabled = $true } | Out-Null
  }
  throw
}

Write-Host ''
Write-Host "Security defaults on: $([bool](Invoke-MgGraphRequest -Method GET -Uri $sdUri).isEnabled)"
# New policies take a few seconds to show up in the list; wait up to a minute for both.
$deadline = (Get-Date).AddMinutes(1)
do {
  $all = @((Invoke-MgGraphRequest -Method GET -Uri $caUri).value)
  $missing = @($baseline.displayName | Where-Object { $_ -notin $all.displayName })
  if ($missing) { Start-Sleep -Seconds 5 }
} while ($missing -and (Get-Date) -lt $deadline)
if ($missing) { Write-Warning "Not listed yet: $($missing -join ', ') - check Entra admin center -> Conditional Access in a few minutes." }
Write-Host 'Conditional Access policies:'
foreach ($p in $all) {
  Write-Host ("  {0,-50} {1}" -f $p.displayName, $p.state)
  # Microsoft can add its own managed policies later; one that restricts authentication flows would
  # block device codes again.
  if ($p.conditions.authenticationFlows -and $p.state -ne 'disabled') {
    Write-Warning "  '$($p.displayName)' restricts authentication flows - exclude the build admin, or device-code sign-in breaks again."
  }
}
Write-Host 'Phase 0 CA baseline complete. Do not add a policy targeting workload/agent identities - Module 5 finds that gap.'
