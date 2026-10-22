# ADR-0029: Purview runs app-only, through one lab compliance app

**Status:** Accepted (measured 2026-10-18)
**Applies to:** `setup/RUNBOOK.md` → Phase 4c, `setup/scripts/03c_provision_purview.ps1`, `_labapp.ps1`;
Task 05-06

## Context

Task 05-06 needs an **encrypting** sensitivity label and a labelled copy of the comp workbook. Copilot
Studio can't ground on a file under an encrypting label, even for users who can open it — the behaviour
05-06 retests. Creating the label and policy needs Security & Compliance PowerShell, and labelling a file
needs Graph's `assignSensitivityLabel`.

- Security & Compliance PowerShell refuses the `az` token (*UnAuthorized*).
- `Connect-IPPSSession -Certificate` fails inside the module on Linux (*NewEXOModule* null reference).
- `assignSensitivityLabel` is a **metered** Graph API: the calling app must be linked to a billing resource.

## Decision

One app per tenant, `halcourt-lab-compliance`, signs in app-only with a certificate. The script mints the
token itself and passes `-AccessToken`. Step 0 of `03c_provision_purview.ps1` creates whatever is missing,
idempotently:

| What | Why |
|---|---|
| App `halcourt-lab-compliance`, with a certificate in `setup/lab-compliance-app.local.{json,pfx}` (gitignored) | the app-only sign-in |
| **Compliance Administrator**, `Exchange.ManageAsApp` | the label and label policy |
| Graph `Files.ReadWrite.All` | copying and labelling the workbook |
| SharePoint `Sites.FullControl.All` | turning on SharePoint's label integration |
| `Microsoft.GraphServices/accounts` in `rg-halcourt-graph-billing` | billing for the metered label API |

A facilitator without the local certificate files gets a fresh certificate appended to the app; the app
itself is shared by every estate (listed in [ADR-0001](0001-estates.md)'s shared items).

The original `Leadership/2026-comp-bands.xlsx` stays **unlabelled** — Exercise 04 needs it reachable. Only a
copy, `2026-comp-bands-labeled.xlsx` with a `LABELLED-COPY-<estate>` marker row, is labelled, so a retest can
tell which file answered.

## Consequences

- Two lags, both handled by re-running: a new group isn't an Exchange recipient for a while, and label
  assignment returns `labelNotFound` until the label replicates (errata → Phase 4c).
- SharePoint search must index the labelled copy before 05-06 can be retested, so this runs days before a
  delivery.
- Never delete `rg-halcourt-graph-billing` or the app while any estate is live.
