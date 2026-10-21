<#
FACILITATOR-ONLY. Phase 8b, part three: Purview role groups for the attendees.

05-07 KT04 opens a chat's transcript in DSPM for AI. Global Reader (the access model) shows each interaction
but not its text - "We couldn't retrieve this prompt and response" - until the reader is in Purview's
Data Security AI Content Viewers role group (verified as student03, 2026-10-20). This puts the attendees in it:
the Lab-Students-<estate> group 07 maintains, or - if Purview won't take that group - each of its members, so
re-run it after 07 adds attendees.

Role-group membership needs Organization Management, which the lab app can't hold, so this signs in as the
admin with one device-code approval (_auth.ps1, Connect-LabComplianceAdmin). Safe to re-run; -Remove takes the
attendees out again after the delivery. Isolated training tenants only. ASCII only.

  pwsh setup/scripts/07c_provision_purview_roles.ps1            # estate from HALCOURT_ESTATE
  pwsh setup/scripts/07c_provision_purview_roles.ps1 -Remove
#>
param(
  [string]$Estate = $env:HALCOURT_ESTATE,
  [string[]]$RoleGroups = @('DataSecurityAIContentViewers'),
  [switch]$Remove
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_estate.ps1')          # also the tenant guard
$Estate = Resolve-Estate $Estate
. (Join-Path $PSScriptRoot '_auth.ps1')

$group  = Get-EstateName 'Lab-Students' $Estate
$domain = az rest --method GET --url 'https://graph.microsoft.com/v1.0/organization?$select=verifiedDomains' --query "value[0].verifiedDomains[?isInitial].name | [0]" -o tsv
$g = az ad group show --group $group --query '{id:id,name:displayName}' -o json 2>$null | ConvertFrom-Json
if (-not $g) { throw "Entra group $group not found - run 07_provision_lab_users.ps1 first." }
$members = @(az ad group member list --group $g.id --query "[?'@odata.type'=='#microsoft.graph.user'].userPrincipalName" -o tsv)

Connect-LabComplianceAdmin -Organization $domain
foreach ($rg in $RoleGroups) {
  $have = @(Get-RoleGroupMember -Identity $rg | ForEach-Object { "$($_.Name)"; "$($_.WindowsLiveID)"; "$($_.ExternalDirectoryObjectId)" })
  if ($Remove) {
    foreach ($m in @($g.id) + $members) {
      if ($m -in $have) { Remove-RoleGroupMember -Identity $rg -Member $m -Confirm:$false; Write-Host "  ${rg}: removed $m" }
    }
    continue
  }
  if ($g.id -in $have -or $g.name -in $have) { Write-Host "  ${rg}: $($g.name) already a member"; continue }
  try {
    Add-RoleGroupMember -Identity $rg -Member $g.id -ErrorAction Stop
    Write-Host "  ${rg}: added the group $($g.name)"
  } catch {
    # Purview role groups take users and mail-enabled groups; a plain security group may be refused.
    Write-Host "  ${rg}: the group was refused ($($_.Exception.Message.Split([char]10)[0])) - adding its $($members.Count) member(s)"
    foreach ($m in $members) {
      if ($m -in $have) { continue }
      Add-RoleGroupMember -Identity $rg -Member $m -ErrorAction Stop; Write-Host "    added $m"
    }
  }
  Write-Host "  ${rg} now: $((@(Get-RoleGroupMember -Identity $rg | ForEach-Object Name)) -join ', ')"
}
Disconnect-ExchangeOnline -Confirm:$false | Out-Null
