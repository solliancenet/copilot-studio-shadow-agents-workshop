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

### Phase 1 · `azd up` fails once on the Foundry account — retry it

**Expect this on every rebuild** (reproduced on both the 2026-09-22 rebuilds). Every Container App deploys,
then the run ends with:

```text
RequestConflict: Another operation is in progress on the resource
  .../Microsoft.CognitiveServices/accounts/aif-<token>
```

It is transient — the account is still settling from the teardown. **Re-run `azd up` and it completes.**
Two things make this look worse than it is: `azd` exits 0 despite the failure, so check the output rather
than the exit code, and the deployment outputs (`POLICY_API_FQDN`, `UNDERWRITING_MCP_FQDN`) are **not**
written to the azd env until the run succeeds — so Phase 6, which reads them, must wait for a clean `azd up`.

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
  refs; the connection owner (a SysAdmin in that env, e.g. Tom in Prod) binds connections it owns — **before**
  Phase 6.5 disables Tom.
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
