# ADR-0003: CLI sign-ins live in the repo, not your home folder

**Status:** Accepted
**Applies to:** `scripts/env.sh`, `scripts/shims/pac`, `.vscode/settings.json`, `.claude/settings.json`,
`.devcontainer/`, every `setup/scripts/*` and `infra/*.sh` script; `setup/RUNBOOK.md` → *Estates* step 2

## Context

`az` and `pac` keep their sign-ins in your home folder by default (`~/.azure`, `~/.local/share/...`). A
facilitator's home folder usually holds their day-job login — a company tenant and subscription. Building
the lab from that state risks running a script that creates users, environments and DLP policies against
the wrong tenant, and a lab login left in the home folder leaks into day-job work the other way.

## Decision

Sign-in state for this repo lives in the repo, in two gitignored folders:

| Folder | Holds | Set by |
|---|---|---|
| `.azure/` | Azure CLI profile and token cache; azd environments | `AZURE_CONFIG_DIR` |
| `.pac/` | Power Platform CLI auth profiles and token cache | the `scripts/shims/pac` wrapper on `PATH` |

`scripts/env.sh` sets both. It is applied automatically:

- in the dev container's VS Code terminal (`.vscode/settings.json`, `terminal.integrated.env.linux`);
- in Claude Code (`.claude/settings.json`, a SessionStart hook);
- in `infra/*.sh`, which source it.

Anywhere else — including a terminal on your own Mac or Windows machine — run `source scripts/env.sh`
before `az login`, or the login lands in your home folder and the scripts don't see it.

## Consequences

- A login in your home folder does not count. `az account show` can report you signed in (to your company
  tenant) while the scripts report *Please run 'az login'* — they are reading different folders.
- Each clone of the repo signs in separately; deleting `.azure/` and `.pac/` signs you out of the lab.
- `azd` lists every subfolder of `.azure/` as an environment, so `env.sh` keeps the az extension folder in
  `~/.azure` and switches off az's log and telemetry folders.
- Two copies of the settings must agree: `scripts/env.sh` and `.vscode/settings.json`.

## Alternatives considered

- **Use the home folder and switch tenants with `az login --tenant`.** Simpler, but one forgotten switch
  points a provisioning script at the wrong tenant.
- **A separate OS user or VM per lab.** Strong isolation, but heavy for a facilitator kit.
