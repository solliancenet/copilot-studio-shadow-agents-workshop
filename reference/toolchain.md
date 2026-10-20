# Provisioning toolchain

The dev container (`.devcontainer/`) installs every tool below; the RUNBOOK assumes you run in it
([RUNBOOK → Before you start](../setup/RUNBOOK.md#before-you-start)). This list is for working outside the
container, or for knowing what a phase depends on.

| Tool | Used by | Outside the container |
|---|---|---|
| Azure CLI (`az`) + Bicep | every phase (sign-in and tokens); Phase 1 | [Install the Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli), then `az bicep install` |
| Azure Developer CLI (`azd`) | Phase 1 | [Install azd](https://learn.microsoft.com/azure/developer/azure-developer-cli/install-azd) |
| Power Platform CLI (`pac`) — the .NET tool build | Phases 0, 3, 6, 7 | needs the .NET 10 SDK: `dotnet tool install --global Microsoft.PowerApps.CLI.Tool` |
| PowerShell 7 with `Microsoft.Graph`, `PnP.PowerShell`, `ExchangeOnlineManagement` | every `setup/scripts/*.ps1` | [Install PowerShell](https://learn.microsoft.com/powershell/scripting/install/installing-powershell), then `Install-Module` each |
| `pandoc` | Phase 4 builds the planted `.docx` from Markdown; without it the script uploads the raw `.md` with the payload visible | your package manager |
| Playwright + Chromium | Phase 6's headless connection consent | `pip install playwright && python3 -m playwright install --with-deps chromium` |

Outside the container, run `source scripts/env.sh` before you sign in, so sign-ins land in the repo
([ADR-0003](adr/0003-project-local-sign-in.md)).
