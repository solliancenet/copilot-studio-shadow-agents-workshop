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
point these scripts at a production tenant. All external endpoints are Azure Container Apps with
their own default `*.azurecontainerapps.io` FQDNs, assigned at deploy time — no custom domain or DNS.

## Prerequisites (technician)

- Tooling on the build box:
  - Azure CLI (`az`) + Bicep, an Azure subscription for the Container Apps.
  - Power Platform CLI (`pac`).
  - PowerShell 7 with modules: `Microsoft.Graph`, `Microsoft.PowerApps.Administration.PowerShell`,
    `Microsoft.PowerApps.PowerShell`, `PnP.PowerShell`, `Microsoft.Xrm.Data.PowerShell` (or `pac`).

## Phase order (do NOT reorder)

```
0. Provision isolated tenant   → fresh *.onmicrosoft.com, licensing, Power Platform
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

### Phase 0 — Provision the isolated training tenant

Stands up the **brand-new, isolated** M365 / Power Platform tenant the rest of this runbook assumes.
Do this once per lab tenant; it is mostly a portal flow, so the steps below are UI actions, not scripts.

{: important}
This tenant **must not** be linked to any production or corporate tenant. Sign up with a **personal or
lab-dedicated admin credential — never corporate SSO**. The estate you are about to build is
deliberately vulnerable; it has to live somewhere you can break without touching a real org.

1. **Sign up for a new M365 tenant.**
   - Preferred path: get **Microsoft 365 E5** via the **Microsoft 365 Developer Program** —
     https://developer.microsoft.com/microsoft-365/dev-program — which provisions an instant E5 sandbox
     tenant. When it offers a sandbox type, choose **"Instant sandbox (Add-on purchases enabled)"** — this
     is the variant that lets you buy Copilot / add-on services directly from the sandbox, which later
     steps need. The sandbox is a **90-day renewable E5 subscription** preloaded with ~16 sample users
     (Phase 2 adds the lab personas alongside these).
   - Setup requires an **Azure billing account** for a one-time verification. You are **not charged** —
     it is used only to transfer the developer subscription. Note that a **newly created billing account
     can take ~15 minutes to a few hours** to appear in the setup dialog's billing-account dropdown, so
     create it ahead of time if you can.
   - The sandbox **domain is preconfigured and not customizable** — it is auto-assigned an
     `*.onmicrosoft.com` domain. The **data-center region is chosen at signup and cannot be changed
     afterward**, so pick the region you deliver from.
   - If for any reason the Dev Program path is unavailable to you, you can fall back to a **paid
     Microsoft 365 E5 trial** at https://www.microsoft.com/microsoft-365/enterprise/e5.
   - When asked to sign in, choose **"Create a new account" / use a personal or lab email** — do **not**
     authenticate with your corporate identity. The result is a standalone tenant with its own
     auto-assigned `*.onmicrosoft.com` domain that shares no trust with production.
   - The `*.onmicrosoft.com` prefix comes from the **organization name** you type in the wizard, so choose
     it to land `halcourtmutual.onmicrosoft.com` if that prefix is free — the estate identities are written
     against that canonical domain. If it is already taken, pick a close variant and pass it to the
     provisioning scripts with `-DomainSuffix <your-domain>.onmicrosoft.com`.

2. **Complete initial tenant setup.**
   - Finish the sign-up wizard: create the **global administrator** account (record the UPN — this is the
     technician identity the rest of the runbook uses).
   - In **Entra admin center** (https://entra.microsoft.com) → the admin user → **Authentication
     methods**, register **MFA** on the global admin. Do this before assigning any other access.
   - In **Microsoft 365 admin center** (https://admin.microsoft.com) → **Settings → Org settings →
     Organization profile**, confirm the **tenant region / data location** shows the region you chose at
     signup (it is read-only here — the region was fixed at signup and cannot be changed).
   - This global admin ends up holding every admin role the rest of the runbook needs: **Power Platform
     admin, Entra admin, SharePoint admin**, and — for the Module 5 CONTROL work — **Purview,
     Conditional Access, and Defender** access. In a fresh tenant the Global Administrator covers all of
     these; if you split duties onto a separate technician later, grant those roles explicitly in Entra.

3. **Add and assign licensing.**
   - The estate needs **Copilot Studio**, **M365 E5 / Agent 365**, and **Purview** (same set the
     Prerequisites section lists). In **M365 admin center → Billing → Purchase services**, add the
     trial/purchased SKUs that cover them.
   - In **Billing → Licenses**, assign the SKUs to the global admin (and later to the personas Phase 2
     creates).
   - `[verify]` exact 2026 SKU names and whether Copilot Studio / Agent 365 / Purview are bundled into
     E5 or purchased separately — this is the same open dependency tracked in
     [`../PLANNING.md`](../PLANNING.md). Do not hard-code SKU strings here; confirm against the tenant.

4. **Enable the Power Platform side.**
   - Open the **Power Platform admin center** (PPAC, https://admin.powerplatform.microsoft.com) as the
     global admin and confirm the **default environment** exists (M365 provisions one automatically). If
     it is missing, `[verify]` tenant provisioning has finished and create it.
   - Open **Copilot Studio** (https://copilotstudio.microsoft.com) as the same admin and confirm it loads
     and can reach the default environment — this is where Phase 6 authors the agents.

5. **Phase 0 verification checklist.**
   - Global admin can **sign in** to https://admin.microsoft.com with MFA satisfied.
   - **PPAC loads** and shows the default environment.
   - **Copilot Studio loads** for the admin.
   - **Licensing shows assigned** (Copilot Studio / E5-Agent 365 / Purview) on the admin account.
   - The build-box tooling from **Prerequisites** is installed and authenticated **against the new
     tenant**:

     ```bash
     az login --allow-no-subscriptions          # sign in as the lab global admin
     az account show                            # confirm the new tenant id
     pac auth create --name halcourt-lab        # Power Platform CLI → new tenant
     pac org list                               # confirm the default environment is visible
     ```

     ```powershell
     Connect-MgGraph -TenantId <yourlab>.onmicrosoft.com   # Microsoft.Graph
     Get-MgOrganization | Select DisplayName, Id           # confirm the new tenant
     Add-PowerAppsAccount                                  # PowerApps admin modules
     ```

   Once all five check, proceed to Phase 1.

### Phase 1 — Azure infrastructure (Bicep)

Deploys the internal **Policy API** and the **Underwriting MCP** server as Container Apps. Both are
intentionally weak (static-secret auth, over-scoped surface) — see `infra/policy-api/` and
`infra/mcp-underwriting/`.

```bash
az group create -n rg-halcourt-lab -l eastus
az deployment group create -g rg-halcourt-lab -f setup/infra/main.bicep \
  -p policyApiKey='<generate-a-lab-only-key>' mcpBearer='<generate-a-lab-only-token>'
```

Record the two Container App FQDNs from the deployment outputs — of the form
`ca-policyapi-<suffix>.<region>.azurecontainerapps.io` and
`ca-underwritingmcp-<suffix>.<region>.azurecontainerapps.io`. These default `*.azurecontainerapps.io`
FQDNs (no custom domain, no DNS to configure) are exactly what the agents' actions point at: they become
the `<policy-api-fqdn>` and `<mcp-fqdn>` values used in `agent-authoring-guide.md`. The **static API key**
you pass here is the one that will sit in Policy Lookup Bot's HTTP action config (that exposure is the
point of Scenario E).

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
pwsh setup/scripts/03_provision_sharepoint.ps1 `
  -TenantAdminUrl https://<tenant>-admin.sharepoint.com `
  -RootSiteUrl https://<tenant>.sharepoint.com
```

Creates `HR-Benefits` (with a `Leadership/` subfolder holding `2026-comp-bands.xlsx`) and
`Claims-Knowledge`, uploads the FAQ library, and **plants `Open-Enrollment-FAQ.docx`** built from
`setup/data/Open-Enrollment-FAQ.md` (which carries the indirect-injection payload — see the SPOILER block
in `AGENTS.md`). The whole-site grounding + the leadership folder are what make Scenarios A and B fire.

### Phase 5 — Dataverse seed

```powershell
pwsh setup/scripts/04_provision_dataverse.ps1 `
  -ClaimsTestEnvUrl https://<org>.crm.dynamics.com
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
pwsh setup/scripts/05_export_artifact_pack.ps1
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
