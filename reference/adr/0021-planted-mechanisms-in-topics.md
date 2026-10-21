# ADR-0021: Planted HTTP, MCP and flow calls live in topics

**Status:** Accepted (verified 2026-09-22)
**Applies to:** `setup/agents/`, `setup/agent-authoring-guide.md`, `setup/RUNBOOK.md` → Phase 6

## Context

All ten agents author from committed workspaces, without the portal. A native HTTP, MCP or flow action
publishes as a **topic** node but not as a tool (errata, *Phase 6 · what authors cleanly vs needs the
portal*). Some features — a **Power Automate flow** (Expense Helper) and the **MCP server** (Underwriting) —
can only be created in the portal.

## Decision

- Connector tools go in a `TaskDialog`; the HTTP action, MCP invoke and flow invoke go in a **topic**.
- Most agents — the benign four and the connector/HTTP planted ones — are **authored** workspaces
  (`agent.mcs.yml` instructions + `knowledge/` + `actions/` + `connectionreferences.mcs.yml`, scaffolded
  with `pac copilot init` then filled in; `capture:"authored"` in the manifest).
- Agents that need a portal-only feature are built once in the portal and **captured**
  (`capture:"clone"`), then replayed:

  ```bash
  pac copilot clone --bot <schema-name> --environment <env-org-url> --output-dir setup/agents   # then rename the folder to the manifest slug
  ```

## Consequences

- An agent runs only if its workspace is committed under `setup/agents/<slug>/`; others report `SKIP`.
