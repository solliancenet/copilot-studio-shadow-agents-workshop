<#
FACILITATOR-ONLY. Phase 8b, part two: the facilitator's DEMONSTRATION account for Exercise 05.

Exercise 05 is demonstrated (decided 2026-10-19): the facilitator applies each control to the shared estate,
the room retests, the estate is restored (09_ex05_demo_state.ps1). This account is what those demonstrations
run as - on the projector and in the recorded walkthroughs - so the screen shows a facilitator, never a
student, and the facilitator's own tenant-admin account stays off the projector.

  facilitator.<estate>@<domain>  "Lab Facilitator (<estate>)"
    Power Platform Administrator   standing - data policies, environment roles, Dataverse self-elevation
    AI Administrator               PIM-ELIGIBLE - 05-05: Block an agent in Agent 365
    Security Administrator         PIM-ELIGIBLE - 05-07: Defender real-time protection. It can also edit
                                   Conditional Access, which is why it is eligible, not held: activate it for
                                   the one step, time-boxed, and let it lapse.

The admin roles put it under CA-Require-MFA-Admins: it enrols MFA at first sign-in like any admin. No licence
(every step is an admin-portal action). Its password goes to setup/lab-facilitator-<estate>.local.csv
(gitignored). Safe to re-run; -Destroy removes the account. Isolated training tenants only.

  pwsh setup/scripts/07b_provision_facilitator.ps1            # estate from HALCOURT_ESTATE
  pwsh setup/scripts/07b_provision_facilitator.ps1 -Destroy
#>
param(
  [string]$Estate = $env:HALCOURT_ESTATE,
  [string]$DomainSuffix,
  [switch]$Destroy
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_estate.ps1')          # also the tenant guard
$Estate = Resolve-Estate $Estate

$script:Tokens = @{}
function Get-AdminToken([string]$r) { if (-not $script:Tokens[$r]) { $script:Tokens[$r] = az account get-access-token --resource $r --query accessToken -o tsv }; $script:Tokens[$r] }
function Graph([string]$m, [string]$path, $body) {
  $h = @{ Authorization = "Bearer $(Get-AdminToken 'https://graph.microsoft.com/')" }
  $uri = "https://graph.microsoft.com/v1.0/$path"
  if ($null -ne $body) { Invoke-RestMethod -Method $m -Uri $uri -Headers $h -ContentType 'application/json' -Body ($body | ConvertTo-Json -Depth 20) }
  else                 { Invoke-RestMethod -Method $m -Uri $uri -Headers $h }
}

$org = (Graph GET 'organization?$select=verifiedDomains,countryLetterCode').value[0]
if (-not $DomainSuffix) { $DomainSuffix = ($org.verifiedDomains | Where-Object { $_.isDefault } | Select-Object -First 1).name }
$upn  = "$(Get-EstateAlias 'facilitator' $Estate)@$DomainSuffix"
$name = Get-EstateDisplayName 'Lab Facilitator' $Estate
$csv  = Join-Path (Split-Path $PSScriptRoot -Parent) "lab-facilitator-$Estate.local.csv"

$existing = $null
try { $existing = Graph GET "users/$([uri]::EscapeDataString($upn))?`$select=id,accountEnabled" } catch { $existing = $null }

if ($Destroy) {
  if ($existing) { Graph DELETE "users/$($existing.id)" | Out-Null; Write-Host "Deleted $upn" } else { Write-Host "$upn does not exist" }
  if (Test-Path $csv) { Remove-Item $csv; Write-Host "Removed $csv" }
  return
}

# ---- the account ---------------------------------------------------------------------------------------
if ($existing) {
  Write-Host "Exists:  $upn"
  $id = $existing.id
} else {
  # Same character rules as the attendee passwords (07): typed by hand, so no O/0, I/l/1, S/5.
  $upper = 'ABCDEFGHJKMNPQRTUVWXYZ'; $lower = 'abcdefghjkmnpqrtuvwxyz'; $digit = '2346789'; $sym = '!@#$%*-+='
  $pick  = { param($set, $n) -join (1..$n | ForEach-Object { $set[(Get-Random -Maximum $set.Length)] }) }
  $pw = -join (((& $pick $upper 2) + (& $pick $lower 2) + (& $pick $digit 2) + (& $pick $sym 2) + (& $pick ($upper + $lower + $digit) 8)).ToCharArray() | Sort-Object { Get-Random })
  $u = Graph POST 'users' @{
    accountEnabled = $true; displayName = $name; mailNickname = (Get-EstateAlias 'facilitator' $Estate).Replace('.', '')
    userPrincipalName = $upn; usageLocation = $(if ($org.countryLetterCode) { $org.countryLetterCode } else { 'US' })
    passwordProfile = @{ password = $pw; forceChangePasswordNextSignIn = $false }
  }
  $id = $u.id
  [pscustomobject]@{ upn = $upn; password = $pw } | Export-Csv -NoTypeInformation $csv
  Write-Host "Created: $upn  (password -> $csv, gitignored)"
}

# ---- standing role: Power Platform Administrator -------------------------------------------------------
$templates = (Graph GET 'directoryRoleTemplates?$select=id,displayName').value
function TemplateId([string]$n) { ($templates | Where-Object displayName -eq $n | Select-Object -First 1).id }
$ppa = TemplateId 'Power Platform Administrator'
$role = $null; try { $role = Graph GET "directoryRoles(roleTemplateId='$ppa')" } catch { }
if (-not $role.id) { $role = Graph POST 'directoryRoles' @{ roleTemplateId = $ppa } }
try { Graph POST "directoryRoles/$($role.id)/members/`$ref" @{ '@odata.id' = "https://graph.microsoft.com/v1.0/directoryObjects/$id" } | Out-Null; Write-Host '  Power Platform Administrator: assigned' }
catch { if ("$_" -match 'already exist') { Write-Host '  Power Platform Administrator: already assigned' } else { throw } }

# ---- eligible roles, through the kit's app-only identity (the az token lacks the PIM scopes) -------------
. (Join-Path $PSScriptRoot '_labapp.ps1'); Ensure-LabApp -NoBilling
$pim = Get-AppToken 'https://graph.microsoft.com'
foreach ($n in 'AI Administrator', 'Security Administrator') {
  $b = @{ action = 'adminAssign'; principalId = $id; roleDefinitionId = (TemplateId $n); directoryScopeId = '/'
          justification = 'Halcourt lab: Exercise 05 facilitator demonstrations, activated per step'
          scheduleInfo = @{ startDateTime = (Get-Date).ToUniversalTime().ToString('o'); expiration = @{ type = 'noExpiration' } } }
  for ($i = 0; ; $i++) {
    try {
      Invoke-RestMethod -Method POST -Uri 'https://graph.microsoft.com/v1.0/roleManagement/directory/roleEligibilityScheduleRequests' `
        -Headers @{ Authorization = "Bearer $pim" } -ContentType 'application/json' -Body ($b | ConvertTo-Json -Depth 5) | Out-Null
      Write-Host "  $n`: eligible"; break
    } catch {
      if ("$_" -match 'RoleAssignmentExists|already exists') { Write-Host "  $n`: already eligible"; break }
      if ($i -ge 5 -or "$_" -notmatch '403|Forbidden') { throw }
      Start-Sleep 60; $pim = Get-AppToken 'https://graph.microsoft.com'   # a fresh grant still propagating
    }
  }
}
Write-Host "`nSign in once as $upn to enrol MFA (CA-Require-MFA-Admins). Activate AI Administrator / Security"
Write-Host "Administrator in Entra > Privileged Identity Management > My roles only for the step that needs it."
