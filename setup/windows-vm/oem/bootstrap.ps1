<#
Windows build VM — install the provisioning toolchain from setup/RUNBOOK.md → Prerequisites.

Runs once, automatically, at the end of Windows setup (install.bat). Safe to re-run: every step skips
what is already installed. If the first run failed (check C:\OEM\bootstrap.log), re-run it from an
elevated prompt:

  powershell -ExecutionPolicy Bypass -File C:\OEM\bootstrap.ps1

Written for Windows PowerShell 5.1, which is all a fresh Windows has.
#>
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # Invoke-WebRequest is very slow with the progress bar on
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Start-Transcript -Path (Join-Path $PSScriptRoot 'bootstrap.log') -Append | Out-Null

$pwsh = "$env:ProgramFiles\PowerShell\7\pwsh.exe"

# Network can lag behind first logon.
$deadline = (Get-Date).AddMinutes(5)
while (-not (Test-NetConnection -ComputerName aka.ms -Port 443 -InformationLevel Quiet)) {
  if ((Get-Date) -gt $deadline) { throw 'No network after 5 minutes.' }
  Start-Sleep -Seconds 10
}

function Install-Msi([string]$Name, [string]$Url) {
  $file = Join-Path $env:TEMP "$Name.msi"
  Write-Host "Installing $Name..."
  Invoke-WebRequest -Uri $Url -OutFile $file -UseBasicParsing
  $p = Start-Process msiexec.exe -ArgumentList "/i `"$file`" /qn /norestart" -Wait -PassThru
  if ($p.ExitCode -notin 0, 3010) { throw "$Name install failed (msiexec exit $($p.ExitCode))." }
}

function Get-GitHubMsiUrl([string]$Repo, [string]$Pattern) {
  $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases/latest" -UseBasicParsing
  ($release.assets | Where-Object name -Like $Pattern | Select-Object -First 1).browser_download_url
}

# --- CLIs ---------------------------------------------------------------------
# Installers update PATH in the registry, not in this session.
function Test-Tool([string]$Name) {
  $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' +
              [Environment]::GetEnvironmentVariable('Path', 'User')
  [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

if (-not (Test-Path $pwsh)) {
  Install-Msi 'PowerShell-7' (Get-GitHubMsiUrl 'PowerShell/PowerShell' 'PowerShell-*-win-x64.msi')
}
if (-not (Test-Tool 'az'))     { Install-Msi 'azure-cli' 'https://aka.ms/installazurecliwindowsx64' }
if (-not (Test-Tool 'pac'))    { Install-Msi 'power-platform-cli' 'https://aka.ms/PowerAppsCLI' }
if (-not (Test-Tool 'pandoc')) { Install-Msi 'pandoc' (Get-GitHubMsiUrl 'jgm/pandoc' 'pandoc-*-windows-x86_64.msi') }
if (-not (Test-Tool 'azd')) {
  Write-Host 'Installing azd...'
  # The installer ends with `exit 0`. Piped to Invoke-Expression that exit ends THIS script, so run it
  # in its own process.
  $azdInstaller = Join-Path $env:TEMP 'install-azd.ps1'
  Invoke-WebRequest -Uri 'https://aka.ms/install-azd.ps1' -OutFile $azdInstaller -UseBasicParsing
  & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $azdInstaller
  if ($LASTEXITCODE) { throw "azd install failed (exit $LASTEXITCODE)." }
}

# --- PowerShell modules -------------------------------------------------------
# Scripts run from Z:, a network drive, which RemoteSigned treats as remote. Lab VM only.
Set-ExecutionPolicy Bypass -Scope LocalMachine -Force
& $pwsh -NoProfile -Command 'Set-ExecutionPolicy Bypass -Scope LocalMachine -Force'

# PowerShell 7 — every phase. PnP.PowerShell 3.x needs 7.4+, so install these from pwsh.
& $pwsh -NoProfile -Command {
  $ErrorActionPreference = 'Stop'
  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
  foreach ($m in 'Microsoft.Graph', 'Microsoft.PowerApps.Administration.PowerShell',
                 'PnP.PowerShell', 'ExchangeOnlineManagement') {
    if (-not (Get-Module -ListAvailable $m)) {
      Write-Host "Installing $m (PowerShell 7)..."
      Install-Module $m -Scope AllUsers -Force -AllowClobber
    }
  }
}
if ($LASTEXITCODE) { throw "PowerShell 7 module install failed (exit $LASTEXITCODE)." }

Write-Host 'Windows build VM ready. Open a new terminal so PATH picks up the new tools.'
Stop-Transcript | Out-Null
