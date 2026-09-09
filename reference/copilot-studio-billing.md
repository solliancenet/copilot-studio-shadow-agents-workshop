# Copilot Studio — billing & licensing models

Background reference for the facilitator build. **Not attendee content.** Verified against
Microsoft Learn primary sources (doc dates noted); re-verify before each delivery — these
surfaces change often.

## TL;DR for this workshop

- To **publish** the 10-agent estate you need a **publish-capable** license. The **trial license
  cannot publish** (create + test-chat only).
- The only publish-capable path that does **not** require an Azure subscription is the
  **standalone prepaid Copilot Credit pack subscription**. Everything else with "publish" either
  needs an Azure subscription (pay-as-you-go, CCCU prepurchase) or only partially covers the
  estate (Microsoft 365 Copilot USL — authenticated B2E only).
- Copilot Studio metering currency is **Copilot Credits** (renamed from "messages" on
  2025-09-01).

## The billing/licensing models

### 1. Microsoft 365 Copilot USL (per-user license)
- Employee-facing (**B2E**), **authenticated** agent usage is **included at no charge** when the
  agent runs under the authenticated M365 Copilot user's identity (subject to fair-use limits).
- **No Azure subscription required.**
- **Does not cover:** Computer-Using Agents (CUA); agent flows except via the *"When an agent
  calls the flow"* trigger; **autonomously-triggered agents and web/unauthenticated channels** —
  all bill at standard credit rates.
- The E5 **Developer sandbox does not include** M365 Copilot USL (separate paid license).
- For this estate: only partial cover (the estate has autonomous + web channels), so USL alone
  is insufficient.

### 2. Standalone Copilot Studio subscription (prepaid Copilot Credit pack)
- Build/publish agents on **any supported channel** + premium connectors.
- Bought via **Marketplace** (main left nav in the Microsoft 365 admin center) → search "Copilot."
  **No Azure subscription required.**
- Tenant-pooled credit capacity; **enforced monthly**, unused credits **do not carry over**;
  **overage at 125% disables custom agents** until capacity is increased/reset.
- The "free" Copilot Studio **maker/user license presupposes** a tenant prepaid pack:
  > "You need a Copilot Studio tenant prepaid Copilot Credit pack subscription before you can get
  > this user license."
- **Recommended default for the workshop** — publish-capable and avoids the Azure-Plan blocker.

### 3. Pay-as-you-go (PAYG) meter
- Pay for Copilot Studio via an **Azure subscription**, no upfront commitment; monthly billing of
  actual credits consumed. Link environments to the subscription with a **billing policy**
  (Power Platform admin center, or M365 admin center → Billing → Pay-as-you-go).
- **Requires an Azure subscription** with the admin as Owner/Contributor. With PAYG there is no
  125% cutoff (overage just bills through).
- **This is the blocker we hit** (see "Live blocker" below).

### 4. Copilot Credits prepurchase plan (CCCUs)
- One-year prepaid pool of **Copilot Credit Commit Units**, usable across eligible Microsoft
  products. Purchased in the **Azure portal**.
- **Also requires** a billing policy → **Azure subscription**.

### 5. Trial license
- Sign up as an individual to **create agents and test in the test-chat panel only**.
  > "The trial license gives you access to Copilot Studio to create agents. You can test your
  > agents using the test chat panel. However, you can't publish the agent."
- **Cannot publish.** Dead end for the estate build. Admins can also block viral trial signups.

## Copilot Credits — how metering works (standard harness)

- Currency = **Copilot Credits**; total cost = sum of credits consumed. Rate depends on agent
  design, interaction volume, and features used.
- Sample rates (per the rates page; verify before delivery):
  - Classic answer = 1 · Generative answer = 2 · Agent action = 5 · Tenant graph grounding = 10
  - Agent flow actions = 13 per 100 · AI tools basic/standard/premium = 1 / 15 / 100
  - Voice: Classic 10, GenAI 35, Premium GenAI 75 (credits/min)
- Whole **"Used by Microsoft 365 Copilot licensed user"** column = **No charge** (the USL B2E
  inclusion, with the exclusions listed under model 1).
- **Overage enforcement (prepaid model):** at **125%** of prepaid capacity, custom agents are
  disabled; admin notified by email + PPAC. PAYG environments are not subject to the cutoff.
- Reasoning models bill twice: *feature rate* + *text and generative AI tools (premium)* per 1K
  tokens.

## Live blocker (2026-09-08, 0zwdt94t.onmicrosoft.com dev sandbox)

Attempting Copilot Studio PAYG on the E5 dev sandbox:
- `Billing → Pay-as-you-go → Add a billing policy` requires an **Azure subscription**; the admin
  (JC) had **none** ("You don't have the Owner or Contributor role on any Azure subscription").
- The inline **"Create a new Azure subscription"** flyout failed twice: *"We couldn't create the
  subscription. Please try again later."* — a red herring. **The problem was NOT a missing
  subscription:** two Azure subscriptions already existed under the tenant/MCA; the admin (JC)
  simply had **no RBAC role on them**, so they didn't appear in the billing-policy dropdown and
  the wizard's "you have no Owner/Contributor subscription" banner fired.
- **ACTUAL FIX (what worked, 2026-09-08):** in **Entra admin center → Azure/tenant properties →
  "Access management for Azure resources"**, JC elevated to **User Access Administrator at the
  root scope**, then assigned themselves **Contributor** on each of the two existing
  subscriptions (Azure portal → Subscription → Access control (IAM) → Add role assignment). After
  that the subscriptions appear in the PAYG billing-policy dropdown and the policy can be created.
- Lesson: before assuming you must *create* a subscription (or chase a billing-admin grant),
  check whether subscriptions already exist and you just lack **RBAC** — self-elevate via Entra
  and assign **Contributor**. Creating a new subscription is only needed if none exist.
- Alternative (no Azure sub at all): buy a **standalone prepaid Copilot Credit pack** (model 2).
- **Follow-up (same live run):** the Dataverse "0 GB capacity" blocker turned out to be **false** — the
  sandbox carried **5 GB prepaid Database capacity**, and `Claims-Test` (Sandbox + Dataverse) created
  normally, consuming 1 GB of prepaid, with **no PAYG needed** for the environment itself.
- **Region-lock lesson:** a PPAC billing plan is **locked to one region** and only lists environments in that
  region. The New-environment picker's **Macro Region** ("North America") auto-assigned **Canada**, which did
  not match a **United States** plan — the env couldn't be linked. Fix: make the environment and the billing
  plan land in the **same region**. A region-matched plan (`ppccdevcanada`, Copilot Studio meter) then linked
  to Claims-Test cleanly.
- **Where Copilot Studio PAYG actually lives:** not the M365 admin center's Pay-as-you-go page (no Copilot
  Studio there) — it's a **PPAC billing plan** (Licensing → Billing Plans) with the Copilot Studio meter,
  linked per-environment.

## How Copilot Studio connects to the subscription (PAYG)

Creating the pay-as-you-go **billing policy** (M365 admin center → Billing → Pay-as-you-go) does not by
itself meter Copilot Studio — Copilot Studio is **not** listed on that page's **Services** tab (its entries
are M365 Backup, Microsoft 365 Copilot [the USL chat product], High Volume Email, SharePoint/OneDrive
Storage, Perception). The Copilot Studio ↔ subscription link is **per-environment**, done in the **Power
Platform admin center**:

- **PPAC → Licensing → Billing Plans → New billing plan** (or edit an existing one) → select the
  **Azure subscription** → choose **Power Platform products** meters → **Select environments** → add each
  environment. Available for **production/sandbox** environments only, so it happens in **Phase 3** once the
  Dataverse-backed environments exist (the default environment has no Dataverse).
- **Do not** create the special **"Microsoft 365 Copilot Chat"** billing plan — it auto-provisions a
  `Microsoft 365 Copilot Chat` environment for unlicensed users consuming agents in Copilot Chat, which is
  not the custom published estate. Use the standard plan linked to your own environments.

Source: https://learn.microsoft.com/en-us/power-platform/admin/pay-as-you-go-set-up

## Sources (Microsoft Learn)

- Standard harness licensing — https://learn.microsoft.com/en-us/microsoft-copilot-studio/billing-licensing (ms.date 2026-08-03)
- Billing rates and management — https://learn.microsoft.com/en-us/microsoft-copilot-studio/requirements-messages-management (ms.date 2026-08-03)
- Manage Copilot Credits and capacity (Power Platform admin) — https://learn.microsoft.com/en-us/power-platform/admin/manage-copilot-studio-messages-capacity
- FAQ for Copilot Studio billing and licensing — https://learn.microsoft.com/en-us/microsoft-copilot-studio/faq-billing-licensing
- Prepaid Capacity Packs vs Pay-as-you-go (M365 Copilot) — https://learn.microsoft.com/en-us/microsoft-365/copilot/pay-as-you-go/copilot-capacity-packs
- Copilot Studio Licensing Guide (canonical PDF) — https://go.microsoft.com/fwlink/?linkid=2320995
