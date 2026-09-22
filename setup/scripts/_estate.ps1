<#
FACILITATOR-ONLY. Estate naming - dot-sourced by the provisioning scripts.

Several people can build the Halcourt Mutual estate in the same tenant. Each build is an ESTATE with a
short id (the facilitator's alias, e.g. mgray), and every tenant-scoped name it creates carries that id,
so estates never adopt or overwrite each other's objects. The canon (AGENTS.md, the artifact pack, the
lab pages) keeps the plain names; the rule below derives the live ones (AGENTS.md -> Live estate naming):

  UPN alias      <alias>.<estate>          marcus.webb.mgray@<tenant domain>
  display name   <name> (<estate>)         Marcus Webb (mgray)
  other names    <name>-<estate>           Claims-Test-mgray, HR-Benefits-mgray, Halcourt-Makers-mgray

Shared by every estate in the tenant: the default environment and the Conditional Access baseline.
ASCII only: Windows PowerShell 5.1 (Phase 5) reads files without a BOM as ANSI.
#>

function Resolve-Estate([string]$Estate) {
  if (-not $Estate) { $Estate = $env:HALCOURT_ESTATE }
  if (-not $Estate) {
    throw 'No estate id. Pass -Estate <id> or set HALCOURT_ESTATE (e.g. your alias: mgray) - see RUNBOOK -> Estates.'
  }
  # Lowercase letters/digits only: the id lands in UPNs, group and environment names, and SharePoint URLs.
  if ($Estate -cnotmatch '^[a-z0-9]{2,12}$') {
    throw "Estate id '$Estate' must be 2-12 lowercase letters or digits (e.g. mgray)."
  }
  return $Estate
}

function Get-EstateName([string]$Name, [string]$Estate)        { "$Name-$Estate" }
function Get-EstateAlias([string]$Alias, [string]$Estate)      { "$Alias.$Estate" }
function Get-EstateDisplayName([string]$Name, [string]$Estate) { "$Name ($Estate)" }
