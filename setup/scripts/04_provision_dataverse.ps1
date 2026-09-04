<#
FACILITATOR-ONLY. Phase 5 — Dataverse seed.

Creates Claim and Customer tables in Claims-Test, seeds rows (Customer holds SSN/DOB), and grants
svc-claims the OVER-BROAD role (read/write all rows, no row-level security). The over-grant + missing RLS
are what Scenarios C and D exploit, and what Module 5 (least privilege) will actually CLOSE.

Requires: Microsoft.Xrm.Data.PowerShell (Connect-CrmOnline, New-CrmRecord, Get-CrmRecords). Table and
security-role metadata are created through the underlying IOrganizationService on the returned
CrmServiceClient ($conn.ExecuteCrmOrganizationRequest(...)) using the Microsoft.Xrm.Sdk message types
the module loads. pac CLI is a supported alternative for the seed but is not used here.

Lines marked [verify] depend on tenant specifics or on 2026 metadata-cmdlet surface.
#>
param(
  [Parameter(Mandatory=$true)][string]$ClaimsTestEnvUrl,                     # https://<org>.crm.dynamics.com
  [string]$SvcClaimsUpn = 'svc-claims@halcourtmutual.onmicrosoft.com',       # over-permissioned service account
  [pscredential]$Credential,                                                 # optional; falls back to interactive
  [string]$PublisherPrefix = 'mm',                                           # customization prefix -> mm_* schema names
  [string]$OverBroadRoleName = 'svc-claims Dataverse Full Access'            # the intentional god-mode role
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $PSCommandPath
$dataDir = Join-Path (Split-Path -Parent $here) 'data'

Import-Module Microsoft.Xrm.Data.PowerShell -ErrorAction Stop

# --- Connect -----------------------------------------------------------------
Write-Host "Connecting to Claims-Test org: $ClaimsTestEnvUrl"
$connectArgs = @{ ServerUrl = $ClaimsTestEnvUrl }
if ($Credential) { $connectArgs['Credential'] = $Credential } else { $connectArgs['InteractiveMode'] = $true }  # [verify] auth path per tenant (SPN/cert also valid)
$conn = Connect-CrmOnline @connectArgs
if (-not $conn -or -not $conn.IsReady) { throw "Failed to connect to $ClaimsTestEnvUrl" }
Write-Host "Connected to $($conn.ConnectedOrgFriendlyName)"

# --- Metadata helpers --------------------------------------------------------
$req = 1033  # LCID for labels

function New-Label([string]$text) {
  New-Object Microsoft.Xrm.Sdk.Label($text, $req)
}

function New-StringAttr([string]$schema, [string]$display, [int]$maxLen = 100) {
  $a = New-Object Microsoft.Xrm.Sdk.Metadata.StringAttributeMetadata
  $a.SchemaName = $schema
  $a.MaxLength  = $maxLen
  $a.FormatName = [Microsoft.Xrm.Sdk.Metadata.StringFormatName]::Text
  $a.RequiredLevel = New-Object Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevelManagedProperty([Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::None)
  $a.DisplayName = New-Label $display
  return $a
}

function New-DateAttr([string]$schema, [string]$display) {
  $a = New-Object Microsoft.Xrm.Sdk.Metadata.DateTimeAttributeMetadata
  $a.SchemaName = $schema
  $a.Format     = [Microsoft.Xrm.Sdk.Metadata.DateTimeFormat]::DateOnly
  $a.RequiredLevel = New-Object Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevelManagedProperty([Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::None)
  $a.DisplayName = New-Label $display
  return $a
}

function New-MoneyAttr([string]$schema, [string]$display) {
  $a = New-Object Microsoft.Xrm.Sdk.Metadata.MoneyAttributeMetadata
  $a.SchemaName = $schema
  $a.RequiredLevel = New-Object Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevelManagedProperty([Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::None)
  $a.DisplayName = New-Label $display
  return $a
}

function Test-EntityExists([string]$logicalName) {
  try {
    $r = New-Object Microsoft.Xrm.Sdk.Messages.RetrieveEntityRequest
    $r.LogicalName    = $logicalName
    $r.EntityFilters  = [Microsoft.Xrm.Sdk.Metadata.EntityFilters]::Entity
    $r.RetrieveAsIfPublished = $true
    [void]$conn.ExecuteCrmOrganizationRequest($r)
    return $true
  } catch { return $false }
}

# Create a custom entity with a string primary-name column, then add extra columns.
function New-CustomTable {
  param(
    [string]$Schema,            # e.g. mm_customer
    [string]$DisplayName,
    [string]$DisplayCollection,
    [string]$PrimarySchema,     # e.g. mm_name
    [string]$PrimaryDisplay,
    [Microsoft.Xrm.Sdk.Metadata.AttributeMetadata[]]$ExtraColumns
  )
  $logical = $Schema.ToLowerInvariant()
  if (Test-EntityExists $logical) {
    Write-Host "  Table $Schema already exists — skipping create."
  } else {
    Write-Host "  Creating table $Schema"
    $em = New-Object Microsoft.Xrm.Sdk.Metadata.EntityMetadata
    $em.SchemaName       = $Schema
    $em.DisplayName      = New-Label $DisplayName
    $em.DisplayCollectionName = New-Label $DisplayCollection
    $em.OwnershipType    = [Microsoft.Xrm.Sdk.Metadata.OwnershipTypes]::UserOwned
    $em.IsActivity       = $false

    $primary = New-StringAttr $PrimarySchema $PrimaryDisplay 100

    $createEntity = New-Object Microsoft.Xrm.Sdk.Messages.CreateEntityRequest
    $createEntity.Entity = $em
    $createEntity.PrimaryAttribute = $primary
    [void]$conn.ExecuteCrmOrganizationRequest($createEntity)
  }

  foreach ($col in $ExtraColumns) {
    if (Test-ColumnExists $logical $col.SchemaName.ToLowerInvariant()) {
      Write-Host "    Column $($col.SchemaName) exists — skipping."
      continue
    }
    Write-Host "    Adding column $($col.SchemaName)"
    $ca = New-Object Microsoft.Xrm.Sdk.Messages.CreateAttributeRequest
    $ca.EntityName = $logical
    $ca.Attribute  = $col
    [void]$conn.ExecuteCrmOrganizationRequest($ca)
  }
  return $logical
}

function Test-ColumnExists([string]$entityLogical, [string]$attrLogical) {
  try {
    $r = New-Object Microsoft.Xrm.Sdk.Messages.RetrieveAttributeRequest
    $r.EntityLogicalName    = $entityLogical
    $r.LogicalName          = $attrLogical
    $r.RetrieveAsIfPublished = $true
    [void]$conn.ExecuteCrmOrganizationRequest($r)
    return $true
  } catch { return $false }
}

# Create a Customer lookup on Claim via a 1:N relationship (Customer 1 -> N Claim).
function New-CustomerLookup {
  param([string]$CustomerLogical, [string]$ClaimLogical, [string]$LookupSchema, [string]$LookupDisplay)
  if (Test-ColumnExists $ClaimLogical $LookupSchema.ToLowerInvariant()) {
    Write-Host "    Lookup $LookupSchema exists — skipping."
    return
  }
  Write-Host "    Creating lookup $LookupSchema (Customer 1 -> N Claim)"
  $lookup = New-Object Microsoft.Xrm.Sdk.Metadata.LookupAttributeMetadata
  $lookup.SchemaName  = $LookupSchema
  $lookup.DisplayName = New-Label $LookupDisplay
  $lookup.RequiredLevel = New-Object Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevelManagedProperty([Microsoft.Xrm.Sdk.Metadata.AttributeRequiredLevel]::None)

  $rel = New-Object Microsoft.Xrm.Sdk.Metadata.OneToManyRelationshipMetadata
  $rel.SchemaName        = "${PublisherPrefix}_customer_claim"
  $rel.ReferencedEntity  = $CustomerLogical
  $rel.ReferencingEntity = $ClaimLogical

  $create = New-Object Microsoft.Xrm.Sdk.Messages.CreateOneToManyRequest
  $create.OneToManyRelationship = $rel
  $create.Lookup = $lookup
  [void]$conn.ExecuteCrmOrganizationRequest($create)
}

# --- Publisher (owns the mm_ prefix) -----------------------------------------
Write-Host "Ensuring publisher with customization prefix '$PublisherPrefix'"
$pub = Get-CrmRecords -conn $conn -EntityLogicalName publisher `
  -FilterAttribute customizationprefix -FilterOperator eq -FilterValue $PublisherPrefix `
  -Fields publisherid -WarningAction SilentlyContinue
if ($pub.Count -eq 0) {
  $pubFields = @{
    uniquename          = 'halcourtmutual'
    friendlyname        = 'Halcourt Mutual'
    customizationprefix = $PublisherPrefix
    customizationoptionvalueprefix = 20000   # [verify] pick a free option-value prefix in target org
  }
  [void](New-CrmRecord -conn $conn -EntityLogicalName publisher -Fields $pubFields)
  Write-Host "  Created publisher (prefix $PublisherPrefix)."
} else {
  Write-Host "  Publisher with prefix $PublisherPrefix already present."
}

# --- Tables ------------------------------------------------------------------
# Customer(mm_name [primary], mm_customerid, mm_ssn, mm_dob)   <- PII: SSN + DOB
# Claim(mm_claimid [primary], mm_customer [lookup], mm_status, mm_amount, mm_adjuster)
Write-Host 'Creating Customer and Claim tables. Customer holds SSN/DOB (PII).'

$customerLogical = New-CustomTable `
  -Schema "${PublisherPrefix}_customer" -DisplayName 'Customer' -DisplayCollection 'Customers' `
  -PrimarySchema "${PublisherPrefix}_name" -PrimaryDisplay 'Name' `
  -ExtraColumns @(
    (New-StringAttr "${PublisherPrefix}_customerid" 'Customer ID' 20),
    (New-StringAttr "${PublisherPrefix}_ssn" 'SSN' 11),
    (New-DateAttr   "${PublisherPrefix}_dob" 'Date of Birth')
  )

$claimLogical = New-CustomTable `
  -Schema "${PublisherPrefix}_claim" -DisplayName 'Claim' -DisplayCollection 'Claims' `
  -PrimarySchema "${PublisherPrefix}_claimid" -PrimaryDisplay 'Claim ID' `
  -ExtraColumns @(
    (New-StringAttr "${PublisherPrefix}_status" 'Status' 50),
    (New-MoneyAttr  "${PublisherPrefix}_amount" 'Amount'),
    (New-StringAttr "${PublisherPrefix}_adjuster" 'Adjuster' 200)
  )

New-CustomerLookup -CustomerLogical $customerLogical -ClaimLogical $claimLogical `
  -LookupSchema "${PublisherPrefix}_customer" -LookupDisplay 'Customer'

# Publish customizations so the new tables/columns are usable for seeding.
Write-Host 'Publishing customizations...'
$pubAll = New-Object Microsoft.Crm.Sdk.Messages.PublishAllXmlRequest   # [verify] type namespace varies by SDK build
[void]$conn.ExecuteCrmOrganizationRequest($pubAll)

# --- Seed rows ---------------------------------------------------------------
Write-Host "Seeding Customer rows from $dataDir/customers.csv"
$custIdToRef = @{}   # CUS-xxx -> EntityReference for the Claim lookup
foreach ($row in (Import-Csv (Join-Path $dataDir 'customers.csv'))) {
  $existing = Get-CrmRecords -conn $conn -EntityLogicalName $customerLogical `
    -FilterAttribute "${PublisherPrefix}_customerid" -FilterOperator eq -FilterValue $row.mm_customerid `
    -Fields "${PublisherPrefix}_customerid" -WarningAction SilentlyContinue
  if ($existing.Count -gt 0) {
    Write-Host "  Customer $($row.mm_customerid) exists — skipping."
    $id = $existing.CrmRecords[0].("${PublisherPrefix}_customerid_Property").Value
    $custIdToRef[$row.mm_customerid] = New-CrmEntityReference -EntityLogicalName $customerLogical -Id $existing.CrmRecords[0].($customerLogical + 'id')
    continue
  }
  $fields = @{
    "${PublisherPrefix}_name"       = $row.mm_name
    "${PublisherPrefix}_customerid" = $row.mm_customerid
    "${PublisherPrefix}_ssn"        = $row.mm_ssn
    "${PublisherPrefix}_dob"        = [datetime]::Parse($row.mm_dob)
  }
  $guid = New-CrmRecord -conn $conn -EntityLogicalName $customerLogical -Fields $fields
  $custIdToRef[$row.mm_customerid] = New-CrmEntityReference -EntityLogicalName $customerLogical -Id $guid
  Write-Host "  Created customer $($row.mm_customerid) ($($row.mm_name))"
}

Write-Host "Seeding Claim rows from $dataDir/claims.csv"
foreach ($row in (Import-Csv (Join-Path $dataDir 'claims.csv'))) {
  $existing = Get-CrmRecords -conn $conn -EntityLogicalName $claimLogical `
    -FilterAttribute "${PublisherPrefix}_claimid" -FilterOperator eq -FilterValue $row.mm_claimid `
    -Fields "${PublisherPrefix}_claimid" -WarningAction SilentlyContinue
  if ($existing.Count -gt 0) { Write-Host "  Claim $($row.mm_claimid) exists — skipping."; continue }

  $fields = @{
    "${PublisherPrefix}_claimid"  = $row.mm_claimid
    "${PublisherPrefix}_status"   = $row.mm_status
    "${PublisherPrefix}_amount"   = (New-CrmMoney -Amount ([decimal]$row.mm_amount))
    "${PublisherPrefix}_adjuster" = $row.mm_adjuster           # priya.nair / sam.olsen — both real personas
  }
  if ($custIdToRef.ContainsKey($row.mm_customer)) {
    $fields["${PublisherPrefix}_customer"] = $custIdToRef[$row.mm_customer]
  } else {
    Write-Warning "  Claim $($row.mm_claimid): customer $($row.mm_customer) not found — leaving lookup empty."
  }
  [void](New-CrmRecord -conn $conn -EntityLogicalName $claimLogical -Fields $fields)
  Write-Host "  Created claim $($row.mm_claimid) (adjuster $($row.mm_adjuster))"
}

# --- The over-broad role -----------------------------------------------------
# INTENTIONAL planted problem (Scenario C / D). svc-claims gets ORGANIZATION-DEPTH (Global) read/write on
# ALL Claim and Customer rows, PII included. No row-level security. The agent's job only needs the
# requesting adjuster's own claims. Module 5 (least privilege) REPLACES this with a scoped role + RLS.
# DO NOT scope this down here — the over-grant is the exercise.
Write-Host "Granting svc-claims the over-broad Dataverse role: '$OverBroadRoleName'"

# Root business unit (role lives here so its scope is the whole org).
$bu = Get-CrmRecords -conn $conn -EntityLogicalName businessunit `
  -FilterAttribute parentbusinessunitid -FilterOperator 'null' -FilterValue $null `
  -Fields businessunitid -WarningAction SilentlyContinue
$rootBuId = $bu.CrmRecords[0].businessunitid

# Create the role (check-before-create).
$roleRec = Get-CrmRecords -conn $conn -EntityLogicalName role `
  -FilterAttribute name -FilterOperator eq -FilterValue $OverBroadRoleName `
  -Fields roleid -WarningAction SilentlyContinue
if ($roleRec.Count -gt 0) {
  $roleId = $roleRec.CrmRecords[0].roleid
  Write-Host "  Role already exists — reusing $roleId"
} else {
  $roleId = New-CrmRecord -conn $conn -EntityLogicalName role -Fields @{
    name              = $OverBroadRoleName
    businessunitid    = (New-CrmEntityReference -EntityLogicalName businessunit -Id $rootBuId)
  }
  Write-Host "  Created role $roleId"
}

# Resolve the privileges to grant at GLOBAL (organization) depth on both tables.
# Privilege records are named prv{Operation}{entitySchemaName}, e.g. prvReadmm_claim.
$ops     = @('Create','Read','Write','Append','AppendTo','Assign','Share')
$targets = @("${PublisherPrefix}_claim", "${PublisherPrefix}_customer")
$rolePrivs = New-Object System.Collections.Generic.List[Microsoft.Crm.Sdk.Messages.RolePrivilege]
foreach ($t in $targets) {
  foreach ($op in $ops) {
    $prvName = "prv$op$t"
    $prv = Get-CrmRecords -conn $conn -EntityLogicalName privilege `
      -FilterAttribute name -FilterOperator eq -FilterValue $prvName `
      -Fields privilegeid -WarningAction SilentlyContinue
    if ($prv.Count -eq 0) { Write-Warning "    Privilege $prvName not found — skipping."; continue }
    $rp = New-Object Microsoft.Crm.Sdk.Messages.RolePrivilege
    $rp.PrivilegeId = $prv.CrmRecords[0].privilegeid
    $rp.Depth       = [Microsoft.Crm.Sdk.Messages.PrivilegeDepth]::Global   # Global = read/write ALL rows, no RLS
    $rolePrivs.Add($rp)
  }
}

$addPriv = New-Object Microsoft.Crm.Sdk.Messages.AddPrivilegesRoleRequest
$addPriv.RoleId     = $roleId
$addPriv.Privileges = $rolePrivs.ToArray()
[void]$conn.ExecuteCrmOrganizationRequest($addPriv)
Write-Host "  Granted $($rolePrivs.Count) Global-depth privileges (Claim + Customer, incl. PII)."

# Assign the role to svc-claims.
$svc = Get-CrmRecords -conn $conn -EntityLogicalName systemuser `
  -FilterAttribute domainname -FilterOperator eq -FilterValue $SvcClaimsUpn `
  -Fields systemuserid -WarningAction SilentlyContinue
if ($svc.Count -eq 0) { throw "svc-claims user '$SvcClaimsUpn' not found in Claims-Test (run 01_provision_entra first)." }
$svcId = $svc.CrmRecords[0].systemuserid

$assoc = New-Object Microsoft.Xrm.Sdk.Messages.AssociateRequest
$assoc.Target        = New-Object Microsoft.Xrm.Sdk.EntityReference('systemuser', $svcId)
$assoc.RelatedEntities = New-Object Microsoft.Xrm.Sdk.EntityReferenceCollection
$assoc.RelatedEntities.Add((New-Object Microsoft.Xrm.Sdk.EntityReference('role', $roleId)))
$assoc.Relationship  = New-Object Microsoft.Xrm.Sdk.Relationship('systemuserroles_association')
try {
  [void]$conn.ExecuteCrmOrganizationRequest($assoc)
  Write-Host "  Assigned '$OverBroadRoleName' to $SvcClaimsUpn."
} catch {
  if ("$_" -match 'Cannot insert duplicate|already exists') { Write-Host "  Role already assigned to $SvcClaimsUpn." }
  else { throw }
}

Write-Host 'Phase 5 complete. svc-claims now has org-wide read/write on Claim + Customer (intentional over-grant).'
