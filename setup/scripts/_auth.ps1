<#
FACILITATOR-ONLY. Sign-in reuse - dot-sourced by the scripts that call Microsoft Graph.

Microsoft Graph PowerShell keeps no token cache between processes on Linux, so every script used to ask
for a new device-code sign-in. The Azure CLI does keep one (project-local: .azure/ via scripts/env.sh),
and its Graph token already carries the scopes these scripts need (User/Group.ReadWrite.All,
User.Read.All, Application.ReadWrite.All, AuditLog.Read.All). So: reuse the az sign-in when it covers the
requested scopes and tenant; otherwise fall back to a device-code sign-in.

Not usable for Conditional Access (the Azure CLI app has no Policy.* scopes) - 00_ signs in itself.
ASCII only.
#>

function Connect-LabGraph([string[]]$Scopes, [string]$TenantId) {
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
  $connectArgs = @{ Scopes = $Scopes; UseDeviceCode = $true; NoWelcome = $true }
  if ($TenantId) { $connectArgs['TenantId'] = $TenantId }
  Connect-MgGraph @connectArgs
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
