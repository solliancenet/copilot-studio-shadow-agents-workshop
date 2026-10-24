<#
FACILITATOR-ONLY. Phase 4b - provision and seed the maker OneDrive that the Meeting Notes Summarizer
decoy grounds on. Runs AFTER Phase 4 (03_provision_sharepoint.ps1) and BEFORE Phase 6 (agents): the decoy
cannot be built until Dev Kim's OneDrive exists and holds his notes, and a Dev Program sandbox does NOT
auto-provision a user's OneDrive - hence a step of its own.

How it provisions: it asks the MAKER to touch their own drive. A user's first authenticated GET of
/me/drive answers ResourceNotFound ("User's mysite not found") and can enqueue the personal site behind it.
Personas are ordinary users, so the password grant is not blocked by the CA baseline's MFA-for-admins rule -
no administrator, no service account, no Conditional Access exception.

[verify] This is BEST EFFORT, not a guarantee. Measured on the verified tenant 2026-09-22:
  dev.kim  18:38 -> site Created 18:38:57, within a minute
  dev.kim  22:25 -> site Created 22:25:59, within a minute, on a true greenfield (the previous personal site
                    had been deleted AND purged first, so nothing was inherited)
  lena.ford 19:38 -> nothing 47 minutes later, identical licensing (4 SharePoint plans, all Enabled)
Two clean successes against one unexplained failure. First-access provisioning is asynchronous with no
published SLA, so the script tries it and waits.

If the site isn't up after -GraphTouchMinutes (5 min), the maker opens OneDrive in a headless browser
(lib/onedrive_first_run.py), the way a person does the first time. On 2026-10-23 that provisioned stu05's
site in about a minute, after the Graph touch had left it missing for 45 minutes twice. If the site still never
appears, the script FAILS with instructions to provision that one maker by hand and re-run - which then just
seeds.

SharePoint won't create a OneDrive for an UNLICENSED user, and no route above reports that: they just never
produce a site. 10_build_estates reclaims a failed estate's seats, so resume such an estate from Phase 2
(-From entra), which licenses its personas again.

The admin-side enqueue (CreatePersonalSiteEnqueueBulk / Request-PnPPersonalSite) is not an alternative here -
it cannot be done headlessly at all. Every route was tried and failed:
  - APP-ONLY (certificate): "Attempted to perform an unauthorized operation". Not a missing permission - the
    same app-only token does other tenant-admin work (Get/Remove-PnPTenantSite, ...DeletedSite). Personal-site
    provisioning wants a USER context.
  - The AZURE CLI's delegated token: 401 on EVERY SharePoint tenant-admin call, even as Global Admin -
    SharePoint does not accept that app. (It is fine for Graph and Exchange.)
  - A freshly created SharePoint Administrator: the password grant succeeds, but SharePoint does not honour a
    new role assignment for another 15-60 min, so the enqueue is still refused.
  - Even interactively, it isn't dependable: on 2026-10-23 a long-standing Global Admin, signed in by device
    code, was refused ("unauthorized operation") twice, for a licensed maker.

Prerequisite: the Phase 4 PnP app + certificate (RUNBOOK Phase 4) - used app-only to SEED the notes once the
site is up, and to test whether it is up. Note Graph's /users/<upn>/drive is NOT a reliable readiness check:
it can keep returning ResourceNotFound for a site that exists and is writable, so this script probes the
personal site with PnP instead.

Estate: names carry the estate id (setup/scripts/_estate.ps1). Pass -Estate or set HALCOURT_ESTATE.
#>
param(
  [string]$Estate       = $env:HALCOURT_ESTATE,
  [string]$TenantDomain,                                   # default: the tenant's default verified domain
  [string]$ClientId     = $env:ENTRAID_APP_ID,             # the Phase 4 PnP app (public client + cert)
  [string]$CertPath     = $env:HALCOURT_PNP_CERT_PFX,      # .pfx with the app's private key
  [string]$CertPassword = $env:HALCOURT_PNP_CERT_PW,
  [string]$MakerAlias   = 'dev.kim',                       # the OneDrive owner (Meeting Notes owner)
  [string]$LabPassword,                                    # the maker's; default: Get-LabPassword (_estate.ps1)
  [int]$ProvisionTimeoutMinutes = 45,                      # generous: first-access provisioning has no published SLA
  [int]$GraphTouchMinutes = 5                              # then the maker opens OneDrive in a browser
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_estate.ps1')
$LabPassword = Get-LabPassword $LabPassword
$Estate = Resolve-Estate $Estate
if (-not $ClientId)  { throw 'No PnP app id. Set ENTRAID_APP_ID (see RUNBOOK Phase 4).' }
if (-not $CertPath)  { throw 'No certificate. Set HALCOURT_PNP_CERT_PFX to the app-only .pfx (see header).' }

# Resolve the tenant domain and the SharePoint host from az's sign-in.
if (-not $TenantDomain) {
  $TenantDomain = az rest --method GET --url 'https://graph.microsoft.com/v1.0/organization?$select=verifiedDomains' `
    --query "value[0].verifiedDomains[?isDefault].name | [0]" -o tsv
}
$tenantName = $TenantDomain.Split('.')[0]                  # a1b2c3d4.onmicrosoft.com -> a1b2c3d4
$adminUrl   = "https://$tenantName-admin.sharepoint.com"
$myHost     = "https://$tenantName-my.sharepoint.com"
$maker      = "$(Get-EstateAlias $MakerAlias $Estate)@$TenantDomain"
$personal   = "$myHost/personal/$($maker.Replace('@','_').Replace('.','_'))"
$certPw     = if ($CertPassword) { ConvertTo-SecureString $CertPassword -AsPlainText -Force } else { $null }
$connArgs   = @{ ClientId = $ClientId; Tenant = $TenantDomain; CertificatePath = $CertPath; WarningAction = 'SilentlyContinue' }
if ($certPw) { $connArgs.CertificatePassword = $certPw }

Write-Host "Estate: $Estate   OneDrive owner: $maker"
Write-Host "  personal site: $personal"

# 1) If the personal site already exists (e.g. provisioned by the interactive admin fallback), skip the
#    enqueue and go straight to seeding. Otherwise enqueue it app-only.
function Test-OneDriveOnline {
  try { Connect-PnPOnline -Url $personal @connArgs; Get-PnPWeb | Out-Null; return $true } catch { return $false }
}
# The maker provisions their OWN OneDrive, which needs no administrator at all. A user's first authenticated
# touch of their drive enqueues the personal site: Graph answers ResourceNotFound ("User's mysite not found")
# straight away and provisions it in the background a while later. Personas are ordinary users, so the
# password grant is not blocked by the CA baseline's MFA-for-admins rule.
#
# This replaced an admin-side enqueue, which cannot be done headlessly (all verified 2026-09-22):
#   - app-only Request-PnPPersonalSite  -> "Attempted to perform an unauthorized operation" (wants a user
#     context; the same app-only token does other tenant-admin work fine),
#   - the Azure CLI's delegated token   -> 401 on EVERY SharePoint tenant-admin call, even as Global Admin,
#   - a freshly created admin account   -> the password grant succeeds, but SharePoint does not honour a new
#     SharePoint Administrator assignment for another 15-60 min, so the enqueue is still "unauthorized".
function Request-OneDriveAsMaker {
  $body = @{ client_id = '04b07795-8ddb-461a-bbee-02f9e1bf7b46'   # Azure CLI public client - fine for Graph
             grant_type = 'password'; username = $maker; password = $LabPassword
             scope = 'https://graph.microsoft.com/.default' }
  $tok = (Invoke-RestMethod -Method POST -Uri "https://login.microsoftonline.com/$TenantDomain/oauth2/v2.0/token" -Body $body).access_token
  try { Invoke-RestMethod -Uri 'https://graph.microsoft.com/v1.0/me/drive' -Headers @{ Authorization = "Bearer $tok" } | Out-Null }
  catch { }    # 404 is the expected answer the first time - the call is what enqueues the provisioning
}

if (Test-OneDriveOnline) {
  Write-Host "OneDrive already online - skipping provisioning."
} else {
  # SharePoint never creates a OneDrive for an unlicensed user, and nothing below would say so: every route
  # just waits out the timeout. Check first (see header: a builder-reclaimed estate resumed past Phase 2).
  $lic = az rest --method GET --url "https://graph.microsoft.com/v1.0/users/$maker`?`$select=assignedLicenses" --query 'length(assignedLicenses)' -o tsv
  if ($LASTEXITCODE -eq 0 -and "$lic".Trim() -eq '0') {
    throw "$maker has no licence, so SharePoint will never create their OneDrive. License the personas first: re-run Phase 2 (10_build_estates.ps1 -From entra), then 03b."
  }
  Write-Host "Asking $maker to open their own OneDrive (this enqueues it; no admin needed)..."
  Request-OneDriveAsMaker
  # 2) Wait until the personal site answers. If the Graph touch hasn't produced it, the maker opens OneDrive in
  #    a browser once (see header); then keep waiting.
  $start = Get-Date
  $deadline = $start.AddMinutes($ProvisionTimeoutMinutes)
  $ready = $false; $browsed = $false
  while ((Get-Date) -lt $deadline) {
    if (Test-OneDriveOnline) { $ready = $true; break }
    if (-not $browsed -and (Get-Date) -gt $start.AddMinutes($GraphTouchMinutes)) {
      $browsed = $true
      Write-Host "Not up after $GraphTouchMinutes min - $maker opens OneDrive in a browser..."
      $probe = Join-Path $PSScriptRoot 'lib/onedrive_first_run.py'
      $shots = Join-Path ([System.IO.Path]::GetTempPath()) "onedrive-first-run-$Estate"
      $res = python3 $probe --upn $maker --password $LabPassword --host $myHost --out $shots 2>&1
      Write-Host "  $(($res | Select-String '^(FINAL_URL|RESULT)=') -join '  ')"
      continue
    }
    Start-Sleep -Seconds 30
  }
  if (-not $ready) {
    throw @"
OneDrive at $personal did not come online within $ProvisionTimeoutMinutes min.
First-access provisioning is asynchronous and sometimes does not happen at all (see this script's header).
Provision this one maker by hand, then re-run - this script will find the site and just seed it:
  Connect-PnPOnline -Url $adminUrl -DeviceLogin -ClientId $ClientId
  Request-PnPPersonalSite -UserEmails $maker
"@
  }
}
Write-Host "OneDrive is online."

# 3) Seed Dev's notes (the Meeting Notes Summarizer grounding source).
$dataDir = Join-Path (Split-Path $PSScriptRoot -Parent) 'data'
$notesMd = Join-Path $dataDir 'Dev-Kim-Meeting-Notes.md'
$notesDocx = Join-Path ([System.IO.Path]::GetTempPath()) 'Dev-Kim-Meeting-Notes.docx'
if (Get-Command pandoc -ErrorAction SilentlyContinue) {
  pandoc $notesMd -o $notesDocx
  Add-PnPFile -Path $notesDocx -Folder 'Documents' | Out-Null
  Write-Host "Seeded Dev-Kim-Meeting-Notes.docx to $personal/Documents"
} else {
  Add-PnPFile -Path $notesMd -Folder 'Documents' | Out-Null
  Write-Warning "pandoc not found - uploaded the raw .md instead of a .docx."
}

# 4) Report what to ground the decoy on. (We are connected to the personal site, so the library is
#    site-relative 'Documents' - not the tenant-relative personal/<user>/Documents path.)
$files = Get-PnPFolderItem -FolderSiteRelativeUrl 'Documents' -ItemType File
Write-Host "Documents now holds:"; $files | ForEach-Object { "  $($_.Name) ($($_.Length) bytes)" }
Write-Host ""
Write-Host "Ground the Meeting Notes Summarizer decoy on this OneDrive (owner $maker):"
Write-Host "  $personal/Documents"
Disconnect-PnPOnline
