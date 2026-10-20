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
| `runbook-decisions.md` | Why the provisioning runbook is built the way it is — decisions, tradeoffs, manual alternatives |
| `toolchain.md` | The provisioning tools, what each phase uses them for, installing them outside the dev container |
| `tenant-capabilities.md` | What the tenant must already have, what breaks without it, the fallback |
| `adr/` | Architecture decision records — one decision per file (estates so far) |
| `runbook-errata.md` | Errata, known issues & troubleshooting for the provisioning runbook |
