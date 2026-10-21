<#
FACILITATOR-ONLY. Sign-in reuse - dot-sourced by the scripts that call Microsoft Graph.

Microsoft Graph PowerShell keeps no token cache between processes on Linux, so every script used to ask
for a new device-code sign-in. The Azure CLI does keep one (project-local: .azure/ via scripts/env.sh),
and its Graph token already carries the scopes these scripts need (User/Group.ReadWrite.All,
User.Read.All, Application.ReadWrite.All, AuditLog.Read.All). So: reuse the az sign-in when it covers the
requested scopes and tenant; otherwise fall back to a device-code sign-in.

-FallbackScopes are requested only by the device-code sign-in: permissions the reused az token already
covers through Directory.AccessAsUser.All (the leave date, User-LifeCycleInfo.*), which a device-code
session would otherwise lack. They are not checked against the az token, so naming them doesn't force
device code on every run.

Not usable for Conditional Access (the Azure CLI app has no Policy.* scopes) - 00_ signs in itself.
ASCII only.
#>

function Connect-LabGraph([string[]]$Scopes, [string]$TenantId, [string[]]$FallbackScopes = @()) {
  if (Get-Command az -ErrorAction SilentlyContinue) {
    $token = az account get-access-token --resource-type ms-graph --query accessToken -o tsv 2>$null
    if ($LASTEXITCODE -eq 0 -and $token) {
      # Read the token's tenant and scopes (JWT payload) before trusting it.
      $payload = $token.Split('.')[1].Replace('-', '+').Replace('_', '/')
      $payload += '=' * ((4 - $payload.Length % 4) % 4)
      $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
      $granted = @($claims.scp -split ' ')
      # X.ReadWrite.All also covers X.Read.All.
      $missing = @($Scopes | Where-Object { $_ -notin $granted -and ($_ -replace '\.Read\.', '.ReadWrite.') -notin $granted })
      $wrongTenant = $TenantId -match '^[0-9a-f-]{36}$' -and $claims.tid -ne $TenantId
      if (-not $missing -and -not $wrongTenant) {
        Connect-MgGraph -AccessToken (ConvertTo-SecureString $token -AsPlainText -Force) -NoWelcome
        Write-Host "Microsoft Graph: reusing the az sign-in ($($claims.upn), tenant $($claims.tid))."
        return
      }
      if ($wrongTenant) { Write-Host "Microsoft Graph: az is signed in to tenant $($claims.tid), not $TenantId - signing in separately." }
      else              { Write-Host "Microsoft Graph: the az sign-in lacks $($missing -join ', ') - signing in separately." }
    }
  }
  # Device code signs in to whatever tenant the browser picks, so pin it: to -TenantId, else to the tenant
  # the repo's az sign-in is on (the tenant _estate.ps1's guard vouches for), and check it afterwards.
  if (-not $TenantId -and (Get-Command az -ErrorAction SilentlyContinue)) { $TenantId = az account show --query tenantId -o tsv 2>$null }
  if (-not $TenantId) { throw 'No tenant to pin the Graph sign-in to: pass -TenantId, or sign az in to the lab tenant (scripts/env.sh).' }
  Connect-MgGraph -Scopes (@($Scopes) + @($FallbackScopes) | Select-Object -Unique) -UseDeviceCode -NoWelcome -TenantId $TenantId
  $ctx = Get-MgContext
  if ($ctx -and $TenantId -match '^[0-9a-f-]{36}$' -and $ctx.TenantId -ne $TenantId) {
    Disconnect-MgGraph | Out-Null
    throw "Graph signed in to tenant $($ctx.TenantId), not $TenantId."
  }
}

# Exchange Online, same idea: Connect-ExchangeOnline accepts a delegated access token, so reuse the az
# sign-in (no device code, no app-only Exchange app). The signed-in admin manages recipients (the shared
# mailbox Graph can't create). $Organization is the tenant's onmicrosoft.com (or any verified) domain.
function Connect-LabExchange([string]$Organization) {
  Import-Module ExchangeOnlineManagement -ErrorAction Stop
  if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Connect-LabExchange needs az: it reuses the az sign-in for the Exchange token.'
  }
  $token = az account get-access-token --resource https://outlook.office365.com --query accessToken -o tsv 2>$null
  if ($LASTEXITCODE -ne 0 -or -not $token) {
    throw 'Could not get an Exchange Online token from az - sign in first (see scripts/env.sh).'
  }
  Connect-ExchangeOnline -AccessToken $token -Organization $Organization -ShowBanner:$false | Out-Null
}

# Security & Compliance (Purview) as the signed-in ADMIN. Role-group membership needs Role Management, which
# only Organization Management carries (Global Administrator) - the lab app's app-only session exposes
# Add-RoleGroupMember with no parameters at all. S&C refuses the az token (03c), and Connect-IPPSSession 3.x
# has no device-code switch, so run the device-code flow here for Exchange Online PowerShell's public client
# and hand the delegated token to -AccessToken. One browser approval (MFA) per run.
function Connect-LabComplianceAdmin([string]$Organization, [string]$TenantId) {
  Import-Module ExchangeOnlineManagement -ErrorAction Stop
  if (-not $TenantId) { $TenantId = az account show --query tenantId -o tsv 2>$null }
  if (-not $TenantId) { throw 'Connect-LabComplianceAdmin: no tenant to pin the sign-in to.' }
  $client = 'fb78d390-0c51-40cd-8e17-fdbfab77341b'            # Exchange Online PowerShell (public client)
  $scope  = 'https://ps.compliance.protection.outlook.com/.default offline_access'
  $dc = Invoke-RestMethod -Method POST -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/devicecode" -Body @{ client_id = $client; scope = $scope }
  Write-Host "Security & Compliance admin sign-in: $($dc.message)"
  $deadline = (Get-Date).AddSeconds([int]$dc.expires_in)
  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Seconds ([int]$dc.interval)
    try {
      $t = Invoke-RestMethod -Method POST -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -Body @{
        grant_type = 'urn:ietf:params:oauth:grant-type:device_code'; client_id = $client; device_code = $dc.device_code }
      break
    } catch {
      $e = ($_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue).error
      if ($e -notin 'authorization_pending', 'slow_down') { throw "Device-code sign-in failed: $e" }
    }
  }
  if (-not $t) { throw 'Device-code sign-in timed out.' }
  $payload = $t.access_token.Split('.')[1].Replace('-', '+').Replace('_', '/'); $payload += '=' * ((4 - $payload.Length % 4) % 4)
  $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload)) | ConvertFrom-Json
  if ($claims.tid -ne $TenantId) { throw "Signed in to tenant $($claims.tid), not $TenantId." }
  Connect-IPPSSession -AccessToken $t.access_token -Organization $Organization -UserPrincipalName $claims.upn -ShowBanner:$false
  Write-Host "Security & Compliance: signed in as $($claims.upn)."
}
