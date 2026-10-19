<#
FACILITATOR-ONLY. The kit's one app-only identity, halcourt-lab-compliance, shared by the scripts that can't
use the az sign-in. Dot-source it, then call Ensure-LabApp once and Get-AppToken <resource> as needed.

  03c_provision_purview.ps1  Security & Compliance PowerShell (labels), Graph (label assignment), SharePoint
  07_provision_lab_users.ps1 PIM: attendees' ELIGIBLE (not active) Exercise 05 roles

Why app-only: the az token is refused by Security & Compliance PowerShell, and lacks the PIM scopes
(RoleEligibilitySchedule.ReadWrite.Directory). Its certificate lives in setup/lab-compliance-app.local.*
(gitignored); Ensure-LabApp creates app, certificate, permissions, role and billing link if missing.
Callers set $AppConfig and $Pfx (paths) before dot-sourcing. ASCII only.
#>
if (-not $AppConfig) { $AppConfig = Join-Path (Split-Path -Parent $PSScriptRoot) 'lab-compliance-app.local.json' }
if (-not $Pfx)       { $Pfx       = Join-Path (Split-Path -Parent $PSScriptRoot) 'lab-compliance-app.local.pfx' }

# Everything this script signs in as is created here, so a fresh tenant needs nothing done by hand.
# Every step checks before it acts, so this runs in full on every call: an app created by an older kit (03c
# before 07 needed PIM) still gets each permission added since, and a certificate near expiry is replaced.
# -NoBilling: callers that never touch the metered Graph API (07) skip the billing link.
function Ensure-LabApp([switch]$NoBilling) {
  $name = 'halcourt-lab-compliance'
  $app  = az ad app list --display-name $name --query '[0].appId' -o tsv
  $haveCfg = (Test-Path $AppConfig) -and (Test-Path $Pfx)
  if ($haveCfg -and $app) {
    # Replace a certificate that expires within 30 days (they are issued for a year).
    try {
      $labCfg = Get-Content $AppConfig -Raw | ConvertFrom-Json
      if ($labCfg.appId -ne $app) { $haveCfg = $false }
      else {
        $c = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($Pfx, $labCfg.pfxPassword)
        if ($c.NotAfter -lt (Get-Date).AddDays(30)) { Write-Host "0. certificate expires $($c.NotAfter.ToString('yyyy-MM-dd')) - renewing"; $haveCfg = $false }
      }
    } catch { $haveCfg = $false }
  }
  if (-not $app) { $app = az ad app create --display-name $name --query appId -o tsv; Write-Host "0. created app $name ($app)" }
  if (-not $haveCfg) {
    # A fresh certificate; the private half stays in setup/*.local.pfx (gitignored), the public half on the app.
    $tmp = Join-Path ([IO.Path]::GetTempPath()) "cmp-$([guid]::NewGuid().ToString('N'))"; New-Item -ItemType Directory $tmp | Out-Null
    $pw = -join ((48..57) + (97..102) | Get-Random -Count 24 | ForEach-Object { [char]$_ })
    & openssl req -x509 -newkey rsa:2048 -nodes -keyout "$tmp/k.pem" -out "$tmp/c.crt" -days 365 -subj "/CN=$name" 2>$null
    & openssl pkcs12 -export -out $Pfx -inkey "$tmp/k.pem" -in "$tmp/c.crt" -passout "pass:$pw"
    az ad app credential reset --id $app --cert "@$tmp/c.crt" --append --only-show-errors | Out-Null
    $org = az rest --method GET --url 'https://graph.microsoft.com/v1.0/organization?$select=verifiedDomains' --query "value[0].verifiedDomains[?isInitial].name | [0]" -o tsv
    @{ appId = $app; pfxPassword = $pw; organization = $org } | ConvertTo-Json | Set-Content $AppConfig
    Remove-Item $tmp -Recurse -Force
    Write-Host "0. certificate -> $Pfx (gitignored)"
  }
  $sp = az ad sp list --filter "appId eq '$app'" --query '[0].id' -o tsv
  if (-not $sp) { $sp = az ad sp create --id $app --query id -o tsv }
  # Application permissions, admin-consented by assigning the app roles directly.
  foreach ($grant in @(@('00000002-0000-0ff1-ce00-000000000000', 'Exchange.ManageAsApp'),   # Security & Compliance PowerShell
                       @('00000003-0000-0000-c000-000000000000', 'Files.ReadWrite.All'),    # copy + assignSensitivityLabel
                       @('00000003-0000-0ff1-ce00-000000000000', 'Sites.FullControl.All'),    # SPO tenant setting
                       @('00000003-0000-0000-c000-000000000000', 'RoleEligibilitySchedule.ReadWrite.Directory'))) { # 07: PIM eligibility
    $res  = az ad sp list --filter "appId eq '$($grant[0])'" --query '[0].id' -o tsv
    $role = az ad sp show --id $grant[0] --query "appRoles[?value=='$($grant[1])'].id | [0]" -o tsv
    $have = az rest --method GET --url "https://graph.microsoft.com/v1.0/servicePrincipals/$sp/appRoleAssignments" --query "value[?appRoleId=='$role'] | length(@)" -o tsv
    if ($have -eq '0') {
      az ad app permission add --id $app --api $grant[0] --api-permissions "$role=Role" --only-show-errors 2>$null | Out-Null
      $b = @{ principalId = $sp; resourceId = $res; appRoleId = $role } | ConvertTo-Json -Compress; $f = New-TemporaryFile; Set-Content $f $b
      az rest --method POST --url "https://graph.microsoft.com/v1.0/servicePrincipals/$sp/appRoleAssignments" --body "@$f" | Out-Null; Remove-Item $f
      Write-Host "0. granted $($grant[1]) (allow a few minutes before it takes effect)"
    }
  }
  $tpl = az rest --method GET --url 'https://graph.microsoft.com/v1.0/directoryRoleTemplates' --query "value[?displayName=='Compliance Administrator'].id | [0]" -o tsv
  $hasRole = az rest --method GET --url "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments?`$filter=principalId eq '$sp' and roleDefinitionId eq '$tpl'" --query 'value | length(@)' -o tsv
  if ($hasRole -eq '0') {
    $b = @{ principalId = $sp; roleDefinitionId = $tpl; directoryScopeId = '/' } | ConvertTo-Json -Compress; $f = New-TemporaryFile; Set-Content $f $b
    az rest --method POST --url 'https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments' --body "@$f" | Out-Null; Remove-Item $f
    Write-Host '0. Compliance Administrator assigned'
  }
  if ($NoBilling) { return }
  # assignSensitivityLabel is metered: link the app to this subscription for billing.
  az provider register -n Microsoft.GraphServices --wait --only-show-errors | Out-Null
  $rg = 'rg-halcourt-graph-billing'
  if ((az group exists -n $rg) -ne 'true') { az group create -n $rg -l eastus2 --only-show-errors | Out-Null }
  if (-not (az resource list -g $rg --resource-type Microsoft.GraphServices/accounts --query "[?properties.appId=='$app'].id | [0]" -o tsv)) {
    az resource create -g $rg -n "$name-billing" --resource-type Microsoft.GraphServices/accounts --properties "{`"appId`":`"$app`"}" --location global --only-show-errors | Out-Null
    Write-Host '0. Graph metered-API billing linked'
  }
}

# ---- app-only tokens: a certificate client assertion, signed here (no MSAL dependency) ---------------
function Get-AppToken([string]$Resource) {
  $labCfg = Get-Content $AppConfig -Raw | ConvertFrom-Json
  $cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($Pfx, $labCfg.pfxPassword,
          [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)
  $b64 = { param([byte[]]$b) [Convert]::ToBase64String($b).TrimEnd('=').Replace('+', '-').Replace('/', '_') }
  if (-not $script:LabTenantId) { $script:LabTenantId = az account show --query tenantId -o tsv }
  $aud = "https://login.microsoftonline.com/$($script:LabTenantId)/oauth2/v2.0/token"
  $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $h = & $b64 ([Text.Encoding]::UTF8.GetBytes((@{ alg = 'RS256'; typ = 'JWT'; x5t = (& $b64 $cert.GetCertHash()) } | ConvertTo-Json -Compress)))
  $p = & $b64 ([Text.Encoding]::UTF8.GetBytes((@{ aud = $aud; iss = $labCfg.appId; sub = $labCfg.appId; jti = [guid]::NewGuid().ToString(); nbf = $now; exp = $now + 600 } | ConvertTo-Json -Compress)))
  $rsa = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
  $sig = & $b64 ($rsa.SignData([Text.Encoding]::UTF8.GetBytes("$h.$p"), [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                               [System.Security.Cryptography.RSASignaturePadding]::Pkcs1))
  $body = @{ client_id = $labCfg.appId; grant_type = 'client_credentials'; scope = "$($Resource.TrimEnd('/'))/.default"
             client_assertion_type = 'urn:ietf:params:oauth:client-assertion-type:jwt-bearer'; client_assertion = "$h.$p.$sig" }
  (Invoke-RestMethod -Method POST -Uri $aud -Body $body).access_token
}
