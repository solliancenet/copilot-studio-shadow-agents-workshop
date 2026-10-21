<#
FACILITATOR-ONLY. Phase 5b - auditing for Lab 05-07 (PLANNING item 16). Needs Phase 5's tables.

05-07 reconstructs Exercise 04 from the logs, so the logs have to be on BEFORE Exercise 04 runs - activity
from before is simply not there. Neither is on by default on a developer tenant (found 2026-10-20: unified
audit ingestion False, Claims-Test auditing off, so 05-07 had nothing to find):

  1. Microsoft Purview Audit - unified audit log ingestion (Exchange Online, app-only). Microsoft says a
     change takes up to 60 minutes; CopilotInteraction events start after that.
  2. Dataverse auditing in Claims-Test-<estate>: the environment, and the Claim table. That records CHANGES
     (create, update, delete, sharing) - what the 05-03 demonstration makes. NOT the Customer table:
     attendees read Claims-Test's audit records (05-07 KT03), and a customer change would carry its old and
     new values - SSN and date of birth - which they must not see. A run that finds it audited turns it off.

Deliberately NOT turned on: read logs. Dataverse auditing never records a read, and activity logging (Read logs
plus a table's read settings) reaches Purview only for PRODUCTION environments - Claims-Test is a sandbox, so
Claims Copilot's reads are logged nowhere. 05-07 KT03 teaches that gap; don't work around it.

Not used: Defender real-time protection for agents. It needs a Microsoft Agent 365 licence the lab tenant
doesn't have, so 05-07 KT06 is reasoned; RUNBOOK Phase 5b keeps the setup for a build that has one.

Auth: the lab app (_labapp.ps1, made by 03c) for Exchange Online; az's admin sign-in for Dataverse.
Safe to re-run. Isolated training tenants only. ASCII only.

  pwsh setup/scripts/04b_provision_audit.ps1            # estate from HALCOURT_ESTATE
#>
param(
  [string]$Estate = $env:HALCOURT_ESTATE
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_estate.ps1')          # also the tenant guard
$Estate = Resolve-Estate $Estate
. (Join-Path $PSScriptRoot '_labapp.ps1')
Ensure-LabApp -NoBilling                           # 04b uses no metered Graph API
$domain = (Get-Content $AppConfig -Raw | ConvertFrom-Json).organization

# ---- 1. unified audit log ingestion ---------------------------------------------------------------------
Write-Host '1. Purview Audit (unified audit log ingestion)'
Import-Module ExchangeOnlineManagement
Connect-ExchangeOnline -AccessToken (Get-AppToken 'https://outlook.office365.com') -Organization $domain -ShowBanner:$false
if ((Get-AdminAuditLogConfig).UnifiedAuditLogIngestionEnabled) { Write-Host '   already on' }
else {
  Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true -WarningAction SilentlyContinue
  Write-Host '   turned on - allow up to 60 minutes before running Exercise 04'
}
$ingestion = (Get-AdminAuditLogConfig).UnifiedAuditLogIngestionEnabled
Disconnect-ExchangeOnline -Confirm:$false | Out-Null

# ---- 2. Dataverse auditing in Claims-Test --------------------------------------------------------------
Write-Host "2. Dataverse auditing in $(Get-EstateName 'Claims-Test' $Estate)"
$pp = az account get-access-token --resource 'https://service.powerapps.com/' --query accessToken -o tsv
$envs = (Invoke-RestMethod -Uri 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2021-04-01' -Headers @{ Authorization = "Bearer $pp" }).value
$e = $envs | Where-Object { $_.properties.displayName -eq (Get-EstateName 'Claims-Test' $Estate) } | Select-Object -First 1
if (-not $e) { throw "Claims-Test-$Estate not found - run Phase 3 first." }
$Org = $e.properties.linkedEnvironmentMetadata.instanceUrl.TrimEnd('/')
$dvTok = az account get-access-token --resource $Org --query accessToken -o tsv
function Dv([string]$Method, [string]$Path, $Body, [hashtable]$Extra = @{}) {
  $h = @{ Authorization = "Bearer $dvTok" } + $Extra
  $u = "$Org/api/data/v9.2/$Path"
  if ($null -eq $Body) { Invoke-RestMethod -Method $Method -Uri $u -Headers $h }
  else { Invoke-RestMethod -Method $Method -Uri $u -Headers $h -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 30) }
}

$o = (Dv GET 'organizations?$select=organizationid,isauditenabled').value[0]
if ($o.isauditenabled) { Write-Host '   environment: already on' }
else {
  Dv PATCH "organizations($($o.organizationid))" @{ isauditenabled = $true } | Out-Null
  Write-Host '   environment: auditing on'
}

# A table's audit flags are metadata: read the whole definition, set the flags, PUT it back, publish.
$publish = @()
$want = @{ mm_claim = $true; mm_customer = $false }
foreach ($t in $want.Keys) {
  $def = Dv GET "EntityDefinitions(LogicalName='$t')"
  if ($def.IsAuditEnabled.Value -eq $want[$t]) { Write-Host "   $t : audited=$($want[$t]) already"; continue }
  $def.IsAuditEnabled.Value = $want[$t]
  $body = $def | Select-Object -Property * -ExcludeProperty '@odata.context'
  Dv PUT "EntityDefinitions($($def.MetadataId))" $body @{ 'MSCRM.MergeLabels' = 'true' } | Out-Null
  $publish += $t; Write-Host "   $t : audited=$($want[$t])"
}
if ($publish) {
  $xml = '<importexportxml><entities>' + (($publish | ForEach-Object { "<entity>$_</entity>" }) -join '') + '</entities></importexportxml>'
  Dv POST 'PublishXml' @{ ParameterXml = $xml } | Out-Null
  Write-Host '   published'
}

# ---- check ----------------------------------------------------------------------------------------------
# Metadata reads can lag the publish (seen: one table read back False/False/False right after it): retry.
for ($i = 0; $i -lt 6; $i++) {
  $o = (Dv GET 'organizations?$select=isauditenabled').value[0]
  $bad = @(foreach ($t in $want.Keys) { $d = Dv GET "EntityDefinitions(LogicalName='$t')?`$select=IsAuditEnabled"; if ($d.IsAuditEnabled.Value -ne $want[$t]) { $t } })
  $tabs = foreach ($t in $want.Keys) { "$t=$(if ($t -in $bad) { 'WRONG' } else { $want[$t] })" }
  if (-not $bad) { break }
  Start-Sleep 15
}
Write-Host "Check: unified audit ingestion=$ingestion; environment audit=$($o.isauditenabled); tables $($tabs -join ', ')"
if (-not $ingestion -or -not $o.isauditenabled -or $bad) { throw 'Auditing is not in the state 05-07 needs - see the Check line.' }
Write-Host 'Defender real-time protection is not used: 05-07 KT06 is reasoned (RUNBOOK Phase 5b).'
