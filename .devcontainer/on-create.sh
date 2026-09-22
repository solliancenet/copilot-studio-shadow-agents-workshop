#!/usr/bin/env bash
# on-create.sh — dev container onCreateCommand. Runs as the remote user, before any postCreateCommand.
set -euo pipefail

# 1. The Jekyll image's GEM_HOME (/usr/local/bundle) ships with root-owned subdirs, so the image's own
#    post-create.sh (gem install bundler + bundle install) fails as this user. Hand it over first.
sudo chown -R "$(id -u):$(id -g)" /usr/local/bundle

# 2. Microsoft.PowerApps.Administration.PowerShell's manifest names its root module
#    '...Administration.Powershell.psm1' but ships '...Administration.PowerShell.psm1'. Windows doesn't
#    care; Linux does, and Import-Module fails. Add a link under the name the manifest expects.
for psm1 in /usr/local/share/powershell/Modules/Microsoft.PowerApps.Administration.PowerShell/*/Microsoft.PowerApps.Administration.PowerShell.psm1; do
  [ -e "$psm1" ] && sudo ln -sf "$(basename "$psm1")" "$(dirname "$psm1")/Microsoft.PowerApps.Administration.Powershell.psm1"
done

# 3. Power Platform CLI. The dotnet-tool build targets net10.0 (see the dotnet feature in devcontainer.json).
dotnet tool install --global Microsoft.PowerApps.CLI.Tool || dotnet tool update --global Microsoft.PowerApps.CLI.Tool

# 4. Playwright + headless Chromium. A connector's OAuth consent has no headless API, so Phase 6
#    (06_provision_agents.ps1 -> lib/consent_browser.py) drives a headless browser through the persona
#    sign-in + consent page. Nothing else needs a browser. --break-system-packages: the base image's
#    python is externally managed (PEP 668) and this container is disposable.
pip install --break-system-packages --quiet playwright 2>/dev/null || pip3 install --break-system-packages --quiet playwright
python3 -m playwright install --with-deps chromium
