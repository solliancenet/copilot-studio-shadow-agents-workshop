# ADR-0011: Scripts reuse the az sign-in, fall back to device codes, and use org-wide Graph consent

**Status:** Accepted
**Applies to:** `setup/scripts/_auth.ps1`, scripts `01`, `03`, `05`, `99`; `setup/RUNBOOK.md` → Phase 0
steps 5–6

## Context

A script that signs in interactively from the dev container must get a token back into the container.
The scripts that call Graph also ask for delegated scopes, and a sign-in that asks for a scope nobody has
consented to stops at a consent prompt — or fails with *AADSTS65001* where it can't show one.

## Decision

- **Reuse the `az` sign-in first.** Its saved Graph token already carries the scopes `01`, `05` and `99`
  need, so they don't ask at all (`_auth.ps1`).
- **Fall back to a device code** (a code entered at https://microsoft.com/devicelogin) only when `az`
  isn't signed in to the lab tenant. PnP (`03`) always uses a device code. A device code works from any
  terminal, because nothing has to redirect back to it.
- **Consent once, for the organization**, to the whole Graph scope set the scripts use (Phase 0 step 5),
  as the **Microsoft Graph Command Line Tools** app.

## Consequences

- One `az login` per build covers most scripts; few code prompts.
- Device codes must be allowed: security defaults block them
  ([ADR-0010](0010-ca-baseline-replaces-security-defaults.md)).
- `pac` and the PowerApps admin module need nothing granted — both are Microsoft first-party apps and the
  global admin already holds Power Platform admin rights. PnP.PowerShell is the exception: it needs its own
  app registration ([ADR-0016](0016-pnp-app-registration.md)).

## Alternatives considered

- **Interactive browser sign-in.** In the VS Code dev container terminal a browser sign-in can work, but it
  depends on VS Code's browser hook and port forwarding, which a plain `docker exec` shell lacks. A device
  code works everywhere.
