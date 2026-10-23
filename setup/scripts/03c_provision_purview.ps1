<#
FACILITATOR-ONLY. Phase 4c - Purview for Lab 05-06 (issue #12).

Creates what 05-06 inspects and retests, and seeds it early enough for SharePoint search to index it:
  1. HR-Leadership-<estate>: a mail-enabled group (encryption rights need an address) holding Marcus Webb.
  2. Sensitivity label Confidential-PII-<estate>: ENCRYPTING, VIEW + EXTRACT for HR-Leadership-<estate> only.
     Copilot Studio can't ground on a file under an encrypting label, even for users who can open it -
     the behaviour 05-06 relies on.
  3. Label policy Halcourt-Labels-<estate>, publishing it to HR-Leadership-<estate>'s members (a label
     policy takes mailboxes only, not a Microsoft 365 group).
  4. SharePoint's sensitivity-label integration (EnableAIPIntegration), so SharePoint applies and honours it.
  5. Leadership/2026-comp-bands-labeled.xlsx in HR-Benefits-<estate>: the comp bands plus a marker row
     (LABELLED-COPY-<estate>) so a retest can tell which copy answered, labelled Confidential-PII-<estate>.
     The original Leadership/2026-comp-bands.xlsx is left UNLABELLED - Exercise 04 needs it reachable.
  6. Checks: the SSN sensitive information type exists; the copy carries the label; search sees the marker.

Auth, all non-interactive, one app: halcourt-lab-compliance (certificate in setup/lab-compliance-app.local.*,
gitignored), holding Compliance Administrator + Exchange.ManageAsApp (Security & Compliance PowerShell),
Graph Files.ReadWrite.All (copy + label assignment) and SharePoint Sites.FullControl.All (tenant setting).
assignSensitivityLabel is a METERED Graph API: the app is linked to a Microsoft.GraphServices/accounts
billing resource (rg-halcourt-graph-billing). Group creation uses the az admin sign-in, like 01.
Why not the az token for Purview: Security & Compliance PowerShell refuses it (UnAuthorized), and
Connect-IPPSSession -Certificate fails inside the module on Linux (NewEXOModule null reference), so this
script mints the app-only token itself and passes -AccessToken. Measured 2026-10-18.

ASCII only.
#>
param(
  [string]$Estate       = $env:HALCOURT_ESTATE,
  [string]$AppConfig    = (Join-Path (Split-Path -Parent $PSScriptRoot) 'lab-compliance-app.local.json'),
  [string]$Pfx          = (Join-Path (Split-Path -Parent $PSScriptRoot) 'lab-compliance-app.local.pfx'),
  [switch]$SkipSearchCheck,
  [switch]$Remove                 # teardown: delete this estate's label policy, then its label (Phase 9)
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_estate.ps1')
if (-not $Estate) { throw 'Pass -Estate or set HALCOURT_ESTATE.' }

# ---- 0. the lab's app-only identity (made once per tenant; idempotent) -------------------------------
. (Join-Path $PSScriptRoot '_labapp.ps1')
# Teardown must not create or rotate the shared app, its certificate or its metered billing resource: -Remove
# only signs in with the app that already exists.
if ($Remove) {
  if (-not ((Test-Path $AppConfig) -and (Test-Path $Pfx))) { throw "No lab app certificate here ($AppConfig) - nothing to sign in with for -Remove." }
} else { Ensure-LabApp }

$cfg      = Get-Content $AppConfig -Raw | ConvertFrom-Json
$domain   = $cfg.organization                 # the INITIAL *.onmicrosoft.com: SharePoint host, compliance sign-in
# Persona UPNs use the tenant's DEFAULT domain, as 01 and 06 build them; it differs on a custom-domain tenant.
$personaDomain = az rest --method GET --url 'https://graph.microsoft.com/v1.0/organization?$select=verifiedDomains' --query "value[0].verifiedDomains[?isDefault].name | [0]" -o tsv
$tenantId = az account show --query tenantId -o tsv
$tenant   = $domain.Split('.')[0]

$groupName = Get-EstateName 'HR-Leadership' $Estate
$labelName = Get-EstateName 'Confidential-PII' $Estate
$labelDisp = Get-EstateDisplayName 'Confidential-PII' $Estate
$policy    = Get-EstateName 'Halcourt-Labels' $Estate
$siteAlias = Get-EstateName 'HR-Benefits' $Estate
$marker    = "LABELLED-COPY-$Estate"
$copyName  = '2026-comp-bands-labeled.xlsx'

# Security & Compliance PowerShell, app-only: the az token is refused and -Certificate fails on Linux
# (NewEXOModule), so mint the token and pass -AccessToken.
function Connect-Compliance {
  Import-Module ExchangeOnlineManagement
  Connect-IPPSSession -AccessToken (Get-AppToken 'https://ps.compliance.protection.outlook.com') -Organization $domain -ShowBanner:$false
}
function Graph([string]$Method, [string]$Path, $Body, [string]$ContentType = 'application/json') {
  $h = @{ Authorization = "Bearer $script:graphToken" }
  $uri = if ($Path -like 'https://*') { $Path } else { "https://graph.microsoft.com/v1.0/$Path" }
  if ($null -eq $Body) { return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h }
  if ($Body -is [byte[]]) { return Invoke-RestMethod -Method $Method -Uri $uri -Headers $h -Body $Body -ContentType $ContentType }
  Invoke-RestMethod -Method $Method -Uri $uri -Headers $h -Body ($Body | ConvertTo-Json -Depth 8) -ContentType $ContentType
}

# ---- teardown (-Remove): policy first, then label ------------------------------------------------------
# Purview won't delete a label a policy still publishes, and a removed policy takes a while to withdraw, so
# the label removal retries and a timeout just asks for a re-run. The group HR-Leadership-<estate> goes with
# 99 -RemovePersonas (every *-<estate> group); the labelled copy goes with the HR-Benefits site.
if ($Remove) {
  Connect-Compliance
  try {
    $pol = Get-LabelPolicy -Identity $policy -ErrorAction SilentlyContinue
    if (-not $pol) { Write-Host "Label policy $policy not found" }
    elseif ("$($pol.Mode)" -eq 'PendingDeletion') { Write-Host "Label policy $policy already being withdrawn" }
    else { Remove-LabelPolicy -Identity $policy -Confirm:$false; Write-Host "Label policy $policy removed" }
    if (Get-Label -Identity $labelName -ErrorAction SilentlyContinue) {
      $gone = $false
      for ($i = 1; $i -le 10 -and -not $gone; $i++) {
        try { Remove-Label -Identity $labelName -Confirm:$false -ErrorAction Stop; $gone = $true }
        catch {
          $msg = $_.Exception.Message.Split([char]10)[0]
          # Only "still published / policy pending" is worth waiting out; anything else won't change.
          if ($msg -notmatch 'publish|polic|pending') { throw }
          Write-Host "   label still published ($msg)"
          if ($i -lt 10) { Write-Host '   retrying in 60s'; Start-Sleep 60 }
        }
      }
      Write-Host $(if ($gone) { "Label $labelName removed" } else { "Label $labelName NOT removed yet - re-run with -Remove later" })
    } else { Write-Host "Label $labelName not found" }
  } finally { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null }
  return
}

# ---- 1. the group -------------------------------------------------------------------------------------
Write-Host "1. Group $groupName"
$marcusUpn = "$(Get-EstateAlias 'marcus.webb' $Estate)@$personaDomain"
$marcus = az ad user show --id $marcusUpn --query id -o tsv
if (-not $marcus) { throw "$marcusUpn not found - run Phase 2 (01) for estate '$Estate' first." }
$g = az rest --method get --url "https://graph.microsoft.com/v1.0/groups?`$filter=displayName eq '$groupName'&`$select=id,mail" --query 'value[0]' -o json | ConvertFrom-Json
if (-not $g) {
  $body = @{ displayName = $groupName; mailNickname = $groupName; mailEnabled = $true; securityEnabled = $true
             groupTypes = @('Unified'); visibility = 'Private'
             description = "Halcourt lab (estate $Estate): HR leadership - the only principals $labelName grants VIEW/EXTRACT."
             'members@odata.bind' = @("https://graph.microsoft.com/v1.0/users/$marcus")
             'owners@odata.bind'  = @("https://graph.microsoft.com/v1.0/users/$marcus") } | ConvertTo-Json -Compress
  $tmp = New-TemporaryFile; Set-Content $tmp $body
  $g = az rest --method post --url 'https://graph.microsoft.com/v1.0/groups' --body "@$tmp" --query '{id:id,mail:mail}' -o json | ConvertFrom-Json
  Remove-Item $tmp; Write-Host "   created ($($g.mail))"
} else { Write-Host "   exists ($($g.mail))" }

# ---- 2-3. label and policy (Security & Compliance PowerShell, app-only) ------------------------------------
Connect-Compliance
Write-Host "2. Label $labelName"
$label = Get-Label -Identity $labelName -ErrorAction SilentlyContinue
if (-not $label) {
  $label = New-Label -Name $labelName -DisplayName $labelDisp -ContentType 'File, Email' `
    -Tooltip 'Halcourt PII and compensation. Encrypted: HR leadership may view and extract; nobody else can open it.' `
    -EncryptionEnabled $true -EncryptionProtectionType Template `
    -EncryptionRightsDefinitions "$($g.mail):VIEW,EXTRACT" -EncryptionContentExpiredOnDateInDaysOrNever Never
  Write-Host "   created ($($label.ImmutableId))"
} else { Write-Host "   exists ($($label.ImmutableId))" }
Write-Host "3. Label policy $policy"
# A label policy's Exchange location takes mailboxes only: the group (a Microsoft 365 group, Exchange type
# GroupMailbox) is refused - "Only mailboxes are supported" - however long it has existed. So the policy is
# published to the group's MEMBERS; the label's encryption rights name the group itself (step 2), and those
# are what 05-06 depends on. (An earlier version blamed the refusal on replication lag and never succeeded.)
$members = @(az rest --method get --url "https://graph.microsoft.com/v1.0/groups/$($g.id)/members/microsoft.graph.user?`$select=userPrincipalName" --query 'value[].userPrincipalName' -o tsv | Where-Object { $_ })
if (-not $members) { $members = @($marcusUpn) }
if (-not (Get-LabelPolicy -Identity $policy -ErrorAction SilentlyContinue)) {
  New-LabelPolicy -Name $policy -Labels $labelName -ExchangeLocation $members | Out-Null
  Write-Host "   created (published to $($members -join ', '))"
} else {
  $have = @((Get-LabelPolicy -Identity $policy).ExchangeLocation.Name)
  $add = @($members | Where-Object { $_ -notin $have })
  if ($add) { Set-LabelPolicy -Identity $policy -AddExchangeLocation $add | Out-Null; Write-Host "   exists; added $($add -join ', ')" }
  else { Write-Host "   exists (published to $($members -join ', '))" }
}
$ssn = Get-DlpSensitiveInformationType | Where-Object Name -match '^U\.S\. Social Security Number' | Select-Object -First 1
Write-Host "   SSN sensitive information type: $(if ($ssn) { $ssn.Name } else { 'MISSING' })"

# ---- 4. SharePoint honours labels -------------------------------------------------------------------
Write-Host '4. SharePoint sensitivity-label integration'
$spAdmin = "https://$tenant-admin.sharepoint.com"
$spTok = Get-AppToken $spAdmin
$cur = Invoke-RestMethod -Uri "$spAdmin/_api/SPO.Tenant?`$select=EnableAIPIntegration" -Headers @{ Authorization = "Bearer $spTok"; Accept = 'application/json' }
if (-not $cur.EnableAIPIntegration) {
  Invoke-RestMethod -Method POST -Uri "$spAdmin/_api/SPO.Tenant" -ContentType 'application/json' -Body '{"EnableAIPIntegration":true}' `
    -Headers @{ Authorization = "Bearer $spTok"; Accept = 'application/json'; 'X-HTTP-Method' = 'MERGE'; 'IF-MATCH' = '*' } | Out-Null
  Write-Host '   enabled'
} else { Write-Host '   already on' }

# ---- 5. the labelled copy ------------------------------------------------------------------------------
Write-Host "5. $copyName"
$script:graphToken = Get-AppToken 'https://graph.microsoft.com'
$site  = Graph GET "sites/$tenant.sharepoint.com:/sites/$($siteAlias)"
$drive = Graph GET "sites/$($site.id)/drive"
$item  = $null
try { $item = Graph GET "drives/$($drive.id)/root:/Leadership/$($copyName)" } catch { }
if (-not $item) {
  # The same generator 03 uses for the original, loaded from 03 itself so the two can't drift.
  $ast = [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot '03_provision_sharepoint.ps1'), [ref]$null, [ref]$null)
  $fn  = $ast.Find({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $args[0].Name -eq 'New-MinimalXlsxFromCsv' }, $true)
  . ([scriptblock]::Create($fn.Extent.Text))
  $work = Join-Path ([IO.Path]::GetTempPath()) "purview-$Estate"; New-Item -ItemType Directory -Force $work | Out-Null
  $csv  = Join-Path $work 'labeled.csv'
  $rows = @(Import-Csv (Join-Path (Split-Path -Parent $PSScriptRoot) 'data/leadership-comp.csv'))
  $marked = $rows[0].psobject.Copy(); foreach ($p in $marked.psobject.Properties) { $p.Value = '' }
  $marked.psobject.Properties | Select-Object -First 1 | ForEach-Object { $_.Value = "$marker (labelled copy - not the original)" }
  ($rows + $marked) | Export-Csv $csv -NoTypeInformation -Encoding UTF8
  New-MinimalXlsxFromCsv -CsvPath $csv -OutPath (Join-Path $work $copyName) -SheetName '2026 Comp Bands'
  $item = Graph PUT "drives/$($drive.id)/root:/Leadership/$($copyName):/content" ([IO.File]::ReadAllBytes((Join-Path $work $copyName))) `
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  Write-Host "   uploaded ($($item.id))"
} else { Write-Host "   exists ($($item.id))" }
$have = (Graph POST "drives/$($drive.id)/items/$($item.id)/extractSensitivityLabels" @{}).labels
if (-not ($have | Where-Object sensitivityLabelId -eq $label.ImmutableId)) {
  try {
    Graph POST "drives/$($drive.id)/items/$($item.id)/assignSensitivityLabel" @{
      sensitivityLabelId = "$($label.ImmutableId)"; assignmentMethod = 'privileged'
      justificationText  = 'Halcourt lab seed for Lab 05-06 (issue #12)' } | Out-Null
    Write-Host "   label assignment requested (async)"
  } catch {
    # A new label (and its policy) reaches SharePoint late - often about an hour, up to 24. Until then the
    # assignment says labelNotFound. Everything above is idempotent: rerun this script later.
    if ("$_" -match 'labelNotFound') {
      Write-Host "   label not yet replicated to SharePoint (labelNotFound) - rerun later; the delivery needs it indexed"
      Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null; return
    }
    throw
  }
} else { Write-Host '   already labelled' }

# ---- 6. checks ------------------------------------------------------------------------------------
Write-Host '6. Checks'
for ($i = 0; $i -lt 12; $i++) {
  $have = (Graph POST "drives/$($drive.id)/items/$($item.id)/extractSensitivityLabels" @{}).labels
  if ($have | Where-Object sensitivityLabelId -eq $label.ImmutableId) { break }
  Start-Sleep 10
}
Write-Host "   copy labelled: $([bool]($have | Where-Object sensitivityLabelId -eq $label.ImmutableId))"
try {
  $orig = Graph GET "drives/$($drive.id)/root:/Leadership/2026-comp-bands.xlsx"
  $ol = (Graph POST "drives/$($drive.id)/items/$($orig.id)/extractSensitivityLabels" @{}).labels
  Write-Host "   original unlabelled: $(-not $ol)"
} catch { Write-Host '   original: NOT FOUND (run 03 first)' }
if (-not $SkipSearchCheck) {
  $q = @{ requests = @(@{ entityTypes = @('driveItem'); query = @{ queryString = "`"$marker`"" }; region = 'NAM' }) }
  $hits = (Graph POST 'search/query' $q).value[0].hitsContainers[0].total
  Write-Host "   search sees the marker: $([bool]$hits) ($hits hit(s)) - indexing can take hours; rerun with nothing to create to recheck"
}
Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
