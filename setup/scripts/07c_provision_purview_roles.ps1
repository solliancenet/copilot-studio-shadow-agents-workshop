<#
FACILITATOR-ONLY. Phase 8b, part three: Purview role groups for the attendees.

05-07 KT04 opens a chat's transcript in DSPM for AI. Global Reader (the access model) shows each interaction
but not its text - "We couldn't retrieve this prompt and response" - unless the reader is in Purview's
Data Security AI Content Viewers role group (Learn: Permissions for DSPM for AI; the narrower of the two roles
that allow it - Content Explorer Content Viewer would also open classified files such as the comp bands).

The attendees are 07's lab accounts, <prefix><NN>.<estate>@ (student01.mgray@...), added one by one - re-run
after 07 adds attendees. Not Lab-Students-<estate>: that is 07's Conditional Access exclusion group and holds
only accounts from an -ExcludeFromAdminMfa run; an earlier version of this script added it, so it is removed.

Role-group membership needs Organization Management, which the lab app can't hold, so this signs in as the
admin with one device-code approval (_auth.ps1, Connect-LabComplianceAdmin). Safe to re-run; -Remove takes the
attendees out again after the delivery. Isolated training tenants only. ASCII only.

  pwsh setup/scripts/07c_provision_purview_roles.ps1            # estate from HALCOURT_ESTATE
  pwsh setup/scripts/07c_provision_purview_roles.ps1 -Remove
#>
param(
  [string]$Estate = $env:HALCOURT_ESTATE,
  [string]$Prefix = 'student',                       # 07's -Prefix
  [string[]]$RoleGroups = @('DataSecurityAIContentViewers'),
  [switch]$Remove
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_estate.ps1')          # also the tenant guard
$Estate = Resolve-Estate $Estate
. (Join-Path $PSScriptRoot '_auth.ps1')

$domain = az rest --method GET --url 'https://graph.microsoft.com/v1.0/organization?$select=verifiedDomains' --query "value[0].verifiedDomains[?isInitial].name | [0]" -o tsv
$rx = "^$([regex]::Escape($Prefix))\d+\.$([regex]::Escape($Estate))@"
$users = @(az ad user list --filter "startswith(userPrincipalName,'$Prefix')" --query "[].{upn:userPrincipalName,name:displayName}" -o json | ConvertFrom-Json | Where-Object { $_.upn -match $rx } | Sort-Object upn)
$attendees = @($users.upn)
if (-not $attendees -and -not $Remove) { throw "No $Prefix<NN>.$Estate accounts - run 07_provision_lab_users.ps1 first." }
Write-Host "Attendees ($($attendees.Count)): $($attendees -join ', ')"
$legacyGroup = Get-EstateName 'Lab-Students' $Estate

Connect-LabComplianceAdmin -Organization $domain
foreach ($rg in $RoleGroups) {
  # Purview returns members by display name ("Lab Student 01 (mgray)") and no object id (seen live), so
  # membership is matched on the Entra display name - unique per lab account (07 builds it from the estate).
  $have = @(Get-RoleGroupMember -Identity $rg)
  $names = @($have | ForEach-Object { "$($_.Name)"; "$($_.DisplayName)" } | Where-Object { $_ })
  if ($have | Where-Object { $_.Name -eq $legacyGroup -or $_.DisplayName -eq $legacyGroup }) {
    Remove-RoleGroupMember -Identity $rg -Member $legacyGroup -Confirm:$false; Write-Host "  ${rg}: removed $legacyGroup (CA-exclusion group, not the attendees)"
  }
  foreach ($u in $users) {
    $present = $u.name -in $names
    if ($Remove) {
      if (-not $present) { continue }
      Remove-RoleGroupMember -Identity $rg -Member $u.upn -Confirm:$false; Write-Host "  ${rg}: removed $($u.upn)"
    } elseif (-not $present) {
      try { Add-RoleGroupMember -Identity $rg -Member $u.upn -ErrorAction Stop; Write-Host "  ${rg}: added $($u.upn)" }
      catch { if ("$_" -match 'MemberAlreadyExists') { Write-Host "  ${rg}: $($u.upn) already a member" } else { throw } }
    }
  }
  # Verify, rather than trust the calls: every attendee present after an add, none after -Remove.
  $after = @(Get-RoleGroupMember -Identity $rg | ForEach-Object { "$($_.Name)"; "$($_.DisplayName)" } | Where-Object { $_ })
  $wrong = @($users | Where-Object { ($_.name -in $after) -eq [bool]$Remove })
  Write-Host "  ${rg} now: $((@(Get-RoleGroupMember -Identity $rg | ForEach-Object Name)) -join ', ')"
  if ($wrong) { throw "${rg}: $(if ($Remove) { 'still holds' } else { 'is missing' }) $(($wrong.upn) -join ', ')" }
}
Disconnect-ExchangeOnline -Confirm:$false | Out-Null
