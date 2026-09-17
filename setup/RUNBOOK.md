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
lab-dedicated admin credential — never corporate SSO**.

1. **Sign up for a new M365 tenant** via the **Microsoft 365 Developer Program**
   (https://developer.microsoft.com/microsoft-365/dev-program) — a 90-day renewable E5 sandbox.
   - Choose the **"Instant sandbox (Add-on purchases enabled)"** variant (alternatives in Errata).
   - Provide an **Azure billing account** for the one-time verification (not charged). Create it ahead of
     time — it can take ~15 min to a few hours to appear (if it still doesn't appear, see Errata).
   - Pick the **data-center region** at signup — it cannot be changed afterward.
   - Choose **"Create a new account" / personal or lab email** — never corporate SSO.
   - Set the **organization name** to land `halcourtmutual.onmicrosoft.com` (auto-assigned from the org
     name). If taken, pick a variant and pass it to the scripts with `-DomainSuffix <domain>.onmicrosoft.com`.
   - The optional **content / sample-data pack** is fine to install — its ~16 users can be mapped to
     Halcourt personas in Phase 2, saving license seats (see Errata).

2. **Complete initial tenant setup.**
   - Finish the wizard: create the **global administrator** account and record the UPN (the technician
     identity the rest of the runbook uses).
   - **Confirm MFA is registered** on the global admin account (the tenant wizard may have already required
     this). Verify in **Entra admin center** (https://entra.microsoft.com) → admin user → **Authentication
     methods**.
   - **Record the tenant's data-center region:** in the admin center, **Settings → Org settings → Organization
     profile → Data location** (or Entra → Properties). Note the region — you'll reuse it as the Azure region
     for the Phase 1 `azd` deployment (`azd` prompts for `AZURE_LOCATION`). The region is immutable; if it is
     wrong the only fix is a new tenant.
   - Confirm the global admin holds **Power Platform admin, Entra admin, SharePoint admin, Purview,
     Conditional Access, and Defender** access (in a fresh tenant Global Administrator covers all of these;
     see Errata if splitting duties).

3. **Add and assign licensing.**
   - **M365 E5** (incl. the Developer SKU): already provided by the sandbox; covers the Purview features the
     labs use.
   - Assign the **E5 per-seat SKUs** in **Billing → Licenses** to the global admin (and the Phase 2 personas
     later).

4. **Phase 0 verification checklist.**
   - Global admin can **sign in** to https://admin.microsoft.com with MFA satisfied.
   - **Licensing shows assigned** (E5) on the admin account.
   - **An Azure subscription is usable** — you hold **Contributor** on it (the basis for later Copilot Studio
     PAYG billing plans; see Errata).
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

   Once these pass, proceed to Phase 1.

### Phase 1 — Azure infrastructure (azd up)

Provisions the whole project with `azd up`: the demo **web** app + Foundry, plus the internal
**Policy API** and **Underwriting MCP** server as Container Apps. The latter two are intentionally weak
(static-secret auth, over-scoped surface) — see `setup/infra/policy-api/` and `setup/infra/mcp-underwriting/`.

{: important}
Everything deploys into the **same Azure Plan / subscription** set up in Phase 0 (see Errata —
Azure spend). No separate billing setup.

```bash
azd auth login
azd env new halcourt-lab          # RG will be rg-halcourt-lab (azd creates it)
azd env set POLICY_API_KEY "lab-$(openssl rand -hex 8)"   # any lab-only string — RECORD it
azd env set MCP_BEARER   "lab-$(openssl rand -hex 8)"     # any lab-only string — RECORD it
azd up                            # provisions + builds/pushes all images + deploys
azd env get-values                # read POLICY_API_FQDN / UNDERWRITING_MCP_FQDN
```

Record both secret values as you set them — you'll need them again later.

`azd up` deploys the entire project (the demo web app + Foundry + the two weak apps) into
`rg-halcourt-lab`.

Record the two Container App FQDNs from `azd env get-values` (`POLICY_API_FQDN` /
`UNDERWRITING_MCP_FQDN`) — of the form
`ca-policyapi-<suffix>.<region>.azurecontainerapps.io` and
`ca-underwritingmcp-<suffix>.<region>.azurecontainerapps.io`. These default `*.azurecontainerapps.io`
FQDNs (no custom domain, no DNS to configure) are exactly what the agents' actions point at: they become
the `<policy-api-fqdn>` and `<mcp-fqdn>` values used in `agent-authoring-guide.md`. The **static API key**
you pass here is the one that will sit in Policy Lookup Bot's HTTP action config (that exposure is the
point of Scenario E).

### Phase 2 — Entra identities & personas

**Prerequisites:** the **Microsoft.Graph** PowerShell module — the script calls `Connect-MgGraph` with
`User.ReadWrite.All` and `Group.ReadWrite.All` — plus **ExchangeOnlineManagement** for the shared-mailbox
step below.

```powershell
pwsh setup/scripts/01_provision_entra.ps1 -TenantId <tenant>
```

Creates the eight personas in `AGENTS.md` (Ana, Marcus, Priya, Sam, Lena, Dev, **Tom Dean** — created
enabled, disabled later in Phase 6.5 — and Jordan), the `svc-claims` service account, and the four groups
(`Halcourt-Makers`, `HR-Team`, `Claims-Adjusters`, `All-Employees`).

**The `it.helpdesk` shared mailbox is a separate manual step.** Graph can't create shared mailboxes, so the
script only prints a reminder — create it in Exchange Online:

```powershell
Connect-ExchangeOnline
New-Mailbox -Shared -Name "IT Helpdesk" -PrimarySmtpAddress it.helpdesk@<domain>
```

This mailbox is the ambiguous owner of Policy Lookup Bot (see `AGENTS.md`), so it must exist.

**Content pack installed?** The script has **no reuse mode** — it always creates all nine accounts. If the
Dev Program content pack seeded ~16 sample users (Adele Vance, Alex Wilber, etc. under **Users → Active
users**), running it as-is creates duplicates and can hit the sandbox **25-seat cap** (16 + 9 = 25, no
headroom). To reuse pack users, **hand-edit the `$people` array** in the script — comment out any persona a
pack user can cover — before running, then update `AGENTS.md` with the actual UPN mappings.

**Tom Dean stays enabled now.** In Phase 6.5 — only *after* his shared connections exist — disable him by
re-running `pwsh setup/scripts/01_provision_entra.ps1 -DisableDepartedOwner`, so the orphan is real.

### Phase 3 — Environments, DLP, Conditional Access

**Prerequisites:** the **Microsoft.PowerApps.Administration.PowerShell** module (`Add-PowerAppsAccount`) and
the **pac CLI**.

```powershell
pwsh setup/scripts/02_provision_environments_dlp.ps1
```

Creates the four environments (`Halcourt (default)`, `Halcourt-Prod`, `Claims-Test`, `Maker-Sandbox`) and
applies `Halcourt-Prod-DLP` to **Prod only**. It deliberately leaves Default / Claims-Test / Maker-Sandbox
**without DLP** — that gap drives Module 5. `Halcourt-Prod` is also marked a **Managed Environment**; the
script does this best-effort, so if the cmdlet path fails it says so — enable it by hand in PPAC and confirm
it took.

**Conditional Access is a separate manual step.** CA policies aren't creatable from the Power Platform
cmdlets, so the script only prints reminders. In **Entra ID**, create the baseline `CA-Require-MFA-Admins`
and `CA-Block-Legacy-Auth`, and deliberately create **no** CA policy targeting workload/agent identities —
that omission is a planted Module 5 finding.

**Then wire Copilot Studio pay-as-you-go billing (manual).** Do this only after the environments exist —
the billing plan is region-locked and must match the environment's region, so the environment has to come
first. Work in this order:

1. **Confirm what region each Dataverse-backed environment landed in.** In PPAC
   (https://admin.powerplatform.microsoft.com) → **Manage → Environments**, open each estate environment
   (`Halcourt-Prod`, `Claims-Test`) and read the **Region** column / detail. The script pins
   `-Location 'unitedstates'`, so they should read **United States** — but verify, because this region
   drives the next step.
2. **Create the billing plan in that SAME region.** PPAC → **Licensing → Billing Plans → + New billing
   plan → Azure subscription**. Name it → pick the **Azure subscription** and **resource group** → set the
   **Meter** to **Copilot Studio** (Dataverse is auto-included) → **Next**. On **Select environments**, set
   the **Region** filter to match the environment's region (**United States**), then **check** the
   Dataverse-backed estate environments (`Halcourt-Prod`, `Claims-Test`) → **Save**.
3. **Mind the region-lock.** A billing plan is locked to one region and only lists environments in that
   region. If an environment landed in a different region than the plan, the two will **not** link — the
   environment won't appear in the plan's picker, and the plan won't appear in the environment's billing-plan
   dropdown. Keep both in **United States** (see Errata for the full region-lock explanation).

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
decoys) exactly per `AGENTS.md`.

{: important}
Author agents **only in the Phase 3 Dataverse-backed environments** (`Halcourt-Prod`, `Claims-Test`) — the
default environment has no Dataverse (if Copilot Studio shows no target environment, see Errata).

**Phase 6.5 — orphan Tom Dean.** After Onboarding Guide and Sales Nudge exist and their **shared
connections are owned by `tom.dean`**, disable Tom's account by re-running
`pwsh setup/scripts/01_provision_entra.ps1 -DisableDepartedOwner`. The agents and connections must remain
live — that is the orphan.

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
| `infra/` (root azd project) | Deploys web + Foundry + Policy API + Underwriting MCP Container Apps via `azd up` |
| `setup/infra/policy-api/` | Minimal, intentionally over-scoped Policy API (static key) |
| `setup/infra/mcp-underwriting/` | Minimal Underwriting MCP server (static bearer, `run_query`) |
| `scripts/01_provision_entra.ps1` | Personas, groups, `svc-claims`, shared mailbox |
| `scripts/02_provision_environments_dlp.ps1` | Environments, prod DLP, CA baseline |
| `scripts/03_provision_sharepoint.ps1` | Sites + FAQ + **plant poisoned doc** |
| `scripts/04_provision_dataverse.ps1` | Claim/Customer tables, PII rows, over-broad role |
| `scripts/05_export_artifact_pack.ps1` | Regenerate the artifact-pack CSVs |
| `scripts/99_teardown.ps1` | Remove the estate |
| `agent-authoring-guide.md` | Manual Copilot Studio authoring, per agent |
| `data/` | Seed data + the poisoned-doc source |
| `../reference/runbook-errata.md` | Errata, options, known issues for this runbook |

{: warning}
Several script steps depend on 2026 product surfaces still settling (CA for workload identities, `pac`
agent commands). Lines marked `# [verify]` need confirmation against the
delivery-date tenant; treat them as the intended operation, not a guaranteed cmdlet.

## Errata, options & known issues

Moved to [`../reference/runbook-errata.md`](../reference/runbook-errata.md) — background, alternatives,
troubleshooting, and open `[verify]` risks, keyed to the phase/step they relate to.
