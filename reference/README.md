# reference/

Background research and vendor-documentation digests that inform the workshop build but are
**not part of the attendee guide**. Facilitator- and agent-readable; excluded from the published
Jekyll site (see `_config.yml` `exclude:`).

Use this folder for durable "why" material — how a vendor's billing/licensing works, capacity
models, platform constraints we verified against primary docs — so the RUNBOOK and lab pages can
stay terse and link here for depth.

Each file should cite its primary sources (Microsoft Learn URLs, doc dates) so claims can be
re-verified as products change.

## Contents

| File | Topic |
|---|---|
| `copilot-studio-billing.md` | Copilot Studio billing/licensing models, trial limits, workshop implications |
| `adr/` | Architecture decision records — why the kit is built the way it is |
| `azure-shared-deployment.md` | Deploying the shared Policy API and MCP apps (owner, once per lab) |
| `azure-endpoints.md` | The Phase 1 Container App addresses |
| `billing-plan-by-hand.md` | Creating or linking a billing plan without the script |
| `pnp-app-setup.md` | Registering the shared `Halcourt PnP` app (once per tenant) |
| `sharepoint-seed.md` | What the Phase 4 SharePoint seed creates, and the planted access |
| `dataverse-seed.md` | What the Phase 5 Dataverse seed creates, and the over-broad role |
| `agents-build.md` | What Phase 6 builds: owners and roles, tool mechanisms, connections |
| `building-one-agent.md` | Building one agent with `pac`; what to expect from connections |
| `toolchain.md` | The provisioning tools, what each phase uses them for, installing them outside the dev container |
| `tenant-capabilities.md` | What the tenant must already have, what breaks without it, the fallback |
| `runbook-errata.md` | Errata, known issues & troubleshooting for the provisioning runbook |
