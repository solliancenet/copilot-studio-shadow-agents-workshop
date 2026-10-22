# ADR-0020: Agents are provisioned clone-first from committed workspaces

**Status:** Accepted (verified through the 2026-09-22 greenfield rebuild)
**Applies to:** `setup/RUNBOOK.md` → Phase 6, `setup/scripts/06_provision_agents.ps1`, `setup/agents/`

## Context

`pac copilot push` only *updates*, and needs a *synced* local workspace (matching `.mcs` state) — which a
committed workspace (gitignored `.mcs`) never has, and which `init` alone doesn't reliably leave behind.

## Decision

The committed workspace is authoritative; the engine reconciles the live agent to it:

- **Clone first.** Each provision clones the agent into a temp dir (pac's own existence view; the Dataverse
  `bots` table can disagree), drops the clone's server-state knowledge/tools/connection references,
  overlays the committed ones, and pushes. If the clone finds nothing, the agent is absent: it `init`s the
  shell first — retried, because the solution import lags — then clones. The agent identity is preserved;
  nothing is deleted.
- **Estate-scoped schema in the shared default environment.** A schema name is unique per environment, so
  agents built into `Halcourt (default)` (`estateSuffixName` in the manifest) get `<schema><estate>`, and the
  engine rewrites the committed schema inside topics, actions and connection references to match. An estate
  built before this keeps its committed schema: the engine uses it when this estate's owner sees an agent
  with that schema under this estate's display name. Before the change, a second estate's `init` failed and
  its schema lookups could reach another estate's agent (issue #33).
- **Publisher.** Each agent keeps its committed prefix; the engine creates a publisher with that prefix if
  the environment lacks one (environment teardown gives new random CDS prefixes).
- **Owner-token Dataverse.** Bot lookup, the chat-audience PATCH and connection binding run **as the
  owner**: in the shared default environment the admin has no read on `bots` (it returns empty), and a
  connection reference can only be bound by the connection's owner (Sales Nudge is Lena's but binds Tom's
  connection; Claims Copilot is Priya's but binds svc-claims's).
- **Chat audience** is set on the bot record, then **publish with retry** — publishing right after create
  can be too soon.

## Consequences

- Re-running Phase 6 is safe and converges on the committed workspaces.
- Workspaces carry `${VAR}` tokens, never one build's names or secrets (errata → *Phase 6 · the committed
  workspaces named THIS tenant and estate*).
- Doing one agent by hand: [building one agent](../building-one-agent.md).
