<#
FACILITATOR-ONLY. Estate naming - dot-sourced by the provisioning scripts.

Several people can build the Halcourt Mutual estate in the same tenant. Each build is an ESTATE with a
short id (the facilitator's alias, e.g. jsmith), and every tenant-scoped name it creates carries that id,
so estates never adopt or overwrite each other's objects. The canon (AGENTS.md, the artifact pack, the
lab pages) keeps the plain names; the rule below derives the live ones (AGENTS.md -> Live estate naming):

  UPN alias      <alias>.<estate>          marcus.webb.jsmith@<tenant domain>
  display name   <name> (<estate>)         Marcus Webb (jsmith)
  other names    <name>-<estate>           Claims-Test-jsmith, HR-Benefits-jsmith, Halcourt-Makers-jsmith

Shared by every estate in the tenant: the default environment and the Conditional Access baseline.
#>

# Tenant guard. The lab's az sign-in lives in the repo's .azure/ (scripts/env.sh). A shell that never
# sourced it - seen: a detached background shell - falls back to ~/.azure, which on a facilitator's machine
# is usually their day-job tenant, and these scripts then read and WRITE there. So: unset means use the
# repo's; anything else stops the run before the first az call.
$_repoAzure = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../.azure'))
if (-not $env:AZURE_CONFIG_DIR) { $env:AZURE_CONFIG_DIR = $_repoAzure }
elseif ([System.IO.Path]::GetFullPath($env:AZURE_CONFIG_DIR).TrimEnd('/','\') -ne $_repoAzure.TrimEnd('/','\')) {
  throw "AZURE_CONFIG_DIR is '$env:AZURE_CONFIG_DIR', not this repo's .azure ($_repoAzure). Run 'source scripts/env.sh' (or unset it) so the scripts use the lab sign-in, not another tenant's."
}

function Resolve-Estate([string]$Estate) {
  if (-not $Estate) { $Estate = $env:HALCOURT_ESTATE }
  if (-not $Estate) {
    throw 'No estate id. Pass -Estate <id> or set HALCOURT_ESTATE (e.g. your alias: jsmith) - see RUNBOOK -> Phase 0b.'
  }
  # Lowercase letters/digits only: the id lands in UPNs, group and environment names, and SharePoint URLs.
  if ($Estate -cnotmatch '^[a-z0-9]{2,12}$') {
    throw "Estate id '$Estate' must be 2-12 lowercase letters or digits (e.g. jsmith)."
  }
  return $Estate
}

function Get-EstateName([string]$Name, [string]$Estate)        { "$Name-$Estate" }
function Get-EstateAlias([string]$Alias, [string]$Estate)      { "$Alias.$Estate" }
function Get-EstateDisplayName([string]$Name, [string]$Estate) { "$Name ($Estate)" }
