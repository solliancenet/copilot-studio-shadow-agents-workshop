<#
FACILITATOR-ONLY. Exercise 05 / Task 05-03 demonstration: replace svc-claims' over-broad Dataverse role with a
scoped one and a fixed data subset - in one step, so it is the same every delivery.

The lab page (05-03 Key Task 02) has the portal steps; the room watches the RESULT in the Power Platform admin
center (svc-claims' roles; the new role's Claim and Customer rows), then retests Scenarios C and D. Snapshot
first and restore after with 09_ex05_demo_state.ps1 -Control ClaimsRoles (roles, the new role and the record
owners all go back):

  pwsh setup/scripts/09_ex05_demo_state.ps1 -Action Snapshot -Control ClaimsRoles
  pwsh setup/scripts/09b_ex05_scoped_claims_role.ps1
  # ... the room retests C and D ...
  pwsh setup/scripts/09_ex05_demo_state.ps1 -Action Restore -Control ClaimsRoles

What it does in Claims-Test-<estate>:
  1. creates "Claims Adjuster (scoped) - <estate>": Read on mm_claim and mm_customer at USER depth, nothing else;
  2. gives svc-claims that role and the built-in Basic User (it needs Basic User to call Dataverse at all);
  3. removes "svc-claims Dataverse Full Access" (the organization-wide read/write from Phase 5);
  4. the fixed subset: makes svc-claims the owner of -SubsetSize claims and their customers. User depth reads
     only what svc-claims owns, so the agent sees exactly those.
Isolated training tenants only. ASCII only.
#>
param(
  [string]$Estate = $env:HALCOURT_ESTATE,
  [int]$SubsetSize = 2
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_estate.ps1')          # also the tenant guard
$Estate = Resolve-Estate $Estate
if (-not (Test-Path (Join-Path (Split-Path $PSScriptRoot -Parent) "ex05-state/$Estate/claims-roles.json"))) {
  throw "No ClaimsRoles snapshot - run 09_ex05_demo_state.ps1 -Action Snapshot -Control ClaimsRoles first, or the demonstration can't be undone."
}

$PP = 'https://service.powerapps.com/'
$script:Tokens = @{}
function Tok([string]$r) { if (-not $script:Tokens[$r]) { $script:Tokens[$r] = az account get-access-token --resource $r --query accessToken -o tsv }; $script:Tokens[$r] }
$envs = (Invoke-RestMethod -Uri 'https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2021-04-01' -Headers @{ Authorization = "Bearer $(Tok $PP)" }).value
$e = $envs | Where-Object { $_.properties.displayName -eq (Get-EstateName 'Claims-Test' $Estate) } | Select-Object -First 1
if (-not $e) { throw "Claims-Test-$Estate not found." }
$Org = $e.properties.linkedEnvironmentMetadata.instanceUrl.TrimEnd('/')
function Dv([string]$Method, [string]$Path, $Body) {
  $h = @{ Authorization = "Bearer $(Tok $Org)" }
  $u = "$Org/api/data/v9.2/$Path"
  if ($null -eq $Body) { Invoke-RestMethod -Method $Method -Uri $u -Headers $h }
  else { Invoke-RestMethod -Method $Method -Uri $u -Headers $h -ContentType 'application/json' -Body ($Body | ConvertTo-Json -Depth 10) }
}

$bu = (Dv GET 'businessunits?$select=businessunitid&$filter=parentbusinessunitid eq null').value[0].businessunitid
$su = (Dv GET "systemusers?`$select=systemuserid&`$filter=startswith(domainname,'$(Get-EstateAlias 'svc-claims' $Estate)@')").value[0].systemuserid
if (-not $su) { throw 'svc-claims not found in Claims-Test.' }
function RoleId([string]$Name) { (Dv GET "roles?`$select=roleid&`$filter=name eq '$Name' and _businessunitid_value eq $bu").value[0].roleid }

# 1. the scoped role
$roleName = "Claims Adjuster (scoped) - $Estate"
$rid = RoleId $roleName
if (-not $rid) {
  Dv POST 'roles' @{ name = $roleName; 'businessunitid@odata.bind' = "/businessunits($bu)" } | Out-Null
  $rid = RoleId $roleName
}
$privs = foreach ($p in 'prvReadmm_claim', 'prvReadmm_customer') {
  @{ PrivilegeId = (Dv GET "privileges?`$select=privilegeid&`$filter=name eq '$p'").value[0].privilegeid; Depth = 'Basic' }
}
Dv POST "roles($rid)/Microsoft.Dynamics.CRM.AddPrivilegesRole" @{ Privileges = @($privs) } | Out-Null
Write-Host "1. role '$roleName': Read on Claim and Customer at User depth"

# 2-3. svc-claims: scoped role + Basic User in, the full-access role out
$have = @((Dv GET "systemusers($su)/systemuserroles_association?`$select=roleid,name").value)
foreach ($r in @($rid, (RoleId 'Basic User'))) {
  if ($r -notin $have.roleid) { Dv POST "systemusers($su)/systemuserroles_association/`$ref" @{ '@odata.id' = "$Org/api/data/v9.2/roles($r)" } | Out-Null }
}
foreach ($r in $have | Where-Object { $_.name -like 'svc-claims Dataverse Full Access*' }) {
  Dv DELETE "systemusers($su)/systemuserroles_association($($r.roleid))/`$ref" | Out-Null
}
Write-Host ("2. svc-claims now holds: " + (((Dv GET "systemusers($su)/systemuserroles_association?`$select=name").value | ForEach-Object name) -join ', '))

# 4. the fixed subset: svc-claims owns N claims and their customers
$claims = @((Dv GET "mm_claims?`$select=mm_claimid,_mm_customer_value&`$orderby=createdon&`$top=$SubsetSize").value)
# A new owner must hold read on the table, and Dataverse can take a while to see a role assigned seconds ago
# (0x80040299 "Principal user ... is missing prvReadmm_claim privilege"): retry rather than fail.
function Set-Owner([string]$Path) {
  for ($i = 0; ; $i++) {
    try { Dv PATCH $Path @{ 'ownerid@odata.bind' = "/systemusers($su)" } | Out-Null; return }
    catch { if ($i -ge 8 -or "$_" -notmatch '0x80040299|is missing') { throw }; Start-Sleep 15 }
  }
}
foreach ($c in $claims) {
  Set-Owner "mm_claims($($c.mm_claimid))"
  if ($c._mm_customer_value) { Set-Owner "mm_customers($($c._mm_customer_value))" }
}
Write-Host "3. fixed subset: svc-claims owns $($claims.Count) claim(s) and their customer(s)"
