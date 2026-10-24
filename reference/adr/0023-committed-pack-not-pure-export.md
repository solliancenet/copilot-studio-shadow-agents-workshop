# ADR-0023: The committed artifact pack is canonical, not a pure export

**Status:** Accepted
**Applies to:** `setup/RUNBOOK.md` → Phase 7, `worksheets/artifact-pack/`,
`setup/scripts/05_export_artifact_pack.ps1`

## Context

Three of the pack's columns are hand-written canon that no API returns: agent `description`, the friendly
connector names (`SharePoint`, not `shared_sharepointonline`), and the rows for things that are not Power
Platform connections at all (`HTTP-PolicyAPI`, `MCP-Underwriting`, `PA-Expense-AutoApprove`). The pack is
also published with the site, and must use canonical names.

## Decision

- The committed pack is the canonical one.
- The export **preserves** existing `description` text by display name rather than blanking it.
- `used_by_agent` comes from the tenant where the tenant knows: an agent's connection references are named
  `<bot schema>.<connector>.<name>` and carry the id of the connection they are bound to. A connection used
  only by **knowledge** (SharePoint or OneDrive grounding, which reads as the user) is bound to no reference,
  so the tenant can't name its agent: `SP-HR-Benefits`, `SP-HR-FAQ`, `SP-Onboarding`, `OneDrive-DevKim`.
  For those the value is canon, and the export keeps the committed one as it does `description` (#43). The
  three made for knowledge-only agents are built by Phase 6 from the manifest's `forAgent` (#44).
- `-Canonicalize` maps live names back to the canon's (strips the estate id, restores
  `@halcourtmutual.onmicrosoft.com`), so the export lands on the committed pack and `git diff` shows the
  drift. Without it, the script refuses to write into the committed pack.

## Consequences

- Read the diff as *drift to review*, not as a test that should come out empty. The connector and
  conceptual-connection rows still need a human.
