# shellcheck shell=bash
#
# env.sh — keep this repo's CLI sign-in state inside the repo. Source it; don't run it.
#
#   source scripts/env.sh
#
# Lab-tenant logins stay out of your home directory (and your day-job logins stay out of
# the lab). Both folders are gitignored.
#
#   .azure/  Azure CLI profile + token cache (AZURE_CONFIG_DIR). azd keeps its environments
#            in the same folder and lists every subfolder as an environment, so the az
#            subfolders (commands/, logs/, telemetry/, cliextensions/) are switched off or
#            left in ~/.azure.
#   .pac/    Power Platform CLI auth profiles + token cache, via scripts/shims/pac.
#
# Applied automatically by the VS Code terminal (.vscode/settings.json — keep in sync),
# Claude Code (.claude/settings.json), and infra/*.sh.

_repo="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"

export AZURE_CONFIG_DIR="$_repo/.azure"
export AZURE_EXTENSION_DIR="${AZURE_EXTENSION_DIR:-$HOME/.azure/cliextensions}"
export AZURE_CORE_COLLECT_TELEMETRY=false
export AZURE_LOGGING_ENABLE_LOG_FILE=false

case ":$PATH:" in
  *":$_repo/scripts/shims:"*) ;;
  *) export PATH="$_repo/scripts/shims:$PATH" ;;
esac

unset _repo
