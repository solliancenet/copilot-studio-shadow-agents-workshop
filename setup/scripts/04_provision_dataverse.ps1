<#
FACILITATOR-ONLY. Phase 5 - Dataverse seed.

Creates the Claim and Customer tables in Claims-Test-<estate>, seeds rows (Customer holds SSN/DOB), and
grants svc-claims.<estate> the OVER-BROAD role (read/write all rows, no row-level security). The over-grant
+ missing RLS are what Scenarios C and D exploit, and what Module 5 (least privilege) will actually CLOSE.

Runs anywhere az is signed in to the lab tenant - the dev container, the host, or Windows - with no new
sign-in: everything goes through the Dataverse Web API and the Power Platform admin API with az's saved
token. It replaces a Windows PowerShell 5.1 script on Microsoft.Xrm.Data.PowerShell (ADAL-based, with an
interactive WPF sign-in).

Columns: a table's primary key is always <table>id, so the business keys are mm_customernumber and
mm_claimnumber (the seed CSVs' mm_customerid / mm_claimid columns map onto them).

svc-claims.<estate> must hold a license: Dataverse refuses to add an unlicensed user (userNotLicensed). If it
has none, everything else is still built and the role assignment is left for a re-run.

Estate (setup/scripts/_estate.ps1): pass -Estate or set HALCOURT_ESTATE. Safe to re-run.
#>
param(
  [string]$Estate = $env:HALCOURT_ESTATE,                          # this build's estate id, e.g. mgray (see _estate.ps1)
  [string]$ClaimsTestEnvUrl,                                       # default: Claims-Test-<estate>'s org URL
  [string]$PublisherPrefix = 'mm',                                 # customization prefix -> mm_* schema names
  [string]$OverBroadRoleName = 'svc-claims Dataverse Full Access'  # the intentional god-mode role
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_estate.ps1')
$Estate = Resolve-Estate $Estate
$dataDir = Join-Path (Split-Path -Parent $PSScriptRoot) 'data'
$p = $PublisherPrefix

# --- az rest wrapper ---------------------------------------------------------------------------------
function Invoke-AzRest([string]$Method, [string]$Url, [string]$Resource, $Body, [switch]$AllowNotFound, [switch]$Return) {
  $azArgs = @('rest', '--method', $Method, '--url', $Url, '--resource', $Resource,
              '--headers', 'Content-Type=application/json', 'OData-Version=4.0', 'OData-MaxVersion=4.0')
  if ($Return) { $azArgs += 'Prefer=return=representation' }
  $file = $null
  if ($null -ne $Body) {
    $file = New-TemporaryFile
    $Body | ConvertTo-Json -Depth 20 | Set-Content -Path $file -Encoding utf8
    $azArgs += @('--body', "@$file")
  }
  # A freshly provisioned Dataverse env is flaky while it warms up, in two distinct ways, and NEITHER means
  # the payload is wrong:
  #   0x80040216 "An unexpected error occurred"     - the first attribute POST after a table/attribute create,
  #                                                   while the customization subsystem settles
  #   0x80048564 "Database is currently unavailable" - relationship creates, before the database is serving
  # (0x80072322 is the ordinary concurrency error and retries just as well.) Back off and retry, so an
  # automated rebuild doesn't need the whole script re-run to inch one step further each time.
  $transient = '0x80040216|0x80072322|0x80048564|An unexpected error occurred|currently unavailable|Service Unavailable'
  $attempt = 0; $out = $null; $code = 0; $err = $null
  while ($true) {
    $attempt++
    $errFile = New-TemporaryFile
    $out = az @azArgs 2> $errFile
    $code = $LASTEXITCODE
    $err = Get-Content $errFile -Raw; Remove-Item $errFile
    if ($code -and $err -match $transient -and $attempt -lt 12) {
      $wait = [Math]::Min(30, 3 * $attempt)
      Write-Host "      transient Dataverse error (attempt $attempt) - retrying in ${wait}s..."
      Start-Sleep -Seconds $wait; continue
    }
    break
  }
  if ($file) { Remove-Item $file }
  if ($code) {
    if ($AllowNotFound -and $err -match 'Not Found|does not exist|Could not find') { return $null }
    throw "$Method $Url failed: $err"
  }
  $text = ($out | Out-String).Trim()
  if ($text) { $text | ConvertFrom-Json }
}

# --- Resolve this estate's Claims-Test and the org ------------------------------------------------------
$bap = 'https://api.bap.microsoft.com'
$claimsName = Get-EstateName 'Claims-Test' $Estate
$envs = (Invoke-AzRest GET "$bap/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2021-04-01" 'https://service.powerapps.com/').value
$claimsEnv = $envs | Where-Object { $_.properties.displayName -eq $claimsName } | Select-Object -First 1
if (-not $claimsEnv) { throw "$claimsName not found - run Phase 3 first." }
if (-not $ClaimsTestEnvUrl) { $ClaimsTestEnvUrl = $claimsEnv.properties.linkedEnvironmentMetadata.instanceUrl }
$org = $ClaimsTestEnvUrl.TrimEnd('/')
$api = "$org/api/data/v9.2"
function Invoke-Dv([string]$Method, [string]$Path, $Body, [switch]$AllowNotFound, [switch]$Return) {
  Invoke-AzRest $Method "$api/$Path" $org $Body -AllowNotFound:$AllowNotFound -Return:$Return
}
Invoke-Dv GET 'WhoAmI' | Out-Null
Write-Host "Estate: $Estate   $claimsName -> $org"

# Seed data names people canonically; map them to this estate's accounts on the tenant's domain.
$domain = az rest --method GET --url 'https://graph.microsoft.com/v1.0/organization?$select=verifiedDomains' `
  --query "value[0].verifiedDomains[?isDefault].name | [0]" -o tsv
function ConvertTo-LiveUpn([string]$Upn) {
  if ($Upn -match '^(.+)@halcourtmutual\.onmicrosoft\.com$') { return "$(Get-EstateAlias $Matches[1] $Estate)@$domain" }
  return $Upn
}

# --- Metadata helpers ------------------------------------------------------------------------------------
function New-Label([string]$Text) {
  @{ '@odata.type' = 'Microsoft.Dynamics.CRM.Label'
     LocalizedLabels = @(@{ '@odata.type' = 'Microsoft.Dynamics.CRM.LocalizedLabel'; Label = $Text; LanguageCode = 1033 }) }
}
$optional = @{ Value = 'None'; CanBeChanged = $true; ManagedPropertyLogicalName = 'canmodifyrequirementlevelsettings' }
function New-StringCol([string]$Schema, [string]$Display, [int]$MaxLength = 100, [switch]$Primary) {
  $c = @{ '@odata.type' = 'Microsoft.Dynamics.CRM.StringAttributeMetadata'; SchemaName = $Schema
          DisplayName = (New-Label $Display); RequiredLevel = $optional; MaxLength = $MaxLength; FormatName = @{ Value = 'Text' } }
  if ($Primary) { $c.IsPrimaryName = $true }
  $c
}
function New-DateCol([string]$Schema, [string]$Display) {
  @{ '@odata.type' = 'Microsoft.Dynamics.CRM.DateTimeAttributeMetadata'; SchemaName = $Schema
     DisplayName = (New-Label $Display); RequiredLevel = $optional; Format = 'DateOnly'; DateTimeBehavior = @{ Value = 'DateOnly' } }
}
function New-MoneyCol([string]$Schema, [string]$Display) {
  # Without AttributeType/AttributeTypeName and a value range the API fails with 0x80040216 ("unexpected error").
  @{ '@odata.type' = 'Microsoft.Dynamics.CRM.MoneyAttributeMetadata'; SchemaName = $Schema
     AttributeType = 'Money'; AttributeTypeName = @{ Value = 'MoneyType' }
     DisplayName = (New-Label $Display); RequiredLevel = $optional; PrecisionSource = 2; MinValue = 0; MaxValue = 1000000000 }
}
function Confirm-Table([string]$Schema, [string]$Display, [string]$Plural, $PrimaryName, [array]$Columns) {
  $logical = $Schema.ToLowerInvariant()
  if (Invoke-Dv GET "EntityDefinitions(LogicalName='$logical')?`$select=LogicalName" -AllowNotFound) {
    Write-Host "  Table $Schema exists - skipping create."
  } else {
    Write-Host "  Creating table $Schema"
    Invoke-Dv POST 'EntityDefinitions' @{
      '@odata.type' = 'Microsoft.Dynamics.CRM.EntityMetadata'; SchemaName = $Schema
      DisplayName = (New-Label $Display); DisplayCollectionName = (New-Label $Plural)
      OwnershipType = 'UserOwned'; IsActivity = $false; HasActivities = $false; HasNotes = $false
      Attributes = @($PrimaryName)
    } | Out-Null
  }
  foreach ($col in $Columns) {
    $colLogical = $col.SchemaName.ToLowerInvariant()
    if (Invoke-Dv GET "EntityDefinitions(LogicalName='$logical')/Attributes(LogicalName='$colLogical')?`$select=LogicalName" -AllowNotFound) {
      Write-Host "    Column $($col.SchemaName) exists - skipping."
      continue
    }
    Write-Host "    Adding column $($col.SchemaName)"
    # A column created before customizations are published can be invisible to the read above, so the create
    # may report it already exists (0x80047013) - that counts as done.
    try { Invoke-Dv POST "EntityDefinitions(LogicalName='$logical')/Attributes" $col | Out-Null }
    catch { if ("$_" -match 'already exists') { Write-Host "    Column $($col.SchemaName) exists (unpublished) - skipping." } else { throw } }
  }
}

# --- Publisher (owns the mm_ prefix) ----------------------------------------------------------------------
if ((Invoke-Dv GET "publishers?`$select=publisherid&`$filter=customizationprefix eq '$p'").value) {
  Write-Host "Publisher with prefix '$p' already present."
} else {
  Invoke-Dv POST 'publishers' @{ uniquename = 'halcourtmutual'; friendlyname = 'Halcourt Mutual'
                                 customizationprefix = $p; customizationoptionvalueprefix = 20000 } | Out-Null
  Write-Host "Created publisher (prefix $p)."
}

# --- Tables --------------------------------------------------------------------------------------------------
# Customer(mm_name [primary], mm_customernumber, mm_ssn, mm_dob)       <- PII: SSN + DOB
# Claim(mm_claimnumber [primary], mm_customer [lookup], mm_status, mm_amount, mm_adjuster)
Write-Host 'Creating Customer and Claim tables. Customer holds SSN/DOB (PII).'
Confirm-Table "${p}_customer" 'Customer' 'Customers' (New-StringCol "${p}_name" 'Name' 100 -Primary) @(
  (New-StringCol "${p}_customernumber" 'Customer ID' 20),
  (New-StringCol "${p}_ssn" 'SSN' 11),
  (New-DateCol   "${p}_dob" 'Date of Birth'))
Confirm-Table "${p}_claim" 'Claim' 'Claims' (New-StringCol "${p}_claimnumber" 'Claim ID' 100 -Primary) @(
  (New-StringCol "${p}_status" 'Status' 50),
  (New-MoneyCol  "${p}_amount" 'Amount'),
  (New-StringCol "${p}_adjuster" 'Adjuster' 200))

# Customer 1 -> N Claim, surfaced on Claim as the mm_customer lookup.
if (Invoke-Dv GET "EntityDefinitions(LogicalName='${p}_claim')/Attributes(LogicalName='${p}_customer')?`$select=LogicalName" -AllowNotFound) {
  Write-Host "    Lookup ${p}_customer exists - skipping."
} else {
  Write-Host "    Creating lookup ${p}_customer (Customer 1 -> N Claim)"
  Invoke-Dv POST 'RelationshipDefinitions' @{
    '@odata.type' = 'Microsoft.Dynamics.CRM.OneToManyRelationshipMetadata'; SchemaName = "${p}_customer_claim"
    ReferencedEntity = "${p}_customer"; ReferencingEntity = "${p}_claim"
    Lookup = @{ '@odata.type' = 'Microsoft.Dynamics.CRM.LookupAttributeMetadata'; SchemaName = "${p}_customer"
                DisplayName = (New-Label 'Customer'); RequiredLevel = $optional }
  } | Out-Null
}
Write-Host 'Publishing customizations...'
Invoke-Dv POST 'PublishAllXml' @{} | Out-Null

# --- Seed rows -----------------------------------------------------------------------------------------------
$custSet  = (Invoke-Dv GET "EntityDefinitions(LogicalName='${p}_customer')?`$select=EntitySetName").EntitySetName
$claimSet = (Invoke-Dv GET "EntityDefinitions(LogicalName='${p}_claim')?`$select=EntitySetName").EntitySetName

Write-Host "Seeding Customer rows from $dataDir/customers.csv"
$custIds = @{}   # CUS-xxx -> row id
foreach ($row in (Import-Csv (Join-Path $dataDir 'customers.csv'))) {
  $existing = (Invoke-Dv GET "$custSet`?`$select=${p}_customerid&`$filter=${p}_customernumber eq '$($row.mm_customerid)'").value
  if ($existing) { $custIds[$row.mm_customerid] = $existing[0]."${p}_customerid"; Write-Host "  Customer $($row.mm_customerid) exists - skipping."; continue }
  $new = Invoke-Dv POST $custSet @{ "${p}_name" = $row.mm_name; "${p}_customernumber" = $row.mm_customerid
                                    "${p}_ssn" = $row.mm_ssn; "${p}_dob" = $row.mm_dob } -Return
  $custIds[$row.mm_customerid] = $new."${p}_customerid"
  Write-Host "  Created customer $($row.mm_customerid) ($($row.mm_name))"
}

Write-Host "Seeding Claim rows from $dataDir/claims.csv"
foreach ($row in (Import-Csv (Join-Path $dataDir 'claims.csv'))) {
  if ((Invoke-Dv GET "$claimSet`?`$select=${p}_claimid&`$filter=${p}_claimnumber eq '$($row.mm_claimid)'").value) {
    Write-Host "  Claim $($row.mm_claimid) exists - skipping."; continue
  }
  $adjuster = ConvertTo-LiveUpn $row.mm_adjuster   # priya.nair / sam.olsen: this estate's accounts
  $fields = @{ "${p}_claimnumber" = $row.mm_claimid; "${p}_status" = $row.mm_status
               "${p}_amount" = [decimal]$row.mm_amount; "${p}_adjuster" = $adjuster }
  if ($custIds.ContainsKey($row.mm_customer)) { $fields["${p}_customer@odata.bind"] = "/$custSet($($custIds[$row.mm_customer]))" }
  else { Write-Warning "  Claim $($row.mm_claimid): customer $($row.mm_customer) not found - leaving lookup empty." }
  Invoke-Dv POST $claimSet $fields | Out-Null
  Write-Host "  Created claim $($row.mm_claimid) (adjuster $adjuster)"
}

# --- The over-broad role -------------------------------------------------------------------------------------
# INTENTIONAL planted problem (Scenario C / D). ORGANIZATION-DEPTH (Global) create/read/write on ALL Claim and
# Customer rows, PII included. No row-level security. The agent's job only needs the requesting adjuster's
# own claims. Module 5 (least privilege) REPLACES this with a scoped role + RLS. DO NOT scope this down here.
Write-Host "Creating the over-broad Dataverse role: '$OverBroadRoleName'"
$rootBu = (Invoke-Dv GET "businessunits?`$select=businessunitid&`$filter=_parentbusinessunitid_value eq null").value[0].businessunitid
$role = (Invoke-Dv GET "roles?`$select=roleid&`$filter=name eq '$OverBroadRoleName' and _businessunitid_value eq $rootBu").value | Select-Object -First 1
if ($role) { $roleId = $role.roleid; Write-Host "  Role already exists - reusing $roleId" }
else {
  $roleId = (Invoke-Dv POST 'roles' @{ name = $OverBroadRoleName; 'businessunitid@odata.bind' = "/businessunits($rootBu)" } -Return).roleid
  Write-Host "  Created role $roleId"
}
$privileges = foreach ($t in "${p}_claim", "${p}_customer") {
  foreach ($op in 'Create', 'Read', 'Write', 'Append', 'AppendTo', 'Assign', 'Share') {
    $priv = (Invoke-Dv GET "privileges?`$select=privilegeid&`$filter=name eq 'prv$op$t'").value | Select-Object -First 1
    if ($priv) { @{ PrivilegeId = $priv.privilegeid; Depth = 'Global' } } else { Write-Warning "    Privilege prv$op$t not found - skipping." }
  }
}
Invoke-Dv POST "roles($roleId)/Microsoft.Dynamics.CRM.AddPrivilegesRole" @{ Privileges = @($privileges) } | Out-Null
Write-Host "  Granted $(@($privileges).Count) Global-depth privileges (Claim + Customer, incl. PII)."

# --- The service account -------------------------------------------------------------------------------------
$svcUpn = "$(Get-EstateAlias 'svc-claims' $Estate)@$domain"
$svc = (Invoke-Dv GET "systemusers?`$select=systemuserid&`$filter=domainname eq '$svcUpn'").value | Select-Object -First 1
if (-not $svc) {
  # Force-sync the user into the environment (what PPAC's "Add user" does).
  $svcOid = az ad user show --id $svcUpn --query id -o tsv
  if ($LASTEXITCODE -or -not $svcOid) { throw "$svcUpn not found in Entra - run Phase 2 first." }
  try {
    Invoke-AzRest POST "$bap/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/$($claimsEnv.name)/addUser?api-version=2020-10-01" `
      'https://service.powerapps.com/' @{ ObjectId = $svcOid } | Out-Null
    $svc = (Invoke-Dv GET "systemusers?`$select=systemuserid&`$filter=domainname eq '$svcUpn'").value | Select-Object -First 1
  } catch {
    if ("$_" -notmatch 'userNotLicensed') { throw }
    Write-Warning "$svcUpn has no license, and Dataverse won't add an unlicensed user (userNotLicensed)."
    Write-Warning "Assign it a license, then re-run this script: only the role assignment is left."
  }
}
$assigned = $false
if ($svc) {
  $current = (Invoke-Dv GET "systemusers($($svc.systemuserid))/systemuserroles_association?`$select=roleid").value
  if ($current.roleid -contains $roleId) { Write-Host "  Role already assigned to $svcUpn." }
  else {
    Invoke-Dv POST "systemusers($($svc.systemuserid))/systemuserroles_association/`$ref" @{ '@odata.id' = "$api/roles($roleId)" } | Out-Null
    Write-Host "  Assigned '$OverBroadRoleName' to $svcUpn."
  }
  $assigned = $true
}

# --- Verify ----------------------------------------------------------------------------------------------------
Write-Host ''
Write-Host '================ Phase 5 verification ================'
$custRows  = (Invoke-Dv GET "$custSet`?`$select=${p}_customernumber,${p}_name,${p}_ssn,${p}_dob").value
$claimRows = (Invoke-Dv GET "$claimSet`?`$select=${p}_claimnumber,${p}_status,${p}_amount,${p}_adjuster,_${p}_customer_value").value
Write-Host "Customer rows: $(@($custRows).Count) (with SSN: $(@($custRows | Where-Object { $_."${p}_ssn" }).Count))"
Write-Host "Claim rows:    $(@($claimRows).Count) (linked to a customer: $(@($claimRows | Where-Object { $_."_${p}_customer_value" }).Count))"
$claimRows | ForEach-Object { Write-Host ("  {0,-9} {1,-13} {2,8}  {3}" -f $_."${p}_claimnumber", $_."${p}_status", $_."${p}_amount", $_."${p}_adjuster") }
$granted = (Invoke-Dv GET "roles($roleId)/roleprivileges_association?`$select=name").value
Write-Host "Role '$OverBroadRoleName': $(@($granted).Count) privileges ($((@($granted.name) | Sort-Object) -join ', '))"
Write-Host "svc-claims role assignment: $(if ($assigned) { "done ($svcUpn)" } else { "PENDING - $svcUpn needs a license" })"
Write-Host "Phase 5 $(if ($assigned) { 'complete' } else { 'complete except the role assignment' })."
