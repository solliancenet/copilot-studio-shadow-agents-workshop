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
     profile → Data location** (or Entra → Properties). Note the region — you will use it for the Phase 1
     `az group create -l` flag. The region is immutable; if it is wrong the only fix is a new tenant.
   - Confirm the global admin holds **Power Platform admin, Entra admin, SharePoint admin, Purview,
     Conditional Access, and Defender** access (in a fresh tenant Global Administrator covers all of these;
     see Errata if splitting duties).

3. **Add and assign licensing** (two separate things — see Errata for how they meter and bill).
   - **M365 E5** (incl. the Developer SKU): already provided by the sandbox; covers the Purview features the
     labs use.
   - **Copilot Studio:** enable **Copilot Credits** via **Marketplace** (main left nav) → search "Copilot."
     For a lab tenant, the **Microsoft Copilot Studio Trial** ("License granting message capacity") avoids the
     $200/mo paid SKU. Both options need the active Azure Plan from step 1's billing setup.
   - To check assigned per-seat licenses: **Billing → Licenses**. To purchase add-ons or enable Copilot
     Credits: **Marketplace** (main nav).
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

### Phase 1 — Azure infrastructure (Bicep)

Deploys the internal **Policy API** and the **Underwriting MCP** server as Container Apps. Both are
intentionally weak (static-secret auth, over-scoped surface) — see `infra/policy-api/` and
`infra/mcp-underwriting/`.

{: important}
These Container Apps deploy into the **same Azure Plan / subscription** set up in Phase 0 (see Errata —
Azure spend). No separate billing setup.

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

If the Dev Program **content pack** was installed (~16 sample users such as Adele Vance, Alex Wilber, etc.
visible in **Users → Active users**), map existing content-pack users to Halcourt personas instead of
creating duplicates — the sandbox has a 25-seat cap. Only create accounts the pack does not cover (e.g.
`svc-claims` service account, `it.helpdesk` shared mailbox, and any persona with no reasonable content-pack
match). Pass `-ReuseContentPack` (or equivalent) to the script, and update `AGENTS.md` with the actual UPN
mappings.

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

## Errata, options & known issues

Background, alternatives, troubleshooting, and open `[verify]` risks pulled out of the phase steps above so
the phases stay terse. Keyed to the phase/step they relate to.

### Phase 0 · sandbox variant tradeoff

Choosing the Dev Program sandbox variant is not a free pick:

- **"Instant sandbox (Add-on purchases enabled)"** — REQUIRED if you intend to buy Copilot Studio /
  Copilot Credits / any add-on directly in this tenant (step 3 and Phase 6 need this). But it pulls in the
  **billing / Azure-plan gate**: the tenant must be linked to a billing account that carries an **active
  Azure Plan** before the add-on purchase surfaces work, and before Dataverse capacity can be added (see the
  Dataverse-capacity items below).
- **Plain "Instant sandbox"** — avoids the billing gate entirely, but **cannot purchase add-ons**. Fine only
  if you can source Copilot Studio capacity and Dataverse capacity another way; otherwise you will hit a wall
  at step 3 / Phase 3.
- **Recommendation for building the estate:** the estate publishes 10 agents on Dataverse-backed
  environments, so you almost certainly need the **Add-on-purchases-enabled** variant and must complete the
  billing/Azure-plan setup. Pick the plain variant only for a throwaway UI walkthrough that never provisions
  agents.

### Phase 0 · billing account not showing in the dropdown

The Dev Program setup requires an **Azure billing account** for a one-time verification. You are **not
charged** — it is used only to transfer the developer subscription. A **newly created billing account can
take ~15 minutes to a few hours** to appear in the setup dialog's billing-account dropdown, so create it
ahead of time if you can.

**Billing account present but still not in the dropdown?** An **MCA billing account** can exist *with* a
billing profile *and* an invoice section and still **not appear** — because it has **no active Azure Plan**.
The dropdown only lists billing accounts that carry an active Azure Plan. Fix: create an **Azure Plan
subscription** under that billing profile / invoice section — **Azure portal → Subscriptions → Add → select
the MCA billing account, billing profile, and invoice section → choose "Microsoft Azure Plan"**. This
provisions the plan and populates the Dev Program dropdown within a short propagation window. You need a
billing role that can create subscriptions — **owner or contributor on the billing profile / invoice
section** (a plain tenant Global Admin without a billing role cannot do this). This is the **same Azure-plan
setup Phase 1 needs** for the Container Apps spend — do it once, here, and Phase 1 reuses it.

### Phase 0 · domain and region are fixed

The sandbox **domain is preconfigured and not customizable** — auto-assigned an `*.onmicrosoft.com` domain
whose prefix comes from the **organization name** you type in the wizard (aim for
`halcourtmutual.onmicrosoft.com`; the estate identities are written against that canonical domain). The
**data-center region is chosen at signup and cannot be changed afterward**, so pick the region you deliver
from. The result is a standalone tenant with its own domain that shares no trust with production.

### Phase 0 · Dev Program fallback

If the Dev Program path is unavailable to you, fall back to a **paid Microsoft 365 E5 trial** at
https://www.microsoft.com/microsoft-365/enterprise/e5.

### Phase 0 · content pack / sample users

The Dev Program offers an optional **content pack** that seeds the tenant with ~16 sample users and demo
data. If installed, those users appear in `users-export.csv` at Phase 7 and change the diff against the
committed artifact pack. **Preferred approach:** map content-pack users to Halcourt personas (see Phase 2)
so they serve double duty. If that is not feasible, either remove the sample users before Phase 7 or filter
them from the diff. The committed artifact pack must reflect whichever approach you chose.

### Phase 0 · splitting admin duties

The Phase 0 global admin ends up holding every admin role the runbook needs: **Power Platform admin, Entra
admin, SharePoint admin**, and — for the Module 5 CONTROL work — **Purview, Conditional Access, and
Defender** access. In a fresh tenant the Global Administrator covers all of these; if you split duties onto a
separate technician later, grant those roles explicitly in Entra.

### Phase 0 · licensing details

The licensing in step 3 is **two separate things** — do NOT treat "Copilot Studio / M365 E5 / Purview" as
one bundle you buy once. They license, meter, and bill differently:

- **M365 E5 (incl. the Developer SKU):** what the Dev Program sandbox already gives you. It covers most of
  **Purview** — sensitivity labels, DLP, audit — used in the Module 5 CONTROL work. No separate purchase for
  the Purview features the labs touch; confirm the specific Purview capabilities against the tenant rather
  than assuming E5 covers every one.
- **Copilot Studio — a SEPARATE, publish-capable license, with three ways to buy it.** The tenant needs one
  of these before it can *publish* agents (the estate publishes 10):
  - **Standalone prepaid Copilot Credit pack subscription** — tenant-pooled Copilot Credits bought as a
    product in **Billing → Purchase services**. Publishes on any channel; **no Azure subscription needed**.
    Capacity is enforced monthly (unused credits do not roll over; **125% overage disables custom agents**).
    Note the "free" Copilot Studio maker/user license itself **requires** a tenant prepaid pack first — there
    is no truly-free publish path.
  - **Pay-as-you-go (PAYG)** — consumption billed to an **Azure subscription** via a **PPAC billing plan**
    (PPAC → Licensing → **Billing Plans** → New billing plan → Azure subscription → Meter = **Copilot
    Studio** → Select environments). The M365 admin center's own "Pay-as-you-go" page does **not** meter
    Copilot Studio (its Services tab has no Copilot Studio entry) — don't create a policy there for this.
    Needs an Azure subscription with Contributor; no 125% cutoff (overage just bills through).
  - **Copilot Credits prepurchase plan (CCCUs)** — one-year prepaid pool bought in the Azure portal; **also**
    needs a billing policy → Azure subscription.
  Currency is **Copilot Credits** (renamed from "messages" on 2025-09-01). A **Microsoft 365 Copilot USL**
  zero-rates only **authenticated, employee-facing (B2E)** agent use — it does **not** cover the estate's
  autonomously-triggered agents or web/unauthenticated channels, and the E5 dev sandbox does not include it.
  Full model comparison + verified sources: [`../reference/copilot-studio-billing.md`](../reference/copilot-studio-billing.md).
- Do not hard-code SKU strings; confirm against the tenant.

### Phase 0 · publish capability (resolved)

**RESOLVED — trial licenses cannot publish.** Per Microsoft's Copilot Studio licensing docs, a **trial
license can create and test agents (test-chat panel) but cannot publish them**. The estate publishes 10
agents, so a trial is a dead end — the tenant needs a **publish-capable** license (standalone prepaid Copilot
Credit pack, pay-as-you-go, or CCCU prepurchase; see "Phase 0 · licensing details" above). This is the same
billing/Azure-Plan dependency as the Dataverse-capacity gate — resolve the Azure Plan once (or use a prepaid
pack, which needs no Azure subscription). See [`../reference/copilot-studio-billing.md`](../reference/copilot-studio-billing.md) and [`../PLANNING.md`](../PLANNING.md).

### Phase 0 · Azure subscription for Copilot Studio PAYG

Pay-as-you-go bills Copilot Studio consumption to an **Azure subscription** via a billing policy. Before
creating the policy you need a subscription on which you hold **Owner or Contributor**.

- **Check for an EXISTING subscription first.** The Dev Program sandbox often already has one or more Azure
  subscriptions. If the billing-policy wizard's **Subscription** dropdown is empty or shows *"You don't have
  the Owner or Contributor role on any Azure subscription,"* the problem is usually **RBAC, not a missing
  subscription** — do **not** use "Create a new Azure subscription" (it fails with a generic *"we couldn't
  create the subscription"* when the real gap is permissions).
- **Grant yourself access:** **Entra admin center → Azure resources → "Access management for Azure
  resources"** → toggle on (elevates you to **User Access Administrator at root scope**), then **Azure portal
  → each Subscription → Access control (IAM) → Add role assignment → Contributor → yourself**. Wait a few
  minutes for propagation, then reopen the billing-policy wizard — the subscription now appears.
- **Only create a new subscription if none exist**, and only if you hold the **Azure subscription creator**
  role on the billing account.

### Phase 0 / Phase 3 · Dataverse capacity (the "0 GB gate" was disproven)

An earlier version of this runbook claimed the E5 Developer sandbox ships with **0 GB Dataverse capacity** and
therefore blocks creating a Dataverse-backed environment. **A live run on 2026-09-08 disproved that:** the
sandbox carried **5 GB prepaid Database capacity** (PPAC → Licensing → **Capacity add-ons → Dataverse** showed
Database 1 GB / 5 GB), and `Claims-Test` (Sandbox + Dataverse) provisioned normally, consuming 1 GB of prepaid
— **no PAYG, no add-on, no capacity error.**

- **Check current capacity:** PPAC → **Licensing → Capacity add-ons → Dataverse** (or the new Dataverse
  licensing experience). Confirm **Database (Dataverse)** prepaid capacity exists; this replaced the old
  "Resources → Capacity" page.
- **Do not treat capacity as a hard gate.** Verify the actual number per tenant (don't assume 0, and don't
  assume 5 — it may differ). Only if a tenant genuinely has **0 GB** would you need a **per-GB capacity
  add-on** or a **PAYG billing plan** (which grants 1 GB per pay-as-you-go environment).
- **Reactive check only:** if a Dataverse environment ever **fails to create citing capacity**, check
  **PPAC → Licensing → Capacity add-ons → Dataverse**; only a genuinely **0 GB** tenant needs an add-on or
  PAYG. Do not pre-check capacity before provisioning — it is not a gate.

### Phase 1 · Azure spend / shared billing setup

These Container Apps need an **Azure subscription** to bill against — the **same subscription** used for the
Phase 0 Copilot Studio PAYG billing policy. The Dev Program sandbox often already carries an Azure
subscription; the usual gate is **RBAC on it, not a missing Azure Plan** — resolve access once in Phase 0
(see "Phase 0 · Azure subscription for Copilot Studio PAYG") and reuse the same subscription here. `[verify]`
whether that subscription includes usable credit (the frequently-cited *~$200 / 30-day* MCA credit is
unconfirmed for the Dev Program subscription) or whether it bills straight through.

### Phase 3 · PAYG billing plan — region-lock & the wrong-plan trap

The click-by-click for creating and linking the Copilot Studio PAYG billing plan now lives in the main
**Phase 3** section above. This is the background on *why* the order and region matter.

**Region-lock (verified live, bit us on 2026-09-08):** a billing plan is **locked to one region** and only
lists environments **in that same region**. The New-environment picker uses a **Macro Region Geography**
("North America") that **auto-assigns a specific region** (it landed us in **Canada**), while the plan's
region list uses **specific** regions ("United States"). If they don't match, the environment won't appear in
the plan and the plan won't appear in the env's billing-plan dropdown. This is why the environment must be
created first and its actual region confirmed before you create the plan — the provisioning script pins
`-Location 'unitedstates'`, so create the billing plan in **United States** to match. Linking is
per-environment, production/sandbox only; it can also be turned on at environment-creation time via the
**"Pay-as-you-go with Azure?"** toggle.

**Do NOT** create the special **"Microsoft 365 Copilot Chat"** billing plan (it auto-provisions a
`Microsoft 365 Copilot Chat` environment) — that path is for unlicensed users consuming agents inside Copilot
Chat, not the custom published estate. Use the standard plan linked to your own environments.

### Phase 6 · agents require a Dataverse-backed environment

The **default environment has no Dataverse**, so you **cannot author agents there**. Author agents only in
the Phase 3 provisioned environments (`Halcourt-Prod`, `Claims-Test`), which are Dataverse-backed. If Copilot
Studio refuses to create an agent or shows no target environment, the Dataverse-capacity gate (Phase 0) was
not satisfied — go back and resolve it before continuing.

### Phase 6 · solution packaging

Where `pac solution export/import` works for your build, package the agents to speed re-provisioning (see the
`[verify]` note in `PLANNING.md`).
