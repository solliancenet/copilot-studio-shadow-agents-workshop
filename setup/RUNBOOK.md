# RUNBOOK.md — Facilitator provisioning

> **FACILITATOR-ONLY. Not published** (the whole `setup/` folder is excluded in `_config.yml`).
> Provisions the intentionally-vulnerable **Halcourt Mutual** demo estate for the workshop. Everything
> here is keyed to the canon in [`../AGENTS.md`](../AGENTS.md) — that file is the source of truth; this
> file is how you build it.

## Model: hybrid

- A single **shared demo tenant** hosts the live estate for the BREAK (Module 4) and CONTROL (Module 5)
  demos. Attendees get a **guest / read** account (Ana Reyes vantage) plus the low-priv **Jordan Blake**
  path for confused-deputy demos.
- An **artifact pack** (five CSVs in `../worksheets/artifact-pack/`) is exported from the estate so the
  DISCOVER / MAP / threat-model / ASSESS work runs offline. **The committed artifact pack is the
  canonical output of Phase 7 below** — regenerate it whenever the estate changes.

{: important}
The estate is deliberately broken. Provision it in an **isolated training tenant** you control. Never
point these scripts at a production tenant. All external endpoints live under
`*.halcourtmutual-lab.com`, which you own for the lab.

## Prerequisites (technician)

- An **isolated M365 / Power Platform tenant** with: Power Platform admin, Entra admin, SharePoint admin,
  and (for Module 5) Purview, Conditional Access, and Defender access.
- Licensing: **Copilot Studio**, **M365 E5 / Agent 365**, **Purview**. Confirm current SKUs — see the
  `[verify]` list in [`../PLANNING.md`](../PLANNING.md).
- Tooling on the build box:
  - Azure CLI (`az`) + Bicep, an Azure subscription for the Container Apps.
  - Power Platform CLI (`pac`).
  - PowerShell 7 with modules: `Microsoft.Graph`, `Microsoft.PowerApps.Administration.PowerShell`,
    `Microsoft.PowerApps.PowerShell`, `PnP.PowerShell`, `Microsoft.Xrm.Data.PowerShell` (or `pac`).
- DNS for `api.halcourtmutual-lab.com` and `mcp.halcourtmutual-lab.com` (CNAME to the Container Apps).

## Phase order (do NOT reorder)

```
1. Azure infra (Bicep)        → Policy API + Underwriting MCP endpoints
2. Entra identities/personas  → users, groups, DISABLE tom.dean
3. Environments + DLP + CA     → 4 environments, prod DLP, CA policies
4. SharePoint seed             → HR-Benefits + Claims-Knowledge, PLANT the poisoned doc
5. Dataverse seed              → Claim + Customer tables, PII rows, the over-broad role
6. Author the agents (MANUAL)  → Copilot Studio, per agent-authoring-guide.md
7. Export the artifact pack    → regenerate ../worksheets/artifact-pack/*.csv
8. Validate                    → every planted problem reproduces; verdicts hold
9. Teardown / reseed
```

---

### Phase 1 — Azure infrastructure (Bicep)

Deploys the internal **Policy API** and the **Underwriting MCP** server as Container Apps. Both are
intentionally weak (static-secret auth, over-scoped surface) — see `infra/policy-api/` and
`infra/mcp-underwriting/`.

```bash
az group create -n rg-halcourt-lab -l eastus
az deployment group create -g rg-halcourt-lab -f setup/infra/main.bicep \
  -p policyApiKey='<generate-a-lab-only-key>' mcpBearer='<generate-a-lab-only-token>'
```

Record the two FQDNs from the deployment outputs; map DNS. The **static API key** you pass here is the
one that will sit in Policy Lookup Bot's HTTP action config (that exposure is the point of Scenario E).

### Phase 2 — Entra identities & personas

```powershell
pwsh setup/scripts/01_provision_entra.ps1 -TenantId <tenant>
```

Creates every persona in `AGENTS.md` (Ana, Marcus, Priya, Sam, Lena, Dev, Jordan), the service account
`svc-claims`, the `it.helpdesk` shared mailbox, and the groups. **Critically, it disables `tom.dean`**
after his connections are created in later phases — the script leaves a marker; run the disable step
(Phase 6.5) only *after* Tom's connections exist, so the orphan is real.

### Phase 3 — Environments, DLP, Conditional Access

```powershell
pwsh setup/scripts/02_provision_environments_dlp.ps1
```

Creates the four environments (`Halcourt (default)`, `Halcourt-Prod`, `Claims-Test`, `Maker-Sandbox`),
applies `Halcourt-Prod-DLP` to **Prod only**, and creates the baseline CA policies
(`CA-Require-MFA-Admins`, `CA-Block-Legacy-Auth`). It deliberately leaves Default / Claims-Test / Sandbox
**without DLP** and creates **no** CA policy targeting workload identities — those gaps drive Module 5.

### Phase 4 — SharePoint seed (plant the poisoned doc)

```powershell
pwsh setup/scripts/03_provision_sharepoint.ps1
```

Creates `HR-Benefits` (with a `Leadership/` subfolder holding `2026-comp-bands.xlsx`) and
`Claims-Knowledge`, uploads the FAQ library, and **plants `Open-Enrollment-FAQ.docx`** built from
`setup/data/Open-Enrollment-FAQ.md` (which carries the indirect-injection payload — see the SPOILER block
in `AGENTS.md`). The whole-site grounding + the leadership folder are what make Scenarios A and B fire.

### Phase 5 — Dataverse seed

```powershell
pwsh setup/scripts/04_provision_dataverse.ps1
```

Creates `Claim` and `Customer` tables in `Claims-Test`, seeds rows from `setup/data/claims.csv` and
`setup/data/customers.csv` (Customer holds SSN/DOB), and grants `svc-claims` the **over-broad** role
(read/write all rows, no row-level security). Least privilege here is what Module 5 will *close*.

### Phase 6 — Author the agents (MANUAL)

Copilot Studio agent authoring is largely not scriptable today. Follow
[`agent-authoring-guide.md`](agent-authoring-guide.md) to build all ten agents (eight planted + two
decoys) exactly per `AGENTS.md`. Where `pac solution export/import` works for your build, package the
agents to speed re-provisioning (see the `[verify]` note in `PLANNING.md`).

**Phase 6.5 — orphan Tom Dean.** After Onboarding Guide and Sales Nudge exist and their **shared
connections are owned by `tom.dean`**, disable Tom's account (the marker from Phase 2). The agents and
connections must remain live — that is the orphan.

### Phase 7 — Export the artifact pack

```powershell
pwsh setup/scripts/05_export_artifact_pack.ps1 -OutDir ../worksheets/artifact-pack
```

Pulls agents/connections/identities/users/environments from PPAC admin APIs + Microsoft Graph and writes
the five canonical CSVs. Diff against the committed pack; the committed files ARE the expected output for
the canonical estate.

### Phase 8 — Validate

Walk `AGENTS.md` and confirm, in the live tenant:
- Every **PLANTED PROBLEM** reproduces (A–F fire; discovery targets are findable).
- Every **CONTROL EFFICACY** verdict holds; resolve any `[verify]` items and update `AGENTS.md`.
- Guest (Ana) read access works; the Jordan Blake confused-deputy path works.
- `pwsh setup/scripts/05_export_artifact_pack.ps1` output matches the committed pack.

### Phase 9 — Teardown / reseed

```powershell
pwsh setup/scripts/99_teardown.ps1        # removes agents, connections, sites, tables, personas
az group delete -n rg-halcourt-lab --yes  # removes the Azure endpoints
```

To reseed between deliveries, re-run Phases 3–7 (Entra personas in Phase 2 can persist).

## File index (this kit)

| Path | Purpose |
|---|---|
| `infra/main.bicep` | Policy API + Underwriting MCP Container Apps |
| `infra/policy-api/` | Minimal, intentionally over-scoped Policy API (static key) |
| `infra/mcp-underwriting/` | Minimal Underwriting MCP server (static bearer, `run_query`) |
| `scripts/01_provision_entra.ps1` | Personas, groups, `svc-claims`, shared mailbox |
| `scripts/02_provision_environments_dlp.ps1` | Environments, prod DLP, CA baseline |
| `scripts/03_provision_sharepoint.ps1` | Sites + FAQ + **plant poisoned doc** |
| `scripts/04_provision_dataverse.ps1` | Claim/Customer tables, PII rows, over-broad role |
| `scripts/05_export_artifact_pack.ps1` | Regenerate the artifact-pack CSVs |
| `scripts/99_teardown.ps1` | Remove the estate |
| `agent-authoring-guide.md` | Manual Copilot Studio authoring, per agent |
| `data/` | Seed data + the poisoned-doc source |

{: warning}
Several script steps depend on 2026 product surfaces still settling (Agent 365 admin APIs, CA for
workload identities, `pac` agent commands). Lines marked `# [verify]` need confirmation against the
delivery-date tenant; treat them as the intended operation, not a guaranteed cmdlet.
