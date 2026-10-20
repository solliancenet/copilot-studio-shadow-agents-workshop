# Runbook — errata, options & known issues

> Known issues, troubleshooting and open `[verify]` risks for the
> [provisioning runbook](../setup/RUNBOOK.md). Keyed to the phase/step they relate to. The *why* behind
> the runbook's design — decisions, tradeoffs and manual alternatives — is in
> [`runbook-decisions.md`](runbook-decisions.md).

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

The sandbox **domain is preconfigured and not customizable** — signup assigns an `*.onmicrosoft.com` domain,
and it may be random (the tenant verified on 2026-09-18 got `0zwdt94t.onmicrosoft.com`). It won't be the
canon's `halcourtmutual.onmicrosoft.com`, and doesn't need to be: `01_provision_entra.ps1` builds the
personas on the tenant's default verified domain, and the later scripts find accounts by alias (runbook
Phase 2). The **data-center region is chosen at signup and cannot be changed afterward**, so pick the region
you deliver from. The result is a standalone tenant with its own domain that shares no trust with production.

### Phase 0 · Dev Program fallback

If the Dev Program path is unavailable to you, fall back to a **paid Microsoft 365 E5 trial** at
https://www.microsoft.com/microsoft-365/enterprise/e5.

### Phase 0 · content pack / sample users

The Dev Program offers an optional **content pack** that seeds the tenant with ~16 sample users and demo
data. They don't collide with the personas — **don't** repurpose them as personas: the persona names and
aliases are canon, used by `AGENTS.md`, the artifact pack and the lab pages. Two real effects:

- **License seats.** The sample users hold E5 developer seats (25 in all; 19 were taken on the tenant
  verified 2026-09-18 — 16 sample users plus admins). Unassign sample users you don't need to free seats for
  the personas.
- **Phase 7 diff.** Sample users appear in `users-export.csv`. Filter them out (or delete them) before
  diffing against the committed pack.

### Phase 0 · security defaults → Conditional Access baseline (troubleshooting)

Why the swap is mandatory is in the runbook (Phase 0, step 4). What goes wrong along the way (verified live
2026-09-18):

- **AADSTS530035 "Access has been blocked by security defaults"** on a device-code sign-in (`az`, `pac`,
  `Connect-MgGraph`, PnP): security defaults are still on — or were turned off only minutes ago. Sign-ins lag
  the switch: one minute after the script, a device-code sign-in still failed with 530035; seven minutes
  after, it worked. The browser shows only *"You don't have access to this"*; the sign-in log
  (`originalTransferMethod = deviceCodeFlow`, error 530035) says why. Browser sign-ins from the host or the
  Windows VM still work meanwhile.
- **A second `pac` profile for the same account replaces the first.** `pac auth create --name other` as the
  same user dropped `halcourt-lab`, and deleting `other` then left no profiles at all. Keep one profile per
  account; recreate `halcourt-lab` if it disappears.
- **"Security Defaults is enabled in the tenant. You must disable Security defaults before enabling a
  Conditional Access policy"** right after turning them off: the change takes a few seconds to reach
  Conditional Access. `00_conditional_access_baseline.ps1` retries that error for up to 3 minutes.
- **"Connect-MgGraph did not establish a session"**: the browser step wasn't finished within
  `Connect-MgGraph`'s fixed 2-minute window (it can't be extended). A consent given just after the window
  still sticks — the re-run only needs the account pick.
- **AADSTS65001** on Graph: the requested scope has no consent yet. Consent for the organization once (runbook
  Phase 0, step 5 → *Microsoft Graph needs admin consent*).
- **Device codes blocked again later**: Microsoft can add *Microsoft-managed* Conditional Access policies to a
  tenant once security defaults are off. One that restricts *authentication flows* blocks device codes the
  same way — exclude the build admin from it. The script's summary flags such policies.

### Phase 0 · splitting admin duties

The Phase 0 global admin ends up holding every admin role the runbook needs: **Power Platform admin, Entra
admin, SharePoint admin**, and — for the Module 5 CONTROL work — **Purview, Conditional Access, and
Defender** access. In a fresh tenant the Global Administrator covers all of these; if you split duties onto a
separate technician later, grant those roles explicitly in Entra.

### Phase 2 · group membership (resolved 2026-09-19)

`01_provision_entra.ps1` used to create the four groups with **no members**, and `AGENTS.md` didn't say who
belonged in them. Both are fixed: `AGENTS.md` → *Groups* is canon, the script fills each group (adding only
missing members), and Phase 4 grants SharePoint access through `HR-Team`, `Claims-Adjusters` and
`All-Employees`.

### Phase 0 · licensing details

The licensing in step 3 is **two separate things** — do NOT treat "Copilot Studio / M365 E5 / Purview" as
one bundle you buy once. They license, meter, and bill differently:

- **M365 E5 (incl. the Developer SKU):** what the Dev Program sandbox already gives you. It covers most of
  **Purview** — sensitivity labels, DLP, audit — used in the Module 5 CONTROL work. No separate purchase for
  the Purview features the labs touch; confirm the specific Purview capabilities against the tenant rather
  than assuming E5 covers every one.
- **Copilot Studio — a SEPARATE, publish-capable license, with three ways to buy it.** The tenant needs one
  of these before it can *publish* agents (the estate publishes 10):
  - **Standalone prepaid Copilot Credit pack subscription** — tenant-pooled Copilot Credits bought via
    **Marketplace** (main left nav) → search "Copilot." Publishes on any channel; **no Azure subscription needed**.
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

### Phase 1 · azd auth mode (`azd auth login` vs `az login`)

`azd auth login` works on a default azd install, which uses azd's own built-in auth. If azd is configured to **delegate to the az CLI** (`auth.useAzCliAuth=true`), `azd auth login` errors with *"current auth mode is 'az cli': 'azd auth login' is disabled when the auth mode is delegated"* — in that mode azd rides on your **`az login`** credential, so run `az login` instead. To switch azd back to its own store: `azd config set auth.useAzCliAuth false`, then `azd auth login`. Either way, keep the azd/az identity, tenant, and subscription the same to avoid confusion.

### Phase 1 · re-running azd / fresh environment

- **Re-run against an existing env:** `azd env select <name>` — do **not** `azd env new <name>` (errors *"environment already exists"*).
- **A brand-new env has no subscription/region.** Set them before `azd up`, or it fails non-interactively with *"prompt required … subscription"*:
  `azd env set AZURE_SUBSCRIPTION_ID <sub-guid>` and `azd env set AZURE_LOCATION <region>`.
- `SERVICE_*_IMAGE_NAME` / `SERVICE_*_RESOURCE_EXISTS` values linger in the env's `.env` after `azd down`; they are stale/cosmetic — ignore them.

### Phase 1 · `azd up` failed on the Foundry account — a race in the template, now fixed (2026-10-17)

Every rebuild used to end, after every Container App had deployed, with:

```text
RequestConflict: Another operation is in progress on the resource
  .../Microsoft.CognitiveServices/accounts/aif-<token>
```

The old note here called it transient — "the account is still settling from the teardown" — and said to
re-run `azd up`. **That was the wrong cause.** It reproduced on 2026-10-17 on a never-used environment
name, with no teardown before it. The real cause was in `infra/foundry.bicep`: the Foundry **project** and
the **model deployment** are both children of the account, nothing ordered them, ARM created both at once,
and the account accepts one operation at a time. A re-run only appeared to fix it because the deployment
had already finished the first time.

`foundryProject` now has `dependsOn: [ modelDeployment ]`. Verified the same day on a fresh environment:
provisioned **first time** in 3m50s, the five-check endpoint smoke test passed, and `azd down --purge
--force` left no resource group and nothing in soft-delete (teardown takes ~17 minutes).

Two corrections to the old note: on azd 1.32 the failed run exits **1**, not 0. And the deployment outputs
(`POLICY_API_FQDN`, `UNDERWRITING_MCP_FQDN`) are still only written by a clean run — Phase 6 needs them.

### Phase 1 · Foundry project soft-delete (AmlRp) — the re-provision trap

Distinct from the transient conflict above: this one does **not** clear on retry. Verified live
(2026-09-16). Tearing down and re-provisioning the **same** azd env name can dead-end the Foundry layer:

- `azd down --purge` does **not** purge the Foundry **project's** backing AmlRp workspace. It leaves a soft-deleted tombstone (`proj-<token>`) that blocks recreating the project name. Worse, **every failed `azd up` regenerates the tombstone**, so purge-and-retry never converges; the `aif-<token>` account can also stick in a `Failed` state.
- The tombstone is invisible to every discovery surface checked: the Foundry portal, the Azure ML **Recently deleted** blade, `az cognitiveservices account list-deleted`, and all `Microsoft.MachineLearningServices` `deletedWorkspaces`/workspace list api-versions.
- **Reliable fix — re-provision under a NEW env name** (`azd env new <name2>` → new `resourceToken` → an uncontaminated `proj-<newtoken>`). This deploys cleanly; the old poisoned name is simply abandoned.
- **Manual purge recipe (only if you must keep the same name):**
  1. Purge the project tombstone:
     `az rest --method delete --url "https://management.azure.com/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.MachineLearningServices/workspaces/proj-<token>?api-version=2026-03-01&forceToPurge=true"`
     (Use `az rest`, not `az ml workspace delete --permanently-delete` — the latter does a GET-before-DELETE that 404s on an invisible tombstone.)
  2. If the account is `Failed`/soft-deleted: `az cognitiveservices account delete -g <rg> -n aif-<token>` then `az cognitiveservices account purge -g <rg> -n aif-<token> -l <region>`.
  3. Retry `azd up`. Note this still loops if the underlying project create keeps failing — which is why the fresh-name path is preferred.

### Phase 3 · DLP cmdlet surface is unverified `[verify]`

The DLP portion of `02_provision_environments_dlp.ps1` is marked `[verify]` throughout — the `New-DlpPolicy`
/ `Set-DlpPolicy` parameter names, the `connectorGroups` classification schema, and the single-environment
scoping enum (`OnlyEnvironments`) are all unconfirmed against the delivery-date
Microsoft.PowerApps.Administration module. It may not apply cleanly. After running, **confirm
`Halcourt-Prod-DLP` exists, carries the intended business/non-business split, and is scoped to Halcourt-Prod
only** (PPAC → Data policies); re-scope or recreate by hand if the cmdlets drifted.

### Phase 5 · Dataverse Web API quirks (verified 2026-09-19)

- **Money column fails with 0x80040216 "An unexpected error occurred"** unless the `MoneyAttributeMetadata`
  carries `AttributeType: Money`, `AttributeTypeName: {Value: MoneyType}` and a `MinValue`/`MaxValue` range.
  `04_provision_dataverse.ps1` sends them.
- **A column can exist and still read as "does not exist"** until customizations are published — creating it
  again then fails with 0x80047013 "already exists". The script counts that as done.
- **`userNotLicensed`** when adding `svc-claims.<estate>` to the environment: Dataverse only takes licensed
  users. The script builds everything else and reports the role assignment PENDING until the account has one.
  A Microsoft 365 E5 developer seat (`DEVELOPERPACK_V2_E5`, whose free Dataverse plan counts for on-demand
  adds) is enough: after assigning one, a re-run added svc-claims as an enabled, licensed Read-Write user
  holding only the over-broad role — see RUNBOOK → Phase 5.
- **A new role comes with nine platform privileges** (SharePoint data, plugin/SDK message reads) besides the
  14 the script grants. They are Dataverse defaults, not part of the over-grant.

### Phase 3 · PAYG billing plan — region-lock & the wrong-plan trap

The click-by-click for creating and linking the Copilot Studio PAYG billing plan now lives in the main
**Phase 3** section above. This is the background on *why* the order and region matter.

**Region-lock (verified live, bit us on 2026-09-08):** a billing plan is **locked to one region** and only
lists environments **in that same region**. The New-environment picker uses a **Macro Region Geography**
("North America") that **auto-assigns a specific region** (it landed us in **Canada**), while the plan's
region list uses **specific** regions ("United States"). If they don't match, the environment won't appear in
the plan and the plan won't appear in the env's billing-plan dropdown. This is why the environment must be
created first and its actual region confirmed before you create the plan — the provisioning script can
only ask for a macro region, so create or pick the plan in the region its summary reports (**Canada** on
the verified tenant). Linking is per-environment, production/sandbox only; it can also be turned on at
environment-creation time via the **"Pay-as-you-go with Azure?"** toggle, or done by API (RUNBOOK → Phase
3). The verified tenant linked `Halcourt-Prod-mgray` and `Claims-Test-mgray` by API to an existing Canada
plan, `ppccdevcanada` (2026-09-19); that plan also still lists an environment that no longer exists
(`ce446a53-…`), which is harmless.

**Do NOT** create the special **"Microsoft 365 Copilot Chat"** billing plan (it auto-provisions a
`Microsoft 365 Copilot Chat` environment) — that path is for unlicensed users consuming agents inside Copilot
Chat, not the custom published estate. Use the standard plan linked to your own environments.

### Phase 6 · agents require a Dataverse-backed environment

Copilot Studio keeps agents in Dataverse, and a Dev Program tenant's **default environment has none** — yet
`AGENTS.md` puts Expense Helper and Onboarding Guide there. The fix is to add Dataverse to the default
environment once per tenant (RUNBOOK → Phase 6, *Before you build*, step 3); on the verified tenant it
provisioned in a few minutes (2026-09-19). If Copilot Studio still refuses to create an agent or shows no
target environment, check Dataverse capacity in **PPAC → Licensing → Capacity add-ons → Dataverse**.

### Phase 4 · the decoy needed its own clean FAQ library (fixed 2026-09-21)

`AGENTS.md` says the **HR FAQ v2 (copy)** decoy grounds on "a single all-staff FAQ library," but the estate
had none: the only FAQ document was the **poisoned** `Open-Enrollment-FAQ.docx` in `Shared Documents`, so
grounding the decoy there would have made it dirty. Fix: `03_provision_sharepoint.ps1` now also creates a
dedicated **`HR FAQ`** document library in `HR-Benefits` and uploads a clean, all-staff FAQ built from
`setup/data/HR-FAQ-Published.md` (no injection payload, no `Leadership/`). The library inherits the site's
permissions (`HasUniqueRoleAssignments = False`), so `All-Employees` read it. Point the decoy's SharePoint
knowledge at the library URL only — `https://<tenant>.sharepoint.com/sites/HR-Benefits-<estate>/HR FAQ` —
not the site root and not `Shared Documents`. Seeded live for estate `mgray` on 2026-09-21. A site **Member**
(Marcus, via the `Edit` permission level's *Manage Lists*) can create the library and upload, so no owner
rights are needed.

### Phase 4b · maker OneDrive won't auto-provision; app-only can't enqueue it (verified 2026-09-21)

The **Meeting Notes Summarizer** decoy grounds on Dev Kim's OneDrive, but a Dev Program sandbox does **not**
auto-provision it: the first browser visit dies with *"a default document library could not be created,"* and
Graph `/me/drive` stays `itemNotFound` for days. Dev's SharePoint service plans were fine
(`SHAREPOINTENTERPRISE`/`SHAREPOINTWAC` = Success), so it is not licensing — the personal site just needs an
admin enqueue (`Request-PnPPersonalSite`). Findings from getting it working:

- **App-only enqueue fails.** With the PnP app given `Sites.FullControl.All` **and** `User.ReadWrite.All`
  (application) + a cert, `Request-PnPPersonalSite` still returned *"Attempted to perform an unauthorized
  operation"* on every attempt over ~25 min — app-only isn't a SharePoint *admin* for the User Profile call.
- **`az ad app permission admin-consent` didn't create the application grants** — assign them directly with
  `POST …/servicePrincipals/<pnp-sp>/appRoleAssignments` (the two SharePoint roles above).
- **Interactive admin works** — the tenant admin (a real SharePoint admin, MFA) running the enqueue via
  `-DeviceLogin`/`-Interactive` succeeded, **once** the PnP app also had the **delegated** `User.ReadWrite.All`
  scope (first try without it: *"Access Denied: … permissions to access profile information"*). A persona
  can't stand in — elevating one to SharePoint admin trips CA MFA-for-admins (`AADSTS50079`).
- **Seeding is app-only and works** — once the site exists, `Add-PnPFile` app-only uploads the notes.
- **Graph `/me/drive` lags** the new personal site (still 404 right after), while SharePoint (where Copilot
  Studio reads) already serves the file. Verify via PnP (`Get-PnPFolderItem -FolderSiteRelativeUrl Documents`),
  not Graph.

Net: `03b_provision_onedrive.ps1` seeds app-only and skips provisioning if the site already exists.

> {: .note }
> **Superseded in part.** The 2026-09-22 rebuild re-tested every identity for the enqueue and found one more
> option — having the **maker touch their own drive**, which needs no admin at all — plus the reason a
> freshly created SharePoint admin still can't do it. The script now tries that first and falls back to the
> manual enqueue. See *Phase 4b · why OneDrive provisioning resists automation* below for the current
> behaviour; the findings above still hold and explain the app registration it depends on.

### Phase 3 / Phase 6 · a business/non-business DLP split blocks agent publish (verified 2026-09-21)

Publishing a connector-based Copilot Studio agent in Prod failed with **"There is a conflict between
business and non-business connectors"** — the planted `Halcourt-Prod-DLP`. Every agent implicitly pulls in
Copilot Studio **platform connectors**; with a business/non-business split (Dataverse etc. = business/
Confidential, default = non-business/General), some implicit connector lands in the non-business bucket and
the publish is blocked. Even after moving every *visible* connector (connection references AND the generated
flows: `shared_commondataserviceforapps`, `shared_conversionservice`) into Confidential, the conflict
persisted — the offending connector isn't surfaced anywhere queryable.

**Fix (decided with the facilitator):** set the policy's `defaultConnectorsClassification` to **Confidential**
(business-by-default) so there is no non-business bucket to conflict with, keep the sensitive connectors in
the business group, and block nothing. Agents then publish. `02_provision_environments_dlp.ps1` now builds
it this way. This does weaken the "split" demo, but the Module 5 lesson is intact: a DLP control exists on
Prod and it **MISSES** the agent-identity/connection risks (which no connector-DLP addresses). Knowledge-only
agents (Benefits Buddy, HR FAQ v2) were never affected; only agents with a connector **tool** trip it.

### Phase 6 · engine mechanics (`06_provision_agents.ps1`, verified 2026-09-21)

- **`pac copilot push` only UPDATES; `init`/`push` for create are flaky.** Push needs a *synced* local
  workspace; a committed workspace (gitignored `.mcs`) has none, and `init` alone doesn't reliably leave a
  cloneable/pushable one (it repeatedly failed, and delete→init races on solution-component cleanup). The
  robust pattern the engine settled on: **clone-first** — clone the agent into a temp dir (which always
  yields a synced workspace), drop the clone's server-state knowledge/tools/conn-refs, overlay the committed
  ones, push. If clone finds nothing the agent is absent → `init` the shell (retried), then clone. This
  **preserves the agent identity** (no delete) and is conflict-free.
- **Use pac's existence view, not the Dataverse `bots` table.** They disagree — most sharply in the shared
  **default environment, where the admin has no read on `bots`** (the query returns empty even though the
  agent exists and pac sees it; it looked like a "ghost agent" for a while). Clone-first sidesteps this.
- **All bot-record ops run AS THE OWNER, not admin.** Bot lookup, chat-audience PATCH and connection binding
  fail as admin in the default env (no `bots` read); and a connection reference can only be bound by the
  **connection's** owner (`ConnectionAuthorizationFailed` otherwise). The agent owner binds its own agent's
  refs; the connection owner (a SysAdmin in that env, e.g. Tom in Prod) binds connections it owns — so Tom must be
  enabled (he now always is; see *Phase 6.5: a disabled owner's connections die*).
- **Publisher prefix is stable per agent, not per env.** Don't rewrite it to the env's CDS Default Publisher
  (that duplicated an agent and mutated the committed source). Keep the committed prefix; ensure a publisher
  with it exists in the env (create on a fresh rebuild).
- **Publish right after create can fail silently** — retry and confirm the "Published successfully" result.
- **Connector-tool input `propertyName`s are BARE for body properties**, not path-style. A request-body
  object's fields are named directly: `url`/`method` for the HTTP connector's `InvokeHttp` (not `request/url`),
  `mm_status` for a Dataverse `UpdateRecord`'s `item` (not `item/mm_status`), `To`/`Subject`/`Body` for
  Outlook `SendEmailV2`. A wrong path fails the publish with **`InvalidPropertyPath`**, reported only in the
  bot's `synchronizationstatus`. Path/query params (`entityName`, `recordId`) are also bare.

### Phase 6 · what authors cleanly vs needs the portal (verified 2026-09-22)

Which planted agents can be **authored** as committed `pac` workspaces and which need a **portal build + clone**:

- **Author cleanly (connector tools):** Sales Nudge, Onboarding Guide, Claims Copilot — a `TaskDialog` with an
  `InvokeConnectorTaskAction` (`operationId` = the connector op, `connectionReference` = the bound connection,
  `connectionProperties.mode: Maker`) works. **Bind the connection as its owner** (System Customizer / SysAdmin
  in that env lets a non-agent-owner bind, e.g. svc-claims into Priya's Claims Copilot).
- **As TOOLS, only connectors publish; as TOPIC NODES, HTTP / MCP / flow all publish** (verified 2026-09-22).
  The dividing line is tool-vs-topic, not connector-vs-not. A `TaskDialog` + `InvokeConnectorTaskAction` (a
  *tool*) publishes; a `TaskDialog` whose action is the native **`HttpRequestAction`** or **`McpServerTool`**
  *pushes* but **fails to publish** ("Node is unknown to the system"). **But the same operations are valid
  DialogActions inside a *topic*** (an `AdaptiveDialog` with an `OnRecognizedIntent` trigger), and those
  **publish**. So every planted agent is authored from a committed workspace — no portal:
  - **Policy Lookup Bot:** a `topics/LookupPolicy.mcs.yml` — Question `policyId` → `HttpRequestAction` GET
    `${POLICY_API_FQDN}/policy/` & policyId, header `x-api-key: ${POLICY_API_KEY}` → SendActivity.
  - **Underwriting Assistant:** topics with **`InvokeMcpTool`** (self-contained: `serverUrl`
    `${UNDERWRITING_MCP_FQDN}/underwriting`, `headers.Authorization: Bearer ${MCP_BEARER}`, `toolName`,
    `arguments`, `output.result`) — one topic each for get_quote / get_risk_score / run_query (run_query is
    the planted over-scope). No separate MCP-tool component needed.
  - **Expense Helper:** a Copilot-triggered **flow** created as a Dataverse `workflow` record (category 5,
    trigger `type: Request, kind: VirtualAgent`, a `Response`/`VirtualAgent` action; owned by Sam), then a
    topic with **`InvokeFlowAction`** (`flowId`, `input.binding`, `output.binding`). Codified: the flow
    definition is `setup/data/expense-approve-flow.json`, the manifest's `flows` section declares it
    (name/owner/environment), and `06_provision_agents.ps1` creates + activates it (as the owner) **before**
    the agents, then resolves `${FLOW:<name>}` to its live id at provision time.
  - Topic node YAML shapes: `Question` (`variable: init:Topic.x`, `entity: StringPrebuiltEntity` /
    `NumberPrebuiltEntity`), `HttpRequestAction`/`InvokeMcpTool`/`InvokeFlowAction` as above, `SendActivity`
    (`activity: "..."`). The engine overlays committed `topics/` onto the clone's system topics (doesn't clean
    them). Secrets stay `${...}` tokens; the engine injects from azd + resolves flow ids, so nothing's in git.
- **Secrets stay out of git.** Committed workspaces use `${POLICY_API_FQDN}`, `${POLICY_API_KEY}`,
  `${UNDERWRITING_MCP_FQDN}`, `${MCP_BEARER}` tokens; `06_provision_agents.ps1` substitutes them from the Phase 1
  `azd env` at provision time, so the planted key lives only in the LIVE agent (which is the vulnerability).
- **`UpdateRecord` (write) tool:** the Dataverse update op's body is a dynamic per-table schema that the tool
  addresses differently than a fixed body; the read tools (`ListRecords`) author cleanly. Claims Copilot ships
  with list-claims + list-customers; the update-status tool is a `[verify]` follow-up.

### Phase 6 · build notes (verified 2026-09-19)

- **Owners need seats and a role in the environment.** Dataverse only adds licensed users, so an owner
  without a seat can't build there — the same `userNotLicensed` rule as `svc-claims` in Phase 5.
- **The *Copilot Studio authors* setting wasn't needed.** An unlicensed persona opened Copilot Studio in a
  pay-as-you-go-linked environment without it. It has no API, and the admin center needs the admin's MFA.
- **Agents in a Developer environment publish without a billing plan.** Team Wiki published in
  `Maker-Sandbox-mgray`, which no plan can link.
- **Agent identities are named `<agent name> (Microsoft Copilot Studio)`**, not `cs-agent-<slug>-<env>`, and
  appear when the agent is created (`agentIdentity`, `ServiceIdentity`). Estate ids aren't in the name.
- **OAuth connections can't be shared** — *ConnectionSharingNotAllowed* for the Dataverse connections the
  pack lists as shared with `Claims-Adjusters` / `Halcourt-Makers`. The live export's `shared_with` will be
  empty for them; the canon needs to say how they are "shared" (through the agent, with maker credentials).
- **Consent in the default environment adds a confirmation page** ("Confirmation required": tick *I have
  verified this request*, then **Allow access**) for a connection the signed-in user just created.
- **A OneDrive connection fails until the user's OneDrive exists** (the error names "No user OneDrive for
  Business"). A newly licensed persona has to open OneDrive once first.
- **`pac copilot push` sends instructions, knowledge and tools but not `settings.mcs.yml`**, and it creates
  connection references without binding them — set the chat audience and the connection on the Dataverse
  records ([decisions → Phase 6, *Building one agent from the command line*](runbook-decisions.md#building-one-agent-from-the-command-line)).
- **Tool inputs from a connector's request body use the property's bare name** (`url`, not `request/url` or
  `request.url`); a wrong one fails the publish with *InvalidPropertyPath*, reported only in the agent
  record's `synchronizationstatus`.
- **The Underwriting MCP server was rewritten as a real MCP server (2026-09-22).** The original
  `setup/infra/mcp-underwriting/server.js` served plain JSON over HTTP (`/tools`, `/call`), which Copilot
  Studio's MCP tool can't import. It now implements **MCP JSON-RPC 2.0 over the Streamable HTTP transport**
  (POST `/underwriting` handling `initialize`, `tools/list`, `tools/call`; a GET SSE stream; `Bearer`
  `${MCP_BEARER}` auth) exposing `get_quote`, `get_risk_score` and the over-scoped `run_query`. Redeploy with
  `azd deploy underwriting-mcp`. The weaknesses (one static bearer for all callers; over-wide tool surface)
  are unchanged — that is Scenario E.

### Phase 6 · solution packaging

Where `pac solution export/import` works for your build, package the agents to speed re-provisioning (see the
`[verify]` note in `PLANNING.md`).

## Findings from the 2026-09-22 greenfield rebuild

A full teardown and Phase 1-6 rebuild on a **freshly provisioned** estate surfaced a class of problem a
same-estate replay never hits: everything below is either a fresh-environment timing effect or an identity
that only an empty tenant reveals. All are already fixed in the scripts; they are recorded here so the
behaviour is recognisable when it recurs. Entries are keyed to their phase, like the rest of this file.

### Phase 2 · the `it.helpdesk` shared mailbox is scripted now

Graph cannot create a shared mailbox, but **`Connect-ExchangeOnline` accepts a delegated `-AccessToken`** —
so there is no need for a device code or a separate app-only Exchange app. `_auth.ps1` gained
`Connect-LabExchange`, which mints an Exchange token from the **existing `az` sign-in**
(`az account get-access-token --resource https://outlook.office365.com`), and Phase 2 runs `New-Mailbox
-Shared` itself. Verified end to end.

Exchange provisions the mailbox **asynchronously**, and a mailbox *type* change (`Set-Mailbox -Type Shared`)
likewise takes minutes to become visible — don't read either back immediately and conclude it failed.

### Phase 3 · billing by API — endpoint and schema

`02b_provision_billing.ps1` links this estate's Prod and Claims-Test to a plan in their region. Three things
are easy to get wrong:

- **Billing is not on BAP.** It lives on `api.powerplatform.com/licensing`; `api.bap.microsoft.com` rejects
  the `2022-03-01-preview` api-version outright, which looks like a bad request rather than a wrong host.
- **A policy's `environmentIds` reads as `null`.** The authoritative list of linked environments is the
  **`/billingPolicies/<id>/environments` sub-resource**, which is what the script reads to verify.
- **A plan is backed by an Azure resource.** `Microsoft.PowerPlatform/accounts` (body `{ "location":
  "Canada" }`, api `2020-10-30-preview`). Note the casing split: the ARM resource takes a title-case region
  (`Canada`) while the billing policy's `location` is the lower-case Power Platform region (`canada`), and
  that must match where Phase 3 actually put the environments.

### Phase 4 · headless (app-only) SharePoint seed

`03_provision_sharepoint.ps1` gained an app-only path (`-CertPath` / `-CertPassword` / `-SiteOwner`, or
`HALCOURT_PNP_CERT_PFX` / `_PW` / `HALCOURT_SITE_OWNER`) so the site seed runs with **no device code** —
what an automated rebuild needs. Two things make it work:

- It needs the Phase 4 PnP app to also hold the **Graph `Group.ReadWrite.All` _application_** role, because a
  team site is an M365 group and the group is created through Graph. SharePoint's `Sites.FullControl.All`
  alone gives a 403 there.
- **`New-PnPSite -Owners` cannot be used app-only**: it resolves to an empty `owners@odata.bind` and 400s,
  and a group created without an owner never gets its SharePoint site provisioned at all. So the app-only
  branch creates the backing M365 group **directly through Graph** with an explicit owner, then waits for
  SharePoint to provision the site (allow 15 min; a fresh tenant is slow).

For the record, app-only **is** a SharePoint admin for tenant *site* management (`Get`/`Remove-PnPTenantSite`,
`Get`/`Remove-PnPTenantDeletedSite`). The older blanket note that "app-only isn't a SharePoint admin" is true
only of `Request-PnPPersonalSite` — see Phase 4b below.

### Phase 4 · team-site URL collisions on a re-run

A group team site derives its URL from the mailNickname. If `/sites/<alias>` is still held by a
**soft-deleted** site from a previous run, SharePoint silently creates the new site at a **suffixed** URL
(`...-mgray9`) instead. The wait loop polls the canonical URL, so it times out even though provisioning
succeeded — and the estate ends up at a URL the agents do not ground on.

Purge the stale site before re-running, and purge the soft-deleted **group** too so the mailNickname frees:

```powershell
Remove-PnPTenantDeletedSite -Identity https://<tenant>.sharepoint.com/sites/<alias> -Force
```

A teardown that empties the SharePoint recycle bin avoids the whole problem.

### Phase 4b · why OneDrive provisioning resists automation

Creating a maker's OneDrive is the one call in this kit with no dependable headless path. Everything below
was tried on the verified tenant on 2026-09-22.

**What does not work, and why:**

| Identity | Result |
|---|---|
| App-only (certificate) | `Request-PnPPersonalSite` → *"Attempted to perform an unauthorized operation"*. Not a missing permission — the same token does other tenant-admin work fine. Personal-site provisioning wants a **user** context. |
| Azure CLI delegated token | **401 on every SharePoint tenant-admin call**, even as Global Admin (`aud` = SharePoint, `scp` = `user_impersonation`). SharePoint simply does not accept that app. Reusing the `az` sign-in works for Graph and Exchange, never for SharePoint admin. |
| A freshly created SharePoint Administrator | Signs in fine by password grant **through the PnP app** (SharePoint does accept that app), but the enqueue is *still* refused: **SharePoint does not honour a new SharePoint Administrator assignment for another 15-60 minutes**. |

That last row is why an **ephemeral-admin** design was tried and abandoned: it cannot complete inside a
provisioning run, and it would additionally need a Conditional Access exception, since the role pulls the
account into `CA-Require-MFA-Admins` and a password grant cannot satisfy MFA.

**What the script does instead — best effort, `[verify]`.** `03b_provision_onedrive.ps1` has the **maker
touch their own drive**: `GET /me/drive` as that user. Personas are ordinary users, so nothing in the CA
baseline blocks the password grant, and no administrator is involved. The call always answers
`ResourceNotFound` — that is expected — and *may* enqueue the personal site behind it.

Measured on the verified tenant, it works but is **not guaranteed** — treat it as best effort:

| Attempt | Outcome |
|---|---|
| `dev.kim`, 18:38 | site `Created` 18:38:57 — **within a minute** |
| `dev.kim`, 22:25, after the site was deleted **and purged** (true greenfield) | site `Created` 22:25:59 — **within a minute** |
| `lena.ford`, 19:38 | nothing 47 minutes later, on identical licensing (4 SharePoint service plans, all Enabled) |

Two clean successes against one unexplained failure, so the script tries it, waits, and if the site never
appears it fails with instructions to provision that one maker by hand and re-run — which then just seeds.
First-access provisioning is asynchronous with no published SLA, so don't build a timing assumption on it.

**Two traps when you test this yourself:**

- **Graph is not a readiness check.** `GET /users/<upn>/drive` kept returning `ResourceNotFound` for
  `dev.kim` **after** his OneDrive existed and had been written to. Probe the personal site with PnP
  (`Connect-PnPOnline -Url <my-site>/personal/<user>` then `Get-PnPWeb`) — that is what the script does.
- **Beware pre-existing drives.** Two of three personas already had OneDrives from earlier sessions
  (`marcus.webb` 09-21, `dev.kim` 09-19), so "it appeared after I called `/me/drive`" proves nothing. Check
  `Get-PnPWeb -Includes Created` on the personal site before believing any result.

**Teardown does not remove OneDrive personal sites.** `dev.kim`'s 09-19 OneDrive survived the full teardown
and was still present and writable for the 09-22 rebuild — which is why Phase 4b reported "already online". A
"greenfield" estate therefore inherits stale maker OneDrives, contents and all. Remove them deliberately if
that matters (`Remove-PnPTenantSite` against the `-my.sharepoint.com/personal/...` URL), and note that a
re-provision while the old one sits in the recycle bin lands on a **suffixed** URL
(`..._onmicrosoft_com1`) — the same collision as the team sites above.

### Phase 6 · the two default-environment agents are NOT estate-scoped `[verify]`

Every other agent lives in a per-estate environment, so estates never meet. **Expense Helper** and
**Onboarding Guide** live in `Halcourt (default)` — the one environment that cannot be per-estate — and only
their *display* name carries the estate id (`estateSuffixName: true` → "Expense Helper (mgray)"). Their
**schema names are fixed** in the committed workspaces:

```text
cr458_ExpenseHelper        cr458_OnboardingGuide
```

Dataverse keys on the **schema** name, not the display name. So a second estate built in the same tenant
tries to create an agent that already exists, owned by the first estate's maker, and Phase 6 fails with:

```text
user with id <owner> does not have WriteAccess right(s) for record with id <botid> of entity Agent
```

which surfaces only as `CREATE FAILED ... The async operation completed with a statuscode of Failed`. The
owner is another person's persona, so you cannot see or delete it — it looks identical to an orphan left by
a failed teardown (below), and the two are easy to confuse.

**Until the schema names are estate-scoped, treat the default environment as single-estate:** only one
estate per tenant can own Expense Helper and Onboarding Guide, and whoever owns them must delete them before
another estate builds. The real fix is to suffix the schema for agents flagged `estateSuffixName` — which
means rewriting the schema consistently across `settings.mcs.yml`, `agent.mcs.yml`, the knowledge file names
and every `<schema>.topic.*` cross-reference (get one wrong and publish fails with `InvalidReferenceError`,
exactly as the HR FAQ v2 decoy did).

### Teardown · delete the default-environment agents, or the NEXT build cannot recreate them

The worst failure found in the 2026-09-22 rebuild, because it is silent until much later and then
unrecoverable without a human.

**What happens.** Teardown removes this estate's two agents from the **shared default environment**
(Expense Helper, Onboarding Guide) with a Dataverse `DELETE`. A **published** agent refuses that with a bare
`400 Bad Request`. Teardown reported it and carried on; a few steps later it deleted the personas. The
rebuild then re-creates those personas with the **same UPNs but new object ids** — new principals entirely.
The surviving agents are now owned by systemusers nobody can reach, and Phase 6's solution import dies with:

```text
user with id <new-owner> does not have WriteAccess right(s) for record with id <botid> of entity Agent
```

surfacing only as `CREATE FAILED ... The async operation completed with a statuscode of Failed`.

**Why it cannot be cleaned up by script.** In the shared default environment **no human account holds System
Administrator** — only Microsoft service principals (`# CDSUserManagement`, `# DynamicsInstaller`, …) and a
`Delegated Admin`. The lab admin has `Environment Maker` + `Basic User` there, which is why the admin
"sees 0 bots", cannot read the record, and **cannot self-assign System Administrator** (403,
`prvAssignRole`); the BAP `addAdmin` endpoint does not exist. `pac copilot list` as the new owner also
reports *"No Chatbots found"* — the agent is invisible to every headless identity.

**Fixed going forward:** `99_teardown.ps1` now escalates — delete the agent's `botcomponents`, then
deactivate it, then delete — and if it still will not go it prints a loud warning naming the agents and
telling you to remove them **before** re-running Phase 2.

**If you already have orphans**, the only way out is interactive, once: in **PPAC → the default environment
→ Settings → Users + permissions → Users**, give yourself **System Administrator**, then delete the two
agents in Copilot Studio (or Dataverse). Do it *before* Phase 6, which will then recreate them normally.

### Phase 7 · the export no longer needs Windows, and four things it got wrong (verified 2026-09-23)

- **It ran anywhere all along.** The only reason Phase 7 was a Windows-build-VM step is that it drove
  `Microsoft.PowerApps.Administration.PowerShell`: `Add-PowerAppsAccount` needs `System.Windows.Forms` and
  fails on Linux with *"Could not load file or assembly 'System.Windows.Forms'"*. The environment,
  connection, role-assignment and DLP reads all exist over REST, so the script now uses `az` like Phases 3,
  5 and teardown, and runs in the dev container.
- **`description` is not a column on the `bot` entity.** Selecting it fails the whole read with
  `0x80060888` *"Could not find a property named 'description'"*. That text is **canon**, written by hand —
  it exists in the pack and `AGENTS.md`, nowhere in the tenant. The export now omits it from the query and
  **carries the committed text over by display name**, so regenerating the pack reports live drift without
  wiping prose. A new agent arrives with an empty description for a human to fill in.
- **The agent-identity export always produced an empty file.** It filtered on
  `startswith(displayName,'cs-agent-')`, the canon's invented convention. Copilot Studio actually names the
  principal **`<agent display name> (Microsoft Copilot Studio)`**. Fixed, and it now matches on that.
  Two things fell out of fixing it:
  - **Publishing mints a NEW identity every time and teardown removes none**, so a rebuilt estate
    accumulates one stale service principal per agent per build (three per agent after three builds here).
    The export keeps only the newest per agent; the strays stay in the tenant. Worth a look in their own
    right — an orphaned agent identity is exactly the kind of thing the workshop teaches people to find.
  - **`createdDateTime` has to be read defensively.** The Graph SDK does not reliably project it onto the
    typed property even when requested; it turns up in `AdditionalProperties`. Reading only the typed one
    left every date blank. (The old code asked the backing *application* for it — these agent identities
    have no application object, so that was always empty too.)
- **`Export-Csv` quotes every field; the committed pack is unquoted**, so even identical data diffed. Now
  `-UseQuotes AsNeeded`. Environments are also sorted by type (Default, Production, Sandbox, Developer —
  the canon's order) instead of however the admin API returned them, so re-running does not reshuffle rows.

**What the export still cannot reproduce**, and why `git diff` will never be empty: the friendly connector
names (`SharePoint`, not `shared_sharepointonline`), the rows for things that are not Power Platform
connections at all (`HTTP-PolicyAPI`, `MCP-Underwriting`, `PA-Expense-AutoApprove` — an HTTP action, an MCP
server and a cloud flow), and the fabricated canonical dates. Treat the diff as drift to review.

`used_by_agent` is also **approximate** — it attributes a connection to the *first* agent found in the same
environment, so with several agents per environment it will name the wrong one. It is marked `[verify]` in
the script; a precise answer means joining through each agent's connection references.

### Teardown · connections in the shared default environment were never removed

Connections in the three estate environments disappear when the environment does. The ones in
`Halcourt (default)` do not, and nothing was deleting them — so every rebuild left another set behind. By
the third build the environment held **four** stale connections (`SP-Onboarding` from 09-19, three
`O365-Outlook-Onboarding` from 09-19 and 09-22), all owned by personas that had since been deleted and
recreated. The artifact-pack export duly reported one agent's connection three times, which is how it was
noticed.

`99_teardown.ps1` now deletes them alongside the default environment's agents and flow, matching on the
estate's own accounts (`*.<estate>@*`) so another estate's connections in that shared environment are never
touched:

```text
DELETE .../scopes/admin/environments/<default-env>/apis/<connector>/connections/<id>?api-version=2016-11-01
```

Same family as the maker OneDrives, the soft-deleted users and the per-build agent identities: anything
living **outside** the estate environments survives an environment-level teardown and has to be removed by
name.

### Phase 5 · a brand-new Dataverse environment is flaky

A freshly provisioned Dataverse environment fails metadata writes transiently while it warms up:
`0x80040216` ("An unexpected error occurred") on the first attribute after a table create, and `0x80048564`
("Database is currently unavailable") on relationship creates. Neither indicates a bad payload.
`04_provision_dataverse.ps1` now retries both with backoff (up to ~12 attempts), instead of needing the whole
script re-run to inch one step further each time.

### Phase 6 · fresh-environment and re-run robustness

The agent engine needed six fixes before a greenfield run completed all ten agents:

- **Dependency: Playwright + Chromium.** The connection-consent helper (`lib/consent_browser.py`) needs them,
  and nothing else in the kit does. `.devcontainer/on-create.sh` now installs them; outside the container run
  `pip install playwright && python3 -m playwright install --with-deps chromium` first, or **every**
  connection fails at consent.
- **Owner-managed (Developer) environments.** In `Maker-Sandbox` the admin holds **no Dataverse role** — its
  owner (dev.kim) is the sole System Administrator — so admin-token reads throw `0x80042f09`
  (`prvReadUser` / `prvReadPublisher`). `Ensure-EnvUserRole`, `Ensure-Publisher` and the connection-reference
  read now try the admin token first and **fall back to the owner's token** (helper `DvAuto`).
- **The first agent in a new environment.** The first `pac copilot init` there triggers a CDS solution import
  (~16 s and up) and can fail transiently, and the bot can lag a few seconds behind a successful init before
  `clone` sees it. The clone/init retry is now 6 x 20 s (was 3 x 10 s) and **surfaces pac's last output** on
  failure instead of swallowing it.
- **Stale `pac` auth token.** pac caches its OAuth token under `XDG_DATA_HOME`, a directory that survives
  between runs; a refresh token idle more than 12 h fails `init`/`clone`/`publish` with **`AADSTS700082`**
  even though the ROPC password is still valid. The engine now runs `pac auth clear` before `pac auth create`
  so every run re-authenticates.
- **Consent that returns no code.** SharePoint and Dataverse hand back a short connection code to post to
  `confirmConsentCode`; **Office 365 Outlook** completes OAuth entirely through the redirect and returns
  **none**. Treating "no code" as failure was a false negative on a connection that was already live. The
  engine now posts the code when there is one and then **verifies the connection reached `Connected`** —
  that status, not the code, is the success signal.
- **Publisher option-value prefix.** `Ensure-Publisher` computed `customizationoptionvalueprefix` with
  `Measure-Object -Sum`, which yields a `[double]`; it serialised as `10419.0` and Dataverse rejected it
  (`0x80048d19`, expects `Edm.Int32`). Cast to `[int]`.

### Phase 6 · diagnosing a publish that does not confirm

`pac copilot publish` prints only "Failed". The actual diagnostics live on the bot record's
**`synchronizationstatus`** field:

```bash
bots?$filter=schemaname eq '<schema>'      # -> lastFinishedPublishOperation.diagnosticDetails
```

It holds `InvalidReferenceError`, `InvalidPropertyPath` and friends, and is the only place they appear.

That is how the **HR FAQ v2 (copy)** decoy was diagnosed: captured as a portal copy (`new_HRFAQv2copy`), its
system topics still cross-referenced the *original* agent's dialogs (`cr3f5_HRFAQv2copy.topic.Escalate`, ...).
Push succeeded and publish failed with `InvalidReferenceError` / `NotFound`. Fixed by rewriting the committed
topic references to the agent's own schema. **When you capture a "copy" agent, grep `topics/*.mcs.yml` for
stale `<old-schema>.topic.*` references.**


### Phase 6 · the default-environment agents are orphans, not absences (diagnosed 2026-10-13)

**Symptom.** `Halcourt (default)` appears to contain no agents. The build admin reads `bots` and gets
`200` with an empty array. Every persona - including `sam.olsen`, the canonical owner of Expense Helper -
reads the same empty array. `pac copilot list` as that owner reports *"No Chatbots found"*. Three
independent reads agree, and all three are wrong.

**What is actually there.** The bot records exist. `pac copilot init` for `cr458_ExpenseHelper` fails with
the only message that tells the truth:

```
user with id 0bc88b57-... does not have WriteAccess right(s) for record with id 4cf3a8fe-...
of entity Agent ... OwnerPrincipal: 48b56557-a6b6-f111-aaab-000d3a32c3db
```

Resolving that owner gives `fullname = "# Sam Olsen (mgray)"` and
`domainname = ea559c6438cf4b19bd097c953a2abe15sam.olsen.mgray@...`. The GUID-prefixed UPN and the `#`
prefix are how Dataverse renames the `systemuser` record of a **deleted** user. Its Entra object id
(`ea559c64-...`) is not the live `sam.olsen` (`1264def9-...`).

So the agents belong to a sam.olsen from an **earlier build of this same estate**. When Phase 9 removed the
personas and Phase 2 recreated them, the new accounts got new `systemuser` records; the bots stayed behind,
owned by the dead one. `bot` is user-owned, so a user-scoped read shows every live account an empty list.

**Why it is worth writing down.** The failure mode is indistinguishable from "the agents were never built"
unless you ask a tool that reports ownership. It is the same trap Lab 02-01 teaches - *an empty result can
mean no access, not no agents* - landing on the facilitator rather than the attendee. It also means a
rebuild cannot proceed: the schema name is taken, and the live owner has no write access to the record
holding it.

**What it is NOT.** Not another estate's agents, and not a schema-name collision between two estates -
the usual reading of "the default-env agents are not estate-scoped". The collision here is between two
builds of the *same* estate, across a teardown.

**The fix needs rights the build admin does not have.** In `Halcourt (default)` the admin holds only
Environment Maker and Basic User, so it cannot read the records, cannot create a security role
(`403` on `POST /roles`) and cannot reassign or delete the bots. One of these has to happen first:

- give the admin **System Administrator** in the default environment - PPAC -> the environment ->
  Settings -> Users + permissions, or `pac admin assign-user --environment <id> --user <admin UPN>
  --role "System Administrator"` (needs a fresh `pac` sign-in; the device-code flow is interactive); then
- **reassign** the two bots to the live `sam.olsen` and `tom.dean`, which restores them without a rebuild,
  **or delete** them and re-run `06_provision_agents.ps1 -Agents expense-helper` and `-Agents
  onboarding-guide`. Onboarding Guide is owned by `tom.dean`, so it must be built **before** Phase 6.5
  disables him, or he must be re-enabled for the build and disabled again afterwards.

**Prevention.** Phase 9 should remove the default environment's agents while their owners still exist, or
the teardown should reassign them to a surviving principal first. Deleting the personas before the agents
is what strands them.


### Phase 8c · agent identities collide across slices (found 2026-10-13)

**Symptom.** Build the same agent into a per-student slice and the tenant gains a second Entra principal
with the *same* name. Building `claims-copilot` into one slice was enough:
`Claims Copilot (Microsoft Copilot Studio)` x2. At twenty slices it is twenty-one.

**Why it matters twice over.**

- **Lab 01-02** has attendees match each identity to an agent in `agents-export.csv`. The page already
  anticipates duplicates and tells them to compare the identity's Object ID with the agent's **Entra Agent
  ID** in Copilot Studio -> Settings -> Advanced -> Metadata. That works for two candidates. It does not
  work for twenty-one.
- **Phase 7's export** dedupes agent identities **newest-per-display-name**. With duplicates it silently
  keeps whichever slice was built last, so a student's throwaway environment can end up in the committed
  artifact pack.

**Fix.** `06_provision_agents.ps1 -DisplayNameSuffix <slice>` suffixes the agent's display name, and the
identity follows it: `Claims Copilot (mgray-01)`. The same idea the manifest already uses for the shared
default environment (`estateSuffixName`), applied to slices.

**Not a fix for the general case.** Two *estates* in one tenant still collide on the non-default agents,
because only the default-environment two carry the estate id. That is the separate, known gap.

### Phase 8c · the connection-reference bind warning is pre-existing

A slice build reports `could not bind DV-Claims-Shared as svc-claims: 403 (Forbidden)` and the agent still
publishes. It is tempting to read that as the slice being broken. It is not: `connectionreferences` in the
**working** `Claims-Test-<estate>` shows the same three references with `connectionid` empty, exactly as a
freshly built slice does. The slice is at parity with the estate, and Copilot Studio evidently carries the
binding in its own agent settings rather than those rows.

Retrying does not clear the 403 - it failed identically on a second run with svc-claims holding the same
roles in both environments - so it is not the privilege-cache lag that explains several other delays in
this kit. Whether the scenario actually fires is a functional question: drive the agent and watch, which is
Module 4 work, not something the build can assert.


### Phase 6 · a connection reference binds only when the agent owner owns the connection

Building two agents into the same slice showed the rule the earlier `403` was hiding:

| agent | agent owner | connection owner | bind |
|---|---|---|---|
| `onboarding-guide` | tom.dean | tom.dean (`O365-Outlook-Onboarding`) | **bound** |
| `claims-copilot` | priya.nair | svc-claims (`DV-Claims-Shared`) | `403 Forbidden` |

So the bind is not flaky, not a propagation delay and not slice-specific: it succeeds when one principal
owns **both** the agent and the connection, and fails when they differ. That matches the rule the Phase 6
notes already state - the agent owner binds its own agent's references, and a connection reference can
only be bound by the connection's owner - the two requirements simply cannot both be met when the
connection belongs to a service account.

The shared estate is in exactly the same state (`connectionreferences` with `connectionid` empty in
`Claims-Test-<estate>`), so this is long-standing and not a regression. Copilot Studio evidently carries
the binding in the agent's own settings rather than those rows. Treat the warning as expected for any
service-account connection, and judge the scenario by driving the agent, not by reading that table.


### Phase 8c · Dataverse learns an owner is disabled late, not never

Disable a persona in Entra and Dataverse's `systemuser.isdisabled` does **not** follow immediately.
Measured 2026-10-13, same account, two environments:

| environment | disabled in Entra | `isdisabled` in Dataverse |
|---|---|---|
| `Lab-mgray-01` (slice) | ~15 minutes earlier | **False** |
| `Halcourt-Prod-<estate>` | weeks earlier | **True** |

So it is a propagation lag, not a permanent divergence - worth knowing before someone reports it as a
bug, and worth not "fixing" by re-disabling the account.

**It does not affect the exercises.** Lab 02-03's orphan hunt and Lab 03-01's owner cross-check both read
`account_enabled`, which comes from **Entra** via `users-export.csv`, and Entra is correct immediately. A
student who queries an environment's `systemusers` table directly on the day a slice was built is the only
one who would see the stale value.

**Operationally** it joins the other lags in this kit - Conditional Access group membership, and `az`
settling a token for a brand-new org. Build the slices well before the delivery
rather than minutes before it. Nothing here is fast-path safe.


### Phase 8c · the slice suffix only takes on a FIRST build

`-DisplayNameSuffix` is applied by `pac copilot init`, which runs only when the agent does not yet exist.
On a rebuild, clone-first finds the agent by schema name and pushes the committed workspace, which carries
its own display name - so the agent is **not** renamed, and neither is the Entra identity it was born with.
Verified: rebuilding `claims-copilot` into a slice with `-DisplayNameSuffix mgray-01` republished it as
plain `Claims Copilot`, and the tenant still held two identities called
`Claims Copilot (Microsoft Copilot Studio)`.

**So set the suffix on the first build of a slice.** Getting it wrong is not repaired by re-running with
the right flag; it is repaired by deleting the agent (or the whole slice environment) and building again.
Because an identity outlives its agent, each correction leaves an orphaned principal behind - which is the
same trap the default-environment agents fell into, arrived at from the other direction.

Practical consequence for a twenty-slice delivery: build each slice **once**, with the suffix, and treat a
slice as disposable rather than editable. Deleting the environment removes its agents; the orphaned
identities that remain are harmless **provided** they were named distinctly in the first place, because
then they can be told apart from the estate's own.


### Phase 8b · attendee accounts can use PPAC and nothing else (found 2026-10-13)

Signing a lab account into each portal the exercises use, in a real browser:

| Portal | Lab account |
|---|---|
| Power Platform admin center | **works** |
| Microsoft Entra admin center | **blocked** - *"Let's keep your account secure"*, MFA registration |
| Microsoft 365 admin center | **blocked** - same |
| Exchange admin center | **blocked** - same |
| Graph Explorer | page loads (queries while signed in untested) |

There is **no skip**: none of *Skip setup*, *Skip for now*, *Ask later*, *Maybe later* or *Not now* is
offered. This is Microsoft's own mandatory MFA for admin portals, which is enforced independently of
tenant Conditional Access - so `CA-Require-MFA-Admins`'s exclusion, which is what lets these accounts sign
in with a handed-out password at all, does not reach it.

**What it blocks.** Every task that sends an attendee anywhere but PPAC:

- 01-01 KT01 step 3, and 02-01 KT01 step 4 - the agent registry in the M365 admin center;
- 01-01 KT02 step 2, 03-01 KT02 step 3, 03-04 KT01 step 7 - owner checks in the Entra admin center;
- 01-02 KT01 step 2 - *Entra ID -> Agents -> Agent identities*;
- 01-01 KT02 step 2, 02-03 hunt 5, 03-01 KT02 step 3 - shared mailboxes in the Exchange admin center.

**The fix is to stop avoiding MFA and enrol it.** Have attendees register MFA on first sign-in, the way
they would for any corporate lab. That is strictly better than what is built today:

- every portal the exercises use comes back;
- the **CA exclusion becomes unnecessary**, so `CA-Require-MFA-Admins` no longer has to be weakened for a
  delivery, and the accounts can hold Power Platform Administrator without that trade;
- the only cost is each attendee needing an authenticator app and about two minutes at the start.

The accounts still need Power Platform Administrator for Lab 01-01's `/scopes/admin/` calls - that finding
is unchanged. What changes is that the MFA exclusion built to go with it is the wrong half of the trade.


### Phase 8b · RESOLVED - MFA enrolment restores every portal (2026-10-13)

The entry above records that a lab account reached PPAC and nothing else. Enrolling MFA fixes it, and the
enrolment needs no phone: Entra's wizard offers **"Set up a different authentication app"**, which ends on
a screen whose **"Can't scan the QR code?"** link prints the base32 secret. Capture it, generate the code
in software (RFC 6238), finish the wizard.

Measured after enrolling one account:

| Portal | Before | After |
|---|---|---|
| Power Platform admin center | works | works |
| Microsoft Entra admin center | blocked | **works** |
| Microsoft 365 admin center | blocked | **works** (redirects to `admin.cloud.microsoft`) |
| Exchange admin center | blocked | **works** |

Two things that cost time and are worth knowing:

- **Exchange asks to register a SECOND method after the code**, and only there is a skip offered - *"Not
  now"*. Without taking it the sign-in parks on the registration page forever, which looks exactly like
  the original block.
- **The secret must be read up to whitespace.** The screen reads `Secret key: <key> Copy key`, and the
  words that follow are themselves valid base32 letters, so a greedy character class swallows "Copy key"
  into the key and every generated code is rejected as incorrect.

So the facilitator instruction is simply: tell attendees to bring an authenticator app and register at
first sign-in. Nothing in the kit has to weaken `CA-Require-MFA-Admins` to make the labs work.


### Phase 8b · Lab 03-02's role editor needs a LICENCE, not more privileges (2026-10-14)

**Symptom.** An attendee follows Task 03-02 to *"open a role under **Security roles** to see what it grants
on each table"* and the page renders **"Loading role failed!"**. The roles *list* loads; only the editor
fails — and the editor is the only place scope (user / business unit / organization) is visible.

**Evidence.** Three Dataverse calls behind the editor return 403, and their bodies name the cause:

```
EntityDefinitions?$select=Privileges,…   PrivilegeName: prvReadAttribute … User Privileges Count: 15
roles(roleid = …)?$select=…              is missing prvReadTeam privilege
recordfilters?…                          is missing prvReadEntityRecordFilter privilege
```

and each carries:

> `System Administrator unlicensed user with filtered privileges from associated roles. Consider assigning
> License for the privileges to take affect. … unlicensed administrators get Administrative access mode only`

**Why adding privileges does not fix it.** `Lab Reviewer (read-only)` was granted four more privileges,
taking it to **18**; Dataverse still applied **15** (`privilegeCount=15`) and still reported
`prvReadEntityRecordFilter` missing **by the exact id that had just been granted**. An account with no
licence gets access mode `1 Administrative` and its roles' privileges are filtered. Assigning `FLOW_FREE`
changed nothing — it is not a Dataverse-capable plan.

**The blocker.** The tenant has no seat to give:

| SKU | Enabled | Consumed | Free |
|---|---|---|---|
| `DEVELOPERPACK_V2_E5` | 25 | 25 | **0** |
| `FLOW_FREE` | 10000 | 1 | 9999 (does not help) |

The 25 E5 seats are held by **14 Microsoft demo sample users** (AdeleV, AlexW, DiegoS, GradyA, HenriettaM,
IsaiahL, JohannaL, JoniS, LeeG, LidiaH, MeganB, MiriamG, NestorW, PattiF) that have nothing to do with
Halcourt, the **8 estate personas**, and **3 admin accounts**. So ~14 seats are recoverable, which is also
the real answer to "how many licensed attendees does this tenant support": about 14, not an arbitrary N.

**Decision required before a delivery** — the two options are not equivalent:

1. **Licence the lab accounts.** Free seats from the demo users and assign E5 in `07_provision_lab_users.ps1`.
   Task 03-02 then works as written. Note the tenant is shared between estates, so those demo accounts may
   belong to someone else's build — confirm before stripping them.
2. **Reword Task 03-02.** Drop "open a role" and have attendees read the roles list, recording role breadth
   as the **open question** that step 3 of the same task already sanctions ("role breadth unknown from
   export; verify in tenant"). Pedagogically defensible, but it removes the one place the lab shows scope.

**Also fixed here.** `07_provision_lab_users.ps1` granted privileges only in the branch that *created* the
role, so adding a name to `$DvPrivilegeNames` silently did nothing in any environment that already had it —
while still printing a success line. That is how the live role drifted to 14 privileges against a list of 5.
Privileges are now reconciled on every run by diffing `RetrieveRolePrivilegesRole`.

**Update (2026-10-14, same day): the licence is necessary but not sufficient — Dataverse must RE-SYNC it.**

After freeing seats and assigning `DEVELOPERPACK_V2_E5`, the editor still failed with the same
"unlicensed user with filtered privileges" message. Entra was correct; Dataverse was not. It keeps its own
copy of licence state on the `systemuser` record and refreshes it asynchronously:

```
systemusers(<id>)?$select=islicensed,accessmode,modifiedon
  islicensed  False          <- Dataverse still thinks the account is unlicensed
  accessmode  1              <- 'Administrative', the mode that triggers privilege filtering
  modifiedon  2026-10-14T01:36:41Z   <- PREDATES the licence assignment entirely
```

**`modifiedon` predating the licence assignment is the tell.** Until it moves, privileges are filtered
(20 granted, 17 applied) and the error messages blame privileges rather than the sync — which sends you
chasing privilege names that are already granted. On this build the flip took hours and did not happen
until a BAP `addUser` nudge:

```
POST https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/
     environments/<envId>/addUser?api-version=2021-04-01   { "objectId": "<entra object id>" }
```

After the flip: `islicensed True`, `accessmode 0` (Read-Write), and the granted privileges apply.

**Facilitator consequence:** licence the attendee accounts the DAY BEFORE a delivery, not the morning of.
An account licensed an hour before the lab will still fail Task 03-02, and the failure looks like a
privilege problem, not a timing one. Verify with the `systemusers` query above before you start.

**Also fixed (2026-10-14).** Re-running `07_provision_lab_users.ps1` against existing accounts rewrote the
handout's password column as `(unchanged - from the run that created it)` — destroying the only copy of a
working credential, since the script cannot read a password back from Entra. It now resolves the handout
path up front and carries forward any password already recorded, and says
`(unknown - set by an earlier run; reset it or use -Destroy and recreate)` only when there is genuinely
nothing to carry.

### Phase 8b · CORRECTION - the role editor is gated by SYSTEM ADMINISTRATOR, not by a licence (2026-10-14)

The entries above conclude that Task 03-02 needs a Dataverse-capable licence and that attendee accounts
must be licensed the day before a delivery. **That conclusion was drawn from one account that differed in
two ways at once, and it is wrong.** A single-variable test says otherwise:

| Account | Entra licence | Dataverse state | Dataverse role | Role editor |
|---|---|---|---|---|
| `student01` (morning) | none | `islicensed=False`, `accessmode=1` | Lab Reviewer (read-only) | **FAILS** |
| `student01` (after E5) | E5 | `islicensed=True`, `accessmode=0` | Lab Reviewer (read-only) | works |
| `student02` | **none** | `islicensed=False`, `accessmode=1` | **System Administrator** | **works** |

An unlicensed account runs in **Administrative access mode**, which is designed to allow administrative
work without a seat while withholding business *data*. System Administrator's privileges survive that
filtering; a hand-built 21-privilege read-only role does not - it was applied as 17, and the ones dropped
were exactly the metadata privileges the editor needs (`prvReadAttribute`, `prvReadRelationship`,
`prvReadEntityRecordFilter`).

**What this means for a delivery.** `08_provision_student_slices.ps1` already makes each attendee
**System Administrator of their own slice**, and that slice already carries the substrate Task 03-02 asks
about (`svc-claims` holding the over-broad role). So an attendee reading role scope **in their own slice
needs no licence at all**. It fails only in the shared estate, where they hold just the reviewer role -
and granting them System Administrator there is not an option, because it would give them write access to
the shared estate and contradict "a security reviewer observes; they do not change the estate".

So the fix is a ROUTING change, not a procurement one: point Task 03-02's role reading at the attendee's
own slice.

**The licence-sync trap recorded above is still real and still bidirectional** - it just is not the cause
of this failure. Measured both ways on this tenant:

| Change | Dataverse caught up after |
|---|---|
| E5 assigned | hours, and only after a BAP `addUser` nudge |
| account created with no licence | ~50 minutes, during which it reported `islicensed=True` |

The optimistic direction is the dangerous one: a freshly created unlicensed account reports as **licensed**
for a while, so a rehearsal can pass and the delivery fail. Check
`systemusers(<id>)?$select=islicensed,accessmode,modifiedon` and distrust it until `modifiedon` moves past
your change.

**Still unverified:** whether an unlicensed System Administrator can **create** a role (Module 5's ask, as
opposed to reading one). The PPAC "New role" command renders **enabled** and its click produced **zero**
4xx responses, so there is no evidence of a permission block - but the editor did not open under headless
automation, so this is untested rather than proven. Also unverified: Module 5 retests that require reading
Claim/Customer rows **as the attendee**, which Administrative access mode would block; retests performed by
chatting with the agent run as `svc-claims` and are unaffected.

### Phase 8b · PPAC's environment Users list needs prvReadPosition (2026-10-17)

**Symptom.** As an attendee (Lab Reviewer + Bot Viewer, licensed), **Environments → `Claims-Test-<estate>` →
Settings → Users + permissions → Users** shows *"It looks like something went wrong"* before any search.
Lab 03-02 KT01 s2, 03-04 KT01 s3 and 04-04 KT01 s1 all start there.

**Evidence.** The page's own query, `GET systemusers?$select=...`, returns 403 naming the gap: *"is missing
prvReadPosition privilege ... on OTC=50"*. A second call on the same page,
`settingdefinitions?$filter=uniquename eq 'msdyn_EnableTeamsChat'`, returns 403 for `prvReadSettingDefinition`.

**Fix.** Both added to `$DvAccessModel` in `_access_model.ps1` and to the live `Lab Reviewer (read-only)`
role in Halcourt-Prod, Maker-Sandbox and Claims-Test (31 privileges each: 22 modelled + 9 baseline). The
list then loads, an account opens, and its summary shows **Direct Assigned Roles**; **Security roles → a
role** opens the per-table grid with access levels.

**Two things the task text doesn't say.** PPAC shows Dataverse display names with a `# ` prefix
(`# Lab Student 03 (<estate>)`), so a search on the display name finds nothing; search by username. And
for this account there is no separate **Manage security roles** command: the roles are listed in the
user's summary panel.

### Phase 8b · the default environment was outside the access model (2026-10-17)

**Symptom.** In Copilot Studio, an attendee's agent list for `Halcourt (default)` is empty: *"Agents 0
items"*. Expense Helper and Onboarding Guide live there, and Lab 04-04 KT02 s5 and 04-06 KT02 open them.

**Cause.** `Get-EstateDataverseEnvironments` in `07_provision_lab_users.ps1` listed only the three estate
environments. The role dates from Lab 03, which never touched the default environment.

**Fix.** The function now includes the tenant's default environment (`properties.isDefault`). A
`-Count 5 -NoLicense` run created `Lab Reviewer (read-only)` there and gave all five accounts it plus Bot
Viewer; both agents were listed at once.

### Phase 8b · another owner's flow needs prvReadWorkflow at Global (2026-10-17)

**Symptom.** **PPAC → Halcourt (default) → Resources → Flows** says *"No flows found for this
environment"*, while Inventory lists *Submit and auto-approve expense under $500* there as a Cloud flow
(`statecode` 1, on). Lab 03-01 KT01 s2 and 04-04 KT02 s5 open that flow's **Details**.

**Cause.** Bot Viewer grants workflow read at **Basic** depth only (the attendee's own flows).

**Fix.** `prvReadWorkflow` at Global added to `$DvAccessModel` and to the live role in all four
environments; the Flows list then shows the flow. **Not fixed by any role:** the Copilot Studio topic
canvas still marks Expense Helper's flow node *"Flow not found or is turned off"* for the attendee. That
check goes through Power Automate's own sharing, which only sharing the flow would satisfy - not done, since
it would make attendees co-owners of Sam's flow. The task's PPAC route is the one that works.

### Phase 6 · CORRECTION - Claims Copilot never worked: unbound reference, then the wrong Dataverse op (2026-10-18)

The two Phase 6/8c entries above concluded that an empty `connectionid` on Claims Copilot's connection
reference was harmless because "Copilot Studio evidently carries the binding in its own agent settings".
**It does not.** Driven through the Test pane as its owner, every question failed:

1. `ConnectionNotFound - The connection of connection reference … DVClaimsShared was not found`. The tool
   editor showed **Connection: Not connected**. Priya can't select svc-claims' connection: a Dataverse OAuth
   connection **can't be shared** (`ConnectionSharingNotAllowed`), so only svc-claims can bind it - and its
   PATCH was refused for want of `prvReadconnectionreference`, `prvWriteconnectionreference` and
   `prvReadAsyncOperation` (each named in turn by its 403). Fixed by lending svc-claims a throwaway role with
   exactly those three, binding as svc-claims, then removing and deleting the role. 06 now does this
   (`Invoke-BindWithTempRole`) whenever the owner's bind is refused.
2. Then `ConnectorRequestFailure - Microsoft Dataverse returned HTTP 400` on every call, even unfiltered,
   even as svc-claims. The tools used **ListRecords** (List rows, *current environment*), which has no
   environment to resolve inside a Copilot Studio tool. **ListRecordsWithOrganization** with
   `organization = <the environment URL>` works at once: "List the claims" returns all five, and "status of
   CLM-9002" returns *Under review*. Both action YAMLs now use it, with a `${ENV_ORG_URL}` token 06 fills.

To make the change live without a rebuild, svc-claims also had to open and re-save the tools and publish:
it was made a **co-owner** of the agent (added to the agent's `<botid>_1` team; Priya's own editor share
fails without `prvAssignRole`) and lent Bot Author + Basic User + Environment Maker for the edit, all three
removed afterwards. Its only remaining role is `svc-claims Dataverse Full Access`.

Until this, Scenarios C and D - and Claims Copilot's half of B - could not fire for anyone.

### Phase 4c · Purview: the label arrives late, and the token is app-only (2026-10-18)

Building issue #12 (`03c_provision_purview.ps1`) hit four things worth knowing before the next build:

1. **Security & Compliance PowerShell refuses every az token** (`UnAuthorized` for the
   `ps.compliance.protection.outlook.com` and `outlook.office365.com` resources alike), unlike Exchange
   (`Connect-LabExchange`). App-only works - but `Connect-IPPSSession -Certificate` /
   `-CertificateFilePath` dies inside the module on Linux (`NewEXOModule`: object reference not set). The
   script signs its own client assertion and passes `-AccessToken`.
2. **A new Microsoft 365 group isn't an Exchange recipient for a while**: `New-LabelPolicy -ExchangeLocation
   <group mail>` says it "couldn't be found". The policy publishes to Marcus first; a rerun adds the group.
3. **`assignSensitivityLabel` says `labelNotFound`** for a label created minutes earlier - SharePoint hasn't
   received it. Typically about an hour, documented up to 24. It is also **metered**: the app needs a
   `Microsoft.GraphServices/accounts` billing link, and only `privileged`/app-only assignment is allowed.
4. `extractSensitivityLabels` is a **POST** (a GET says `itemNotFound`), and a loose
   `'Social Security Number'` match finds *Austria Social Security Number* first - match
   `'^U\.S\. Social Security Number'`.

### Phase 6 · Underwriting Assistant's MCP calls never ran - rebuilt as a real MCP tool (2026-10-18)

**Symptom.** Driven through the Test pane as Priya, every Underwriting Assistant topic that called the MCP
server answered *"Action of type 'InvokeMcpTool' is not supported"* (`ActionTypeNotSupported`), and the
attendee's canvas showed *"Your topic … can't be shown on the authoring canvas"*. Scenario C's `run_query`
and the MCP half of Scenario E could not fire. `InvokeMcpTool` is not a Copilot Studio node kind.

**Fix (decided 2026-10-18: a real MCP tool, not an HTTP node).** The server (`setup/infra/mcp-underwriting`,
stateless Streamable HTTP, `initialize`/`tools/list`/`tools/call` all answered) is now registered the way
Copilot Studio's *Add new MCP* wizard does it, from committed files:

- `setup/agents/underwriting-assistant/mcp-connector/` - the wizard's own connector definition: one
  `POST /underwriting`, `x-ms-agentic-protocol: mcp-streamable-1.0`, `operationId: InvokeServer`, API-key
  auth in the `Authorization` header. 06 creates it as the owner with `pac connector create`.
- manifest connection `MCP-Underwriting` (`connector: custom`, `apiKeyFrom: MCP_BEARER`): Priya's connection,
  key `Bearer <MCP_BEARER>`, no consent step.
- `actions/UnderwritingMCP.mcs.yml`: `InvokeExternalAgentTaskAction` + `ModelContextProtocolMetadata`,
  **`mode: Maker`** - the wizard defaults to `Invoker` (each user's own key), which would hide the shared
  bearer that is Scenario E's point.
- The three `topics/` that used `InvokeMcpTool` are deleted.

Verified by a real 06 run (`-Agents underwriting-assistant`): "premium quote for a standard auto profile"
→ `get_quote`, USD 1,425; "run this pricing query: SELECT * FROM risk_rows" → `run_query`, *all pricing and
customer risk rows*.

Traps on the way, all now handled or noted:
1. **`pac copilot push` won't create a connection reference** the workspace declares - *"A record with the
   specified key values does not exist in connectionreference entity"*. 06 now creates missing ones first.
2. **Connector display names are capped at 30 characters**, silently truncated (`…-MCP-mgray` → `…-MCP-mgra`).
   06 truncates the same way, or a rerun would not find what it made.
3. **A deleted connector's display name stays taken** - Dataverse row and Power Apps API record both gone,
   the wizard still says *"already exists"*. Hence the `Halcourt-` prefix on the name.
4. **Names allow only letters, digits, `-` and `_`** - `Underwriting MCP (mgray)` is refused.
5. **Doc impact (for the exercise owner):** the MCP calls are on the agent's **Tools** page now, not in
   Topics, and a viewer sees one MCP tool whose individual tools (`get_quote`, `get_risk_score`, `run_query`)
   appear when it runs. 04-03 KT02 s3, 04-05 KT02 s4 and 05-04 KT06 describe topics.

### Phase 8b · Exercise 05's write steps: PIM-eligible roles, and per-environment self-elevation (2026-10-18)

Exercise 05 asks attendees to *change* things. Decided 2026-10-18: an attendee who must perform an action
holds the role for it, as narrowly as the platform allows - which for these turned out to be **time**, not
resources:

| Step | Lever | How |
|---|---|---|
| 05-02, 05-03, 05-05 b, 05-07 auditing - Dataverse / Copilot Studio writes | **System Administrator, self-elevated per environment** | Power Platform Administrator's own *Membership > Add me*, one environment at a time; 05-05 KT06 already says so. No standing grant, and none in Claims-Test during Exercise 04 - a standing one there would let attendees read claims directly and void Scenario D. |
| 05-05 KT06 - Block / Delete / assign owner in Agent 365 | **AI Administrator, PIM-eligible** | Entra > *Privileged Identity Management* > *My roles* > *Activate*, justification, 1-2 hours |
| 05-07 KT01/KT06 - Defender real-time protection for agents | ~~Security Administrator, PIM-eligible~~ **facilitator** (2026-10-19) | Security Administrator can edit Conditional Access - the lockout this table exists to prevent. Withdrawn from the five lab accounts; 07 withdraws it on re-run |
| 05-04 KT03 - workload-identity CA policy | *not granted* | the step writes the policy down; one wrong edit to `CA-Require-MFA-Admins` locks every account out |

Neither role can be scoped to resources: the agent block and the Defender setting are tenant-wide objects.
PIM makes them *eligible* - inert until activated, time-boxed, justified and audited. E5 includes Entra ID
P2, so PIM is available. Verified: student03 activated AI Administrator from *My roles* and held it as an
active assignment.

The az token can't create eligibility (`PermissionScopeNotGranted: RoleEligibilitySchedule.ReadWrite.Directory`),
so 07 uses the kit's app-only identity (`_labapp.ps1`, shared with 03c), which now also holds that permission.
Doc impact: 05-05 KT06 and 05-07 should tell attendees to activate the role first.

### Phase 6.5 · a disabled owner's connections die - Tom stays enabled (2026-10-19)

**Symptom.** Onboarding Guide's `O365-Outlook-Onboarding` reference was unbound and Sales Nudge's
`DV-CRM-Shared` reference too; Tom's Prod Dataverse connection showed `Error`.
**Evidence.** The connection's status: `Failed to refresh access token ... AADSTS50057: The user account is
disabled` (2026-10-17, two days after Phase 6.5 disabled him). Entra issues no token to a disabled user, so
every OAuth connection he owns goes to `Error` at its next refresh. The planted state "owner disabled,
connection still live" can't exist. And the answer key already says so: *Identity lifecycle / JML -
CLOSES IT: connections die with the owner.*
**Fix (decided 2026-10-19: "departed, still enabled").** Tom is a leaver nobody shut down. Phase 6.5 is now
`01_provision_entra.ps1 -MarkDepartedOwner`: it sets his `employeeLeaveDateTime` (Entra's leaver record,
which Lifecycle Workflows act on) and leaves the account enabled. `users-export` gains `employee_leave_date`.
Disabling Tom is the Exercise 05 fix to test, never a build step.
**Also found.** Tom had **no licence** (he lost it when recreated), so `Ensure-Connection` failed with
`InvalidUserPlan`; the Phase 6 seat loop covers him on a fresh build. And Onboarding Guide was still owned
by the *deleted* Tom's Dataverse record (renamed `<objectid>tom.dean...`), which 06 can't clone as the live
Tom: reassign the bot, its components and its connection reference to the live record first (as for Sam's
Expense Helper, whose SubmitExpense topic also pointed at the deleted Sam's flow until a 06 re-run resolved
`${FLOW:...}` again).
**Doc impact.** 02-03 hunts 1/4/5, 02-04, 05-05, 05-07, 06-01 ("whose account is disabled. The connection
is still live") and the inventory key say "disabled"; they need "departed (leave date), still enabled".

### All phases · a shell without `scripts/env.sh` uses your OTHER tenant (2026-10-19)

**Symptom.** `06_provision_agents.ps1` printed `Estate 'mgray' on <a different company's domain>` and failed
looking up a persona.
**Evidence.** It ran in a detached background shell that hadn't picked up `AZURE_CONFIG_DIR`, so `az` used
`~/.azure` - the facilitator's day-job tenant. It got as far as listing environments and one user lookup
(reads; the 404 stopped it). A run with the persona names already in place there would have written.
**Fix.** `_estate.ps1` (loaded by every Phase 1-9 script) now points an unset `AZURE_CONFIG_DIR` at the
repo's `.azure/` and **throws** if it is set anywhere else. `00_conditional_access_baseline.ps1` doesn't load
it but requires `-TenantId`.

### Phase 8b · a viewer can't open a connector tool's Details without prvReadconnectionreference (2026-10-19)

**Symptom.** As student03, Claims Copilot → Tools → *List claims* showed only "This Tool has encountered an
error obtaining required dependencies"; the MCP tool on Underwriting Assistant opened fine.
**Evidence.** `Bot Viewer` grants `prvReadconnectionreference` at **Basic** depth, and Claims Copilot's
references belong to svc-claims and Priya. Adding it at **Global** to the Lab Reviewer role in Claims-Test
fixed it at once (Details then show *Maker-provided credentials*).
**Fix.** In `$DvAccessModel`; applied by hand to the role in all four environments (re-running 07 would
also re-license student01-05). Also confirmed as a viewer: Settings (Connection Settings, Advanced →
Metadata) is closed at every address; Knowledge, Tools and Topics open at `/knowledge`, `/actions`, `/topics`;
the bots table's `synchronizationstatus.applicationId` equals the agent identity's Application ID.

### Review fixes to this branch (2026-10-19)

A review of PR #10 found, and this commit fixes:
- **Security Administrator was PIM-eligible** for 05-07, but it can create, update and delete Conditional
  Access policies - the CA-Require-MFA-Admins lockout the access model refuses CA Administrator for. Removed
  from `$EligibleRoles`; 07 withdraws it (`$RetiredEligibleRoles`); withdrawn live from all five accounts.
  Defender real-time protection is a facilitator step (RUNBOOK Phase 8b).
- **`Ensure-LabApp` returned early** once app and certificate existed, so an app made by 03c before 07 needed
  PIM never got `RoleEligibilitySchedule.ReadWrite.Directory`, and the certificate was never renewed. It now
  checks every step on every call and renews a certificate within 30 days of expiry; 07 retries a 403 while
  a fresh grant propagates and skips the billing link (`-NoBilling`).
- **01 and 05 asked for `User-LifeCycleInfo.*`,** which the az token never carries, forcing device code on
  every run. Dropped: Directory.AccessAsUser.All on the reused az token already reads and writes the leave
  date. The device-code fallback in `_auth.ps1` is now pinned to the az tenant and checked afterwards.
- **06:** a failed temporary-role bind now warns (it was silent) and the role is created inside the `try` and
  removed by name; the Teams channel is judged by the bot record's `channels`, not by the browser script,
  which no longer reports "already" when it simply couldn't find the button.
- **03c** built Marcus's UPN on the initial domain; personas use the default domain.

### Delivery · Exercise 05 is demonstrated, not done by attendees (2026-10-19)

**Decision (Matt, 2026-10-19).** Attendees share one estate, so one attendee's change is everyone's result
(16 people applying and undoing the same DLP policy on top of each other). The facilitator applies each
control once, live, and restores it; attendees retest. Pages: PR #17.
**Kit.** No attendee write role remains: AI Administrator eligibility is retired too (withdrawn live from
the five lab accounts; 07 withdraws it on re-run). `09_ex05_demo_state.ps1` snapshots and restores what a
script can restore exactly - data policies, the default environment's Environment Maker users AND teams,
svc-claims' roles and teams in Claims-Test - and the RUNBOOK lists the portal-only reversals (knowledge
scope, the Agent 365 Block, Defender). It replaces the walkthrough pipeline's `estate_state.py`, which
lived outside the repo and stripped every team from Environment Maker on restore, whether or not a team
held it before.

### Exercise 05 · the DLP list call has no connector groups - a snapshot built on it can't restore (2026-10-19)

**Symptom.** In the first facilitator-account recording of 05-01, `09_ex05_demo_state.ps1 -Diff` reported
"same as the snapshot" after the facilitator had blocked both HTTP connectors, and the safety restore did
nothing. Halcourt-Prod's policy was left blocking HTTP until it was restored by hand (17:22-17:25 UTC).
**Evidence.** `GET .../PowerPlatform.Governance/v2/policies` returns each policy WITHOUT `connectorGroups`;
`GET .../policies/<id>` includes them (Confidential 1771 / Blocked 2 after the save). The script compared and
snapshotted the list form, so classification was invisible to it.
**Fix.** `DlpAll` reads every policy individually; the shape includes the default classification; Restore
refuses a snapshot without connector groups. Tested end to end: an API PATCH blocking HTTP -> Diff
`CHANGED` -> Restore -> Blocked 0.

### Phase 6 · the committed workspaces named THIS tenant and estate (2026-10-19)

**Symptom.** Six committed knowledge sources pointed at `https://<this tenant>.sharepoint.com/sites/...-mgray` (and
Dev's OneDrive by its literal personal path), and the two default-environment agents' display names said
"(mgray)" - captured from the first build. Any other tenant or estate would have built Benefits Buddy, Team
Wiki, HR FAQ v2, Claims Copilot and Meeting Notes grounded on the FIRST build's sites, and named its
default-environment agents after another estate.
**Fix.** The workspaces use tokens; 06 resolves them at push: `${ESTATE}`, `${SP_HOST}` / `${SP_MY_HOST}`
(from the tenant's initial domain), `${UPN_PATH:<alias>}` (a persona's OneDrive path segment). Verified: the
substitution reproduces every committed file exactly for estate mgray.

### Exercise 05 · a role can't be given back to a disabled user (2026-10-19)

**Symptom.** Restoring the default environment's Environment Maker after a 05-02 lockdown stopped at the first
re-add: `0x80048d35 ... User ... is disabled. User must be enabled or Organization setting
AllowRoleAssignmentOnDisabledUsers must be turned on`.
**Evidence.** The default environment keeps a **disabled** record for every persona deleted and recreated
(username `<32 hex><upn>`): 12 of them held Environment Maker. Removing a role from them works; adding it
back doesn't.
**Fix.** `09` re-adds each user separately and reports the ones it can't; a lockdown demonstration removes only
enabled, current accounts. The 12 stale records lost the role (harmless: they can't sign in) and the
snapshot was retaken.

### Phase 4 · public group sites gave every employee the comp file (2026-10-19)

**Symptom.** As student03 (an ordinary employee), `Leadership/2026-comp-bands.xlsx` opened directly - so
Benefits Buddy disclosing it proved nothing, and Scenario B's asymmetry was gone.
**Evidence.** 03 created both sites' M365 groups through Graph without `visibility`, so they were **Public**,
and SharePoint put `Everyone except external users` in each site's Members group. `Leadership/` keeps
Members. Claims-Knowledge had the same grant: every employee could edit the claims knowledge base.
**Fix.** Groups are created `Private`; on a site that already exists 03 sets the backing group `Private` (a
public group lets any employee join and become a member), and `Grant-SiteAccess` strips the Everyone claim
from Members - both, so a re-run repairs an existing site. Live: both groups set Private, the claim removed from both sites. After the fix
student03 gets SharePoint's access-denied page for the file, and Benefits Buddy, asked in Teams as student03,
**still** returns the comp table - re-asked 35 minutes later, after the index had time to catch up, with
the same result. The agent reads what the employee can't: Scenario B's asymmetry is real once the site is
private. Test path: Teams web as student03 via the agent's install link (06 now saves it).

### Exercise 05-03 · narrowing Benefits Buddy's grounding did not stop the leak within an hour (2026-10-20)

**What was done.** As the owner (Marcus), Benefits Buddy's whole-site `HR-Benefits` knowledge source was
replaced by the single file `Shared Documents/Open-Enrollment-FAQ.docx` and the agent was published (09:35;
Copilot Studio: "Your users will see the new content soon"). The knowledge list showed only the FAQ.
**Observed.** As student03 in Teams (who gets access-denied on the comp file itself), after "Start over":
10:08 and 10:40 - both times Benefits Buddy returned the full 2026 comp table, citing `2026-comp-bands.xlsx`.
A recording run the same morning saw the same at +10 minutes. Restored afterwards with
`06 -Agents benefits-buddy`.
**Why it matters.** 05-03's suggested verdict for Least privilege x B is "CLOSES IT when the retest shows the
comp file no longer appears". On this platform the retest, run in the session, will show it still
appearing: removing a source from an agent does not promptly remove what was indexed from it. The honest
in-session verdict is DENTS IT at best ("the change is right, but its effect is not observable within the
lab"), or the lab should scope the reader's SharePoint permission instead - the route 05-03 also offers - and
retest that. **Decision for the exercise owner.** Not root-caused: whether the answer comes from a retained
index, a cached published version, or another grounding path is open.

### Phase 5b · nothing was being audited, so 05-07 had nothing to reconstruct (2026-10-20)

**Symptom.** Probing 05-07 as student03, Purview Audit's search form was greyed out and its list said
*"Failed to load data"*, under *"Sorry, we're having trouble figuring out if activity is being recorded"*.
**Evidence.** `Get-AdminAuditLogConfig`: `UnifiedAuditLogIngestionEnabled = False`; `Search-UnifiedAuditLog
-RecordType CopilotInteraction` over three days: 0. In `Claims-Test-mgray`: `isauditenabled`,
`isreadauditenabled`, `isuseraccessauditenabled` all false, and `mm_claim` / `mm_customer` not audited.
PLANNING item 16 assumed Purview Audit is "on by default" - not on a developer tenant - and no phase did the rest.
**Fix.** `04b_provision_audit.ps1` (RUNBOOK Phase 5b) turns on ingestion (Exchange Online, the 03c app),
environment auditing and the two tables' change/read/list-read auditing. It must run at least an hour before
Exercise 04. A table's flags read back False for a while after the publish; the script's check retries.
**Still open:** Defender real-time protection for agents.

**Also found - what an attendee reaches in 05-07** (Global Reader, Security Reader, Power Platform
Administrator), for the exercise owner:

| Step | Result |
|---|---|
| KT01 s1, KT02, KT05 s1 - Purview Audit search | form greyed out (above), even though Purview's `GlobalReader` role group lists View-Only Audit Logs. Not re-tested now ingestion is on |
| KT04 s2, KT05 s2 - DSPM for AI | *"Additional permissions required. Your role can't view or take action on certain data items"* |
| KT01 s3, KT06 s1 - Defender real-time protection | Settings: *"You don't have permission to view this page"* |
| KT03 - a claim's audit history | Dataverse: *"missing prvReadRecordAuditHistory"*. Opening the claim at all would need claim read, which would break Scenario D |

Decided 2026-10-20: 05-07 becomes a facilitator demonstration. The facilitator's audit reach is the Purview
`SecurityAdministrator` role group (Audit Logs, View-Only Audit Logs), which it gets by activating its
PIM-eligible Security Administrator - also what the Defender step needs. The lab app can't add Purview
role-group members (`Add-RoleGroupMember` exposes no `-Identity` to it), so DSPM content (`Data Security AI
Content Viewers`) is not granted yet.
