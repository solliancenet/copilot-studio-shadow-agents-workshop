# ADR-0027: Attendee Dataverse access is a declared access model

**Status:** Accepted
**Applies to:** `setup/scripts/_access_model.ps1`, `07_provision_lab_users.ps1` (Phase 8b),
`00b_preflight.ps1`; [ADR-0004](0004-one-licence-per-attendee.md)

## Context

Power Platform Administrator ([ADR-0024](0024-attendees-are-power-platform-admins.md)) is a **tenant** role.
It grants nothing inside a Dataverse environment: reading `systemusers` or `roles` there fails with
`0x80042f09` *"has not been assigned any roles"* (verified 2026-10-13). Most tasks read something inside an
environment. **System Administrator**, the obvious shortcut, would hand every attendee write access to the
estate they are reviewing.

The first version was a hand-built read-only role with five privileges. It then failed three modules in a
row, each patched by adding what the last 403 named:

| Module | What failed | What it needed |
|---|---|---|
| 03-01, 03-02 | the PPAC role editor: *"Loading role failed!"* | six metadata reads the editor's `EntityDefinitions` and `recordfilters` calls make |
| 01-01 s2-3, 02-01..03, all of 04 | opening an agent in Copilot Studio: *"You need additional access"* | eight Copilot read privileges at Global depth **plus** the built-in `Bot Viewer` |

The role had become a side effect of whichever probe last failed.

## Decision

Attendee Dataverse access is a declared **access model** (`_access_model.ps1`): one row per privilege, with
the exercise step that needs it. Phase 8b enforces it on every run; the preflight verifies it. Extend it
from an exercise's requirement; a privilege nobody can tie to a step does not belong in it.

- **A custom role plus `Bot Viewer`, because neither alone works** (verified 2026-10-16). Copilot Studio
  reads the agent's `bot` and `botcomponent` rows; the agents belong to the personas, so the attendee needs
  those reads at **Global** depth, and `Bot Viewer` grants them only at Basic (own records). The agent page
  also reads connection references, AI plugins, workflows, solutions, publishers and environment
  variables — `Bot Viewer` carries those, maintained by Microsoft. So the custom role carries the
  Global-depth bot reads and the `Copilot*` set, `Bot Viewer` the rest, all `prvRead*`.
- **Reconciled, not just extended.** The live role had drifted (22 privileges in one environment, 14 in
  another, against a list of 5, and `prvReadbot` was the only reason the agent list worked). Phase 8b adds
  what the model lists and removes what it doesn't, so the estate you tested is the estate you deliver.
  Dataverse stamps a baseline onto every custom role (`prvReadSdkMessage*`, `prvReadPluginAssembly`, the
  SharePoint trio) and refuses to remove it (400); the model names that baseline. **The SharePoint write
  privileges on a role named "read-only" are that baseline, not a grant.**

## Consequences

- **Licensing gates the custom role.** An unlicensed account runs in Administrative access mode, which
  *filters* a custom role's privileges and lets only System Administrator through:

  | Account | Licence | Role | Role editor / agent page |
  |---|---|---|---|
  | student01 | none | custom (old) | fails |
  | student01 | E5 | custom | **works** |
  | student02 | none | System Administrator | **works** |
  | student03 | none | custom (complete model) + Bot Viewer | fails (2026-10-17) |

  So the model is necessary and, with a seat, sufficient. Without one, attendees hold System Administrator
  only in their own slice — why 03-01 and 03-02 route there.
- **`addUser` ignores the usual licensing rule.** The BAP admin `addUser` endpoint adds an unlicensed user,
  and a role assigned afterwards works.
- **Match accounts by Entra object id, never by UPN.** A destroy/recreate cycle leaves the previous account's
  `systemuser` record behind under the same UPN; granting the role to that one reports success while the
  live account still gets `0x80042f09`.
- **A Developer environment can refuse `addUser` with 400.** Its owner is its only System Administrator, so
  Maker-Sandbox may need a re-run or a manual add.
