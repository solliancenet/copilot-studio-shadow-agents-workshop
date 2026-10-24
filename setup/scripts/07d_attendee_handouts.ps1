<#
FACILITATOR-ONLY. Phase 8b, part four: the printed sign-in cards for the attendees.

Reads 07's handouts (setup/lab-users-<estate>.local.csv) and writes one card per attendee account, two to a
Letter page with a cut line between them: the workshop guide's address, the estate id, username, password,
tenant domain, the attendee's own lab environment (Lab-<estate>-NN, Phase 8c) and the first sign-in steps.
Print the PDF and hand each attendee their card.

  pwsh setup/scripts/07d_attendee_handouts.ps1                          # every lab-users-*.local.csv
  pwsh setup/scripts/07d_attendee_handouts.ps1 -Estates stu01,stu02     # just these estates

Writes setup/attendee-handouts.local.html and .pdf. Both hold PLAINTEXT passwords: they are gitignored
(*.local.html / *.local.pdf). Never publish or share them anywhere but the printer, and delete them after
the delivery with the handout CSVs (Phase 9). Run it again after re-running 07: it reads the CSVs as they
are then. Needs python3 + playwright for the PDF (the dev container has both); -HtmlOnly skips it.
ASCII only.
#>
param(
  [string[]]$Estates,                                 # default: every setup/lab-users-*.local.csv
  [string]$GuideUrl,                                  # default: url + baseurl from _config.yml (the published site)
  [string]$HandoutDir,                                # where 07's CSVs are; default: setup/
  [string]$OutBase,                                   # default: setup/attendee-handouts.local
  [switch]$HtmlOnly
)
$ErrorActionPreference = 'Stop'
$setup = Split-Path -Parent $PSScriptRoot
# The published site's address, from the same _config.yml values Jekyll builds it with.
if (-not $GuideUrl) {
  $cfg = Get-Content (Join-Path (Split-Path -Parent $setup) '_config.yml') -ErrorAction SilentlyContinue
  $url  = ($cfg | Select-String '^url:\s*"?([^"#\s]+)"?' | Select-Object -First 1).Matches.Groups[1].Value
  $base = ($cfg | Select-String '^baseurl:\s*"?([^"#\s]*)"?' | Select-Object -First 1).Matches.Groups[1].Value
  if (-not $url) { throw 'No url in _config.yml - pass -GuideUrl.' }
  $GuideUrl = "$url$base/"
}
if (-not $HandoutDir) { $HandoutDir = $setup }
if (-not $OutBase) { $OutBase = Join-Path $setup 'attendee-handouts.local' }

# `pwsh -File ... -Estates a,b` arrives as one string 'a,b'; split it (as 10_build_estates does).
$Estates = @($Estates | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
$files = if ($Estates) {
  foreach ($e in $Estates) {
    $f = Join-Path $HandoutDir "lab-users-$e.local.csv"
    if (-not (Test-Path $f)) { throw "No $f - run 07_provision_lab_users.ps1 for estate '$e' first." }
    Get-Item $f
  }
} else { @(Get-ChildItem $HandoutDir -Filter 'lab-users-*.local.csv' | Sort-Object Name) }
if (-not $files) { throw "No setup/lab-users-*.local.csv - run 07_provision_lab_users.ps1 first." }

function HtmlEnc([string]$s) { [System.Net.WebUtility]::HtmlEncode($s) }

# One card per account. The estate id and the NN of Lab-<estate>-NN come from the UPN
# (student01.stu03@domain -> 01, stu03), the same rule 07 and 08 use to build them.
# A row that can't sign anyone in stops the run rather than printing a card for it: printing a partial set
# without noticing is worse than fixing the row first. 07 writes such rows when an account failed to create
# (created = 'FAILED: ...') and, for an existing account whose password it doesn't have, a marker in place
# of the password: '(unknown - ...)', or '(unchanged - ...)' from older versions ($pwMarkers in 07).
$problems = @()
$cards = foreach ($f in $files) {
  foreach ($row in Import-Csv $f) {
    $m = [regex]::Match("$($row.upn)", '^[a-z]+(\d+)\.([a-z0-9]+)@(.+)$')
    $why = if (-not $m.Success) { 'not <prefix><NN>.<estate>@<domain>' }
           elseif ("$($row.created)" -like 'FAILED*') { "07 couldn't create it ($($row.created))" }
           elseif (-not $row.password) { 'no password' }
           elseif ($row.password -match '^\((unknown|unchanged) - ') { 'no password recorded (07 wrote its placeholder)' }
    if ($why) { $problems += "  $($f.Name): $($row.upn) - $why"; continue }
    [pscustomobject]@{ Upn = $row.upn; Password = $row.password; NN = $m.Groups[1].Value; Estate = $m.Groups[2].Value; Domain = $m.Groups[3].Value }
  }
}
if ($problems) {
  throw "Not printing: $($problems.Count) row(s) can't sign anyone in. Re-run 07 for those estates (or reset the account's password and correct its CSV row), then run this again.`n$($problems -join "`n")"
}
$cards = @($cards | Sort-Object Estate, NN)
if (-not $cards) { throw 'No attendee accounts found in the handout CSVs.' }

$guideShown = $GuideUrl -replace '^https?://', '' -replace '/$', ''
$body = @(foreach ($c in $cards) {
  $lab = "Lab-$($c.Estate)-$($c.NN)"
  @"
<section class="card">
  <header>
    <div class="title">Copilot Studio Shadow Agents Workshop</div>
    <div class="sub">Your lab account for Halcourt Mutual</div>
  </header>
  <table>
    <tr><th>Workshop guide</th><td class="mono url">$(HtmlEnc $guideShown)</td></tr>
    <tr><th>Estate id</th><td class="mono big">$(HtmlEnc $c.Estate)</td></tr>
    <tr><th>Username</th><td class="mono big">$(HtmlEnc $c.Upn)</td></tr>
    <tr><th>Password</th><td class="mono big">$(HtmlEnc $c.Password)</td></tr>
    <tr><th>Tenant domain</th><td class="mono">$(HtmlEnc $c.Domain)</td></tr>
    <tr><th>Your lab environment</th><td class="mono">$(HtmlEnc $lab)</td></tr>
  </table>
  <ol>
    <li>Open a <b>private browser window</b>, so your work account doesn't sign you in to the wrong tenant.</li>
    <li>Go to <span class="mono">admin.powerplatform.microsoft.com</span> and sign in with the username and password above.</li>
    <li>When asked, set up <b>Microsoft Authenticator</b> (or another authenticator app) on your phone. This happens once, at your first sign-in.</li>
    <li>Open the workshop guide and start at <b>Exercise 00</b>.</li>
  </ol>
  <footer>A lab-only account, deleted after the workshop. Don't use it for anything else.</footer>
</section>
"@
})

$html = @"
<!doctype html>
<html lang="en"><head><meta charset="utf-8"><title>Attendee sign-in cards</title>
<style>
  @page { size: Letter; margin: 0.5in; }
  * { box-sizing: border-box; }
  body { margin: 0; font: 11pt/1.35 "Segoe UI", "Helvetica Neue", Arial, sans-serif; color: #111; }
  /* Two cards to a page, as an explicit pair: 10in of printable height = 2 x 4.75in cards + the cut line. */
  .page { height: 9.95in; display: flex; flex-direction: column; justify-content: space-between; break-after: page; }
  .page:last-child { break-after: auto; }
  .card { height: 4.75in; padding: 0.3in 0.35in; border: 1px solid #999; border-radius: 6px;
          display: flex; flex-direction: column; overflow: hidden; }
  .cut { border-top: 1px dashed #777; }
  header { border-bottom: 2px solid #222; padding-bottom: 6px; margin-bottom: 10px; }
  .title { font-size: 15pt; font-weight: 700; }
  .sub { font-size: 10.5pt; color: #444; }
  table { border-collapse: collapse; width: 100%; margin-bottom: 10px; }
  th { text-align: left; font-weight: 600; color: #333; width: 1.6in; padding: 3px 8px 3px 0; vertical-align: top; white-space: nowrap; }
  td { padding: 3px 0; overflow-wrap: anywhere; }
  .url { font-size: 9pt; white-space: nowrap; }
  .mono { font-family: "Cascadia Mono", Consolas, "DejaVu Sans Mono", monospace; }
  .big { font-size: 13pt; font-weight: 600; }
  ol { margin: 0; padding-left: 1.2em; font-size: 10pt; }
  li { margin-bottom: 2px; }
  footer { margin-top: auto; font-size: 8.5pt; color: #555; }
</style></head>
<body>
$(@(for ($i = 0; $i -lt $body.Count; $i += 2) {
  '<div class="page">' + $body[$i] + $(if ($i + 1 -lt $body.Count) { '<div class="cut"></div>' + $body[$i + 1] } else { '' }) + '</div>'
}) -join "`n")
</body></html>
"@

$htmlPath = "$OutBase.html"; $pdfPath = "$OutBase.pdf"
# Create both files empty and owner-only BEFORE a password goes into them; writing later keeps the mode.
foreach ($f in $htmlPath, $pdfPath) { Set-Content -Path $f -Value $null -NoNewline; if (-not $IsWindows) { chmod 600 $f } }
Set-Content -Path $htmlPath -Value $html -Encoding utf8
Write-Host "$($cards.Count) card(s) from $($files.Count) handout file(s) -> $htmlPath"
if ($HtmlOnly) { Remove-Item $pdfPath -ErrorAction SilentlyContinue }
else {
  $out = python3 (Join-Path $PSScriptRoot 'lib/print_pdf.py') --html $htmlPath --pdf $pdfPath 2>&1
  if ($LASTEXITCODE) { throw "PDF rendering failed (open the HTML and print it instead): $($out -join ' ')" }
  Write-Host "Print: $pdfPath ($([math]::Ceiling($cards.Count / 2)) page(s), two cards a page - cut on the dashed line)"
}
Write-Warning 'These files hold PLAINTEXT passwords. They are gitignored; print them, never share them, and delete them after the delivery.'
