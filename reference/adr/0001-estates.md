# ADR-0001: Every live build is an estate

**Status:** Accepted
**Applies to:** `setup/RUNBOOK.md` → *Phase 0b*, every `setup/scripts/*` script, `AGENTS.md` → *Live estate naming*

## Context

The scripts find everything they create **by name**. Under the canonical names (`Claims-Test`,
`marcus.webb@…`, `HR-Benefits`) a second build in the same tenant adopts or overwrites the first: its
Phase 3 skips creating `Claims-Test` because one exists, its Phase 5 seeds someone else's Dataverse, and
both builds share Marcus, Tom and the rest — so one person's Phase 6.5 orphans Tom for everyone.

More than one facilitator needs to build Halcourt Mutual in the same tenant.

## Decision

Each build is an **estate** with a short id — the builder's alias, 2–12 lowercase letters or digits — and
every tenant-scoped name it creates carries that id:

| What | Canonical (AGENTS.md, lab pages, artifact pack) | Live, estate `jsmith` | Rule |
|---|---|---|---|
| Accounts | `marcus.webb@halcourtmutual.onmicrosoft.com` | `marcus.webb.jsmith@<tenant domain>` | `<alias>.<estate>@<tenant domain>` |
| Display names | Marcus Webb | Marcus Webb (jsmith) | `<name> (<estate>)` |
| Groups, environments, DLP, sites | `Halcourt-Makers`, `Claims-Test`, `Halcourt-Prod-DLP`, `HR-Benefits` | `Halcourt-Makers-jsmith`, `Claims-Test-jsmith`, `Halcourt-Prod-DLP-jsmith`, `HR-Benefits-jsmith` | `<name>-<estate>` |
| Agents in the default environment | `Expense Helper`, `Onboarding Guide` | `Expense Helper (jsmith)`, `Onboarding Guide (jsmith)` | `<name> (<estate>)` |
| Azure (Phase 1) | — | azd environment `halcourt-jsmith-lab` | `halcourt-<estate>-lab` |

The id comes from `HALCOURT_ESTATE` or `-Estate <id>`; a script refuses to run with neither.
`setup/scripts/_estate.ps1` implements the rule; `AGENTS.md` → *Live estate naming* is the canonical
statement of it.

**Shared, not renamed** — a tenant has exactly one of each:

- the default environment (`Halcourt (default)`), named once by whoever runs first;
- the Conditional Access baseline (Phase 0);
- the PnP app registration (Phase 4).
- proposed: the Phase 1 Azure deployment ([ADR-0005](0005-shared-azure-deployment.md)).

**Lab pages keep the canonical names.** Attendees get the estate id with the tenant domain, and Task 00-01
shows them how names carry it.

## Consequences

- Builds in one tenant are independent, except for the shared items above — a change to those is
  everyone's change.
- Each estate costs its own licences (eight E5 seats, Phase 2) and its own environments and capacity.
- Committed workspaces must use tokens (`${ESTATE}`, `${SP_HOST}`), never one build's literal names —
  errata *Phase 6 · the committed workspaces named THIS tenant and estate* is what happens otherwise.
- `05_export_artifact_pack.ps1 -Canonicalize` maps a live estate back to the canon, so the artifact pack
  and answer key stay estate-neutral.

## Alternatives considered

- **One build per tenant, canonical names.** No suffixes, but every facilitator needs their own tenant,
  with its own licences and Conditional Access setup.
- **Regenerate the published pages per estate.** Attendees would see live names, but the artifact pack and
  answer key would be out of sync with every estate but one.
