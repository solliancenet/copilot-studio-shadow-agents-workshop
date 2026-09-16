# Runbook — errata, options & known issues

> Background, alternatives, troubleshooting, and open `[verify]` risks for the [provisioning runbook](../setup/RUNBOOK.md). Keyed to the phase/step they relate to.

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

### Phase 1 · Foundry project soft-delete (AmlRp) — the re-provision trap

Verified live (2026-09-16). Tearing down and re-provisioning the **same** azd env name can dead-end the Foundry layer:

- `azd down --purge` does **not** purge the Foundry **project's** backing AmlRp workspace. It leaves a soft-deleted tombstone (`proj-<token>`) that blocks recreating the project name. Worse, **every failed `azd up` regenerates the tombstone**, so purge-and-retry never converges; the `aif-<token>` account can also stick in a `Failed` state.
- The tombstone is invisible to every discovery surface checked: the Foundry portal, the Azure ML **Recently deleted** blade, `az cognitiveservices account list-deleted`, and all `Microsoft.MachineLearningServices` `deletedWorkspaces`/workspace list api-versions.
- **Reliable fix — re-provision under a NEW env name** (`azd env new <name2>` → new `resourceToken` → an uncontaminated `proj-<newtoken>`). This deploys cleanly; the old poisoned name is simply abandoned.
- **Manual purge recipe (only if you must keep the same name):**
  1. Purge the project tombstone:
     `az rest --method delete --url "https://management.azure.com/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.MachineLearningServices/workspaces/proj-<token>?api-version=2026-03-01&forceToPurge=true"`
     (Use `az rest`, not `az ml workspace delete --permanently-delete` — the latter does a GET-before-DELETE that 404s on an invisible tombstone.)
  2. If the account is `Failed`/soft-deleted: `az cognitiveservices account delete -g <rg> -n aif-<token>` then `az cognitiveservices account purge -g <rg> -n aif-<token> -l <region>`.
  3. Retry `azd up`. Note this still loops if the underlying project create keeps failing — which is why the fresh-name path is preferred.

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
Studio refuses to create an agent or shows no target environment, check Dataverse capacity in
**PPAC → Licensing → Capacity add-ons → Dataverse** (see Errata) and resolve before continuing.

### Phase 6 · solution packaging

Where `pac solution export/import` works for your build, package the agents to speed re-provisioning (see the
`[verify]` note in `PLANNING.md`).
