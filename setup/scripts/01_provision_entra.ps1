<#
FACILITATOR-ONLY. Phase 2 — Entra identities & personas for the Halcourt Mutual demo estate.
Creates the personas, the service account, and the groups from AGENTS.md, and prints the command for the
shared mailbox (Exchange Online creates that, not Graph).

Tom Dean is the departed owner, and he stays ENABLED. Disabling him would kill his connections (Entra
refuses a disabled user's token refresh - AADSTS50057), and the orphan is precisely a leaver whose account
nobody shut down. After his shared connections exist (Phase 6), run this script again with
-MarkDepartedOwner: it stamps his Entra leave date (employeeLeaveDateTime), the record that says he has
gone, and leaves the account and its connections live.

Requires: Microsoft.Graph (Connect-MgGraph with User.ReadWrite.All, Group.ReadWrite.All). The leave date
needs no extra scope when the az sign-in is reused: its token carries Directory.AccessAsUser.All, which
covers it for a Global Administrator (verified 2026-10-19). Asking for User-LifeCycleInfo.* here would
force a device-code sign-in on every run, because the az token never carries it.
Signs in to Graph by reusing the az sign-in when it can (_auth.ps1); otherwise with a device code (the
browser redirect of an interactive login can't reach a dev container).

Estate (setup/scripts/_estate.ps1): every name carries this build's estate id, so several people can build
in one tenant without adopting each other's accounts - marcus.webb.<estate>@<domain>, "Marcus Webb
(<estate>)", Halcourt-Makers-<estate>. Pass -Estate or set HALCOURT_ESTATE.

Domain: the canon writes every UPN as <alias>@halcourtmutual.onmicrosoft.com, but a lab tenant gets
whatever domain Microsoft assigns (a Dev Program sandbox: something like a1b2c3d4.onmicrosoft.com), and
an *.onmicrosoft.com domain can't be added to another tenant. So the personas use the TENANT's default
verified domain; -DomainSuffix overrides it and must be a verified domain of the tenant.

Licences (reference/adr/0009-eight-licences-per-estate.md): the eight accounts that need one - svc-claims and
the seven agent owners - get the tenant's E5. An account that already holds it is skipped; when seats run out
the rest are reported, not failed, so free seats and re-run. -SkipLicences leaves licensing alone.

Safe to re-run: users and groups that already exist are left as they are.
#>
param(
  [string]$Estate = $env:HALCOURT_ESTATE,            # this build's estate id, e.g. jsmith (see _estate.ps1)
  [string]$TenantId,                                 # optional; target lab tenant (id or *.onmicrosoft.com)
  [string]$DomainSuffix,                             # default: the tenant's default verified domain
  [string]$InitialPassword,                          # default: Get-LabPassword (_estate.ps1) - never in the repo
  [string]$LicenceSku,                               # default: the tenant's E5 (DEVELOPERPACK_V2_E5, SPE_E5 or ENTERPRISEPREMIUM)
  [switch]$SkipLicences,
  [switch]$MarkDepartedOwner,
  [datetime]$DepartedOn = '2026-01-30T17:00:00Z'      # Tom's leave date (canon: users-export)
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_estate.ps1')
$InitialPassword = Get-LabPassword $InitialPassword
$Estate = Resolve-Estate $Estate

. (Join-Path $PSScriptRoot '_auth.ps1')
Connect-LabGraph -Scopes 'User.ReadWrite.All','Group.ReadWrite.All' -TenantId $TenantId -FallbackScopes 'User-LifeCycleInfo.ReadWrite.All'
# Connect-MgGraph can return without a session instead of throwing (e.g. sign-in timed out).
if (-not (Get-MgContext)) { throw 'Connect-MgGraph did not establish a session.' }

# Resolve the persona domain before touching anything, so a wrong domain can't leave a half-built estate.
$org = (Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/organization?$select=verifiedDomains,countryLetterCode').value[0]
$verified = @($org.verifiedDomains | ForEach-Object { $_.name })
if (-not $DomainSuffix) { $DomainSuffix = ($org.verifiedDomains | Where-Object { $_.isDefault } | Select-Object -First 1).name }
if ($DomainSuffix -notin $verified) {
  throw "'$DomainSuffix' is not a verified domain of this tenant. Verified domains: $($verified -join ', ')"
}
Write-Host "Estate: $Estate   Persona domain: $DomainSuffix"
Write-Host "  canon <alias>@halcourtmutual.onmicrosoft.com  ->  live <alias>.$Estate@$DomainSuffix"
# Usage location is required before a license can be assigned; use the tenant's country.
$usageLocation = if ($org.countryLetterCode) { $org.countryLetterCode } else { 'US' }

function Get-Upn([string]$Alias) { "$(Get-EstateAlias $Alias $Estate)@$DomainSuffix" }

if ($MarkDepartedOwner) {
  $tom = Get-Upn 'tom.dean'
  Write-Host "Marking departed owner $tom (leave date $($DepartedOn.ToUniversalTime().ToString('yyyy-MM-dd')); account stays enabled)..."
  Update-MgUser -UserId $tom -AccountEnabled:$true -EmployeeLeaveDateTime $DepartedOn.ToUniversalTime()
  Write-Host "$tom marked departed. Leave him ENABLED: disabling him kills the Onboarding Guide + Sales Nudge connections."
  return
}

# Canonical aliases and names (AGENTS.md); the estate id is added below.
$people = @(
  @{ Alias='ana.reyes';    Name='Ana Reyes';              Note='Platform admin / CoE lead (attendee vantage)' }
  @{ Alias='marcus.webb';  Name='Marcus Webb';            Note='HR maker' }
  @{ Alias='priya.nair';   Name='Priya Nair';             Note='Claims/underwriting maker' }
  @{ Alias='sam.olsen';    Name='Sam Olsen';              Note='Finance approver + maker' }
  @{ Alias='lena.ford';    Name='Lena Ford';              Note='Sales manager' }
  @{ Alias='dev.kim';      Name='Dev Kim';                Note='Developer (broad SharePoint)' }
  @{ Alias='tom.dean';     Name='Tom Dean';               Note='Departed admin (leave date in Phase 6.5; stays enabled)' }
  @{ Alias='jordan.blake'; Name='Jordan Blake';           Note='Low-privilege employee (confused-deputy path)' }
  @{ Alias='svc-claims';   Name='Claims Service Account'; Note='Service account for the shared Dataverse connection' }
)

foreach ($p in $people) {
  $upn = Get-Upn $p.Alias
  if (Get-MgUser -Filter "userPrincipalName eq '$upn'" -ErrorAction SilentlyContinue) {
    Write-Host "Exists:   $upn - leaving it as is."
    continue
  }
  $pwProfile = @{ Password = $InitialPassword; ForceChangePasswordNextSignIn = $false }
  Write-Host "Creating $upn - $($p.Note)"
  New-MgUser -AccountEnabled -DisplayName (Get-EstateDisplayName $p.Name $Estate) `
    -UserPrincipalName $upn -MailNickname (Get-EstateAlias $p.Alias $Estate) `
    -UsageLocation $usageLocation -PasswordProfile $pwProfile | Out-Null
}

# it.helpdesk shared mailbox: Graph can't create one, Exchange Online can - and Connect-LabExchange reuses the
# az sign-in (no device code). Owns Policy Lookup Bot; Phase 6 enables its sign-in + sets a password so it can
# ROPC. Exchange provisions the mailbox asynchronously (it can take a minute to appear).
$helpdesk = Get-EstateAlias 'it.helpdesk' $Estate
$helpdeskUpn = "$helpdesk@$DomainSuffix"
try {
  Connect-LabExchange -Organization $DomainSuffix
  if (Get-Mailbox -Identity $helpdeskUpn -ErrorAction SilentlyContinue) {
    Write-Host "Exists:   shared mailbox $helpdeskUpn - leaving it as is."
  } else {
    Write-Host "Creating shared mailbox $helpdeskUpn"
    New-Mailbox -Shared -Name (Get-EstateDisplayName 'IT Helpdesk' $Estate) -Alias $helpdesk -PrimarySmtpAddress $helpdeskUpn | Out-Null
  }
  Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
} catch {
  # Not fatal: the mailbox is only needed by Phase 6, so report it and carry on building the rest.
  Write-Warning "Could not create the it.helpdesk shared mailbox: $($_.Exception.Message.Split([Environment]::NewLine)[0])"
  Write-Host 'MANUAL: create it in Exchange Online (Connect-ExchangeOnline -Device), then:'
  Write-Host "  New-Mailbox -Shared -Name '$(Get-EstateDisplayName 'IT Helpdesk' $Estate)' -Alias $helpdesk -PrimarySmtpAddress $helpdeskUpn"
}

foreach ($canon in 'Halcourt-Makers','HR-Team','Claims-Adjusters','All-Employees') {
  $g = Get-EstateName $canon $Estate
  if (Get-MgGroup -Filter "displayName eq '$g'" -ErrorAction SilentlyContinue) {
    Write-Host "Exists:   group $g - leaving it as is."
    continue
  }
  Write-Host "Creating group $g"
  New-MgGroup -DisplayName $g -MailEnabled:$false -SecurityEnabled:$true -MailNickname $g | Out-Null
}

# Group membership (AGENTS.md -> Groups). Adds missing members, never removes any.
$membership = [ordered]@{
  'All-Employees'    = 'ana.reyes','marcus.webb','priya.nair','sam.olsen','lena.ford','dev.kim','tom.dean','jordan.blake'
  'HR-Team'          = @('marcus.webb')
  'Claims-Adjusters' = 'priya.nair','sam.olsen'
  'Halcourt-Makers'  = 'marcus.webb','priya.nair','sam.olsen','lena.ford','dev.kim','tom.dean'
}
foreach ($canon in $membership.Keys) {
  $g = Get-MgGroup -Filter "displayName eq '$(Get-EstateName $canon $Estate)'"
  $current = @(Get-MgGroupMember -GroupId $g.Id -All | ForEach-Object Id)
  $added = 0
  foreach ($alias in $membership[$canon]) {
    $u = Get-MgUser -UserId (Get-Upn $alias)
    if ($u.Id -in $current) { continue }
    New-MgGroupMember -GroupId $g.Id -DirectoryObjectId $u.Id
    $added++
  }
  Write-Host "Group $($g.DisplayName): $($membership[$canon].Count) members ($added added)"
}

# Licences (ADR-0009): svc-claims (Phase 5) and the seven agent owners (Phase 6). Never fatal.
if (-not $SkipLicences) {
  $skus = @((Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/subscribedSkus').value)
  $want = if ($LicenceSku) { @($LicenceSku) } else { 'DEVELOPERPACK_V2_E5', 'SPE_E5', 'ENTERPRISEPREMIUM' }
  $sku = $want | ForEach-Object { $n = $_; $skus | Where-Object { $_.skuPartNumber -eq $n } } | Select-Object -First 1
  if (-not $sku) {
    Write-Warning "No E5 licence in this tenant ($($want -join ', ')) - assign licences by hand (ADR-0009)."
  } else {
    $free = [int]$sku.prepaidUnits.enabled - [int]$sku.consumedUnits
    Write-Host "Licences: $($sku.skuPartNumber), $free free"
    $short = @()
    foreach ($alias in 'svc-claims','marcus.webb','priya.nair','lena.ford','dev.kim','tom.dean','sam.olsen','it.helpdesk') {
      $upn = Get-Upn $alias
      $u = Get-MgUser -UserId $upn -Property Id,UsageLocation,AssignedLicenses -ErrorAction SilentlyContinue
      if (-not $u) { Write-Warning "  $upn not found yet - re-run in a minute"; $short += $upn; continue }
      if ($sku.skuId -in @($u.AssignedLicenses.SkuId)) { Write-Host "  Licensed: $upn"; continue }
      if ($free -le 0) { $short += $upn; continue }
      # Exchange creates it.helpdesk without a usage location, and a licence needs one.
      if (-not $u.UsageLocation) { Update-MgUser -UserId $u.Id -UsageLocation $usageLocation }
      Invoke-MgGraphRequest -Method POST -Uri "https://graph.microsoft.com/v1.0/users/$($u.Id)/assignLicense" `
        -Body (@{ addLicenses = @(@{ skuId = $sku.skuId }); removeLicenses = @() } | ConvertTo-Json -Depth 5) `
        -ContentType 'application/json' | Out-Null
      Write-Host "  Assigned: $upn"
      $free--
    }
    if ($short) { Write-Warning "Not licensed: $($short -join ', '). Free seats (Phase 0, step 3) and re-run." }
  }
}

Write-Host "Phase 2 complete for estate '$Estate'. Remember Phase 6.5: re-run with -Estate $Estate -MarkDepartedOwner after Tom's connections exist."
