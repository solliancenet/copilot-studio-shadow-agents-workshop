<#
FACILITATOR-ONLY. The four values every estate's agents take from the ONE shared Phase 1 deployment
(reference/adr/0005-shared-azure-deployment.md): POLICY_API_FQDN, POLICY_API_KEY, UNDERWRITING_MCP_FQDN,
MCP_BEARER. Dot-source it, then call Get-LabEndpoints.

Where they come from, first match wins:
  1. setup/lab-endpoints.local.json (gitignored) - the file the deployment's owner hands every facilitator;
  2. `azd env get-values` - the owner's own selected azd environment, for the owner's own builds.

The owner writes the file once after `azd up` and shares it out of band (it holds two lab secrets):
  pwsh -c '. setup/scripts/_lab_endpoints.ps1; Save-LabEndpoints'
ASCII only.
#>
if (-not $LabEndpointsFile) { $LabEndpointsFile = Join-Path (Split-Path -Parent $PSScriptRoot) 'lab-endpoints.local.json' }
$LabEndpointKeys = @('POLICY_API_FQDN', 'POLICY_API_KEY', 'UNDERWRITING_MCP_FQDN', 'MCP_BEARER')

function Get-AzdLabValues {
  $v = @{}
  if (-not (Get-Command azd -ErrorAction SilentlyContinue)) { return $v }
  try { (& azd env get-values 2>$null) | ForEach-Object { if ($_ -match '^([A-Za-z0-9_]+)="?(.*?)"?$') { $v[$Matches[1]] = $Matches[2] } } } catch {}
  $v
}

# The two addresses are full URLs despite their _FQDN names: a bare host gets https://, and a trailing slash
# comes off (callers append /policy, /underwriting). Secrets pass untouched.
function Format-LabValue([string]$Key, [string]$Value) {
  if ($Key -notlike '*_FQDN') { return $Value }
  $v = $Value.Trim().TrimEnd('/')
  if ($v -notmatch '^https?://') { $v = "https://$v" }
  $v
}

# Returns @{ Values = @{ <key> = <value> }; Source = '<where from>'; Missing = @(<keys>) }. Only the four keys:
# the committed workspaces use no other ${VAR} that azd would supply.
function Get-LabEndpoints {
  $src = $null; $raw = @{}
  if (Test-Path $LabEndpointsFile) {
    $j = Get-Content $LabEndpointsFile -Raw | ConvertFrom-Json
    foreach ($p in $j.PSObject.Properties) { $raw[$p.Name] = "$($p.Value)" }
    $src = $LabEndpointsFile
  } else {
    $raw = Get-AzdLabValues
    # Name the environment: a facilitator who built before ADR-0005 may still have their own per-estate
    # deployment selected, and that must be visible, not silently used.
    $src = "azd env '$($raw['AZURE_ENV_NAME'])' (no setup/lab-endpoints.local.json)"
  }
  $vals = @{}
  foreach ($k in $LabEndpointKeys) { if ($raw[$k]) { $vals[$k] = Format-LabValue $k $raw[$k] } }
  [pscustomobject]@{ Values = $vals; Source = $src; Missing = @($LabEndpointKeys | Where-Object { -not $vals[$_] }) }
}

# The owner's step: copy the four values out of the selected azd environment into the shared file.
function Save-LabEndpoints([switch]$Force) {
  $v = Get-AzdLabValues
  $missing = @($LabEndpointKeys | Where-Object { -not $v[$_] })
  if ($missing.Count) { throw "azd env get-values has no $($missing -join ', ') - select the shared deployment's azd env (azd env select <name>) after a clean azd up." }
  $o = [ordered]@{}; foreach ($k in $LabEndpointKeys) { $o[$k] = Format-LabValue $k $v[$k] }
  # Every estate's agents carry what this file says: don't replace a different deployment's values by
  # accident (e.g. with an old per-estate azd env still selected).
  if ((Test-Path $LabEndpointsFile) -and -not $Force) {
    $old = Get-Content $LabEndpointsFile -Raw | ConvertFrom-Json
    $diff = @($LabEndpointKeys | Where-Object { "$($old.$_)" -ne $o[$_] })
    if ($diff.Count) { throw "$LabEndpointsFile already holds different $($diff -join ', ') than azd env '$($v['AZURE_ENV_NAME'])'. Select the shared deployment's env, or pass -Force to replace it." }
  }
  $o | ConvertTo-Json | Set-Content $LabEndpointsFile
  Write-Host "Wrote $LabEndpointsFile from azd env '$($v['AZURE_ENV_NAME'])'. Share it with each facilitator out of band; it is gitignored."
}
