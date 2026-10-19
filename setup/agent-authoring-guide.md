# Agent authoring guide (Phase 6)

> **FACILITATOR-ONLY.** Build all ten agents exactly per [`../AGENTS.md`](../AGENTS.md) — in the maker
> portal, or from the command line as each owner with `pac copilot init/push/publish` (RUNBOOK → Phase 6,
> which also lists the prerequisites: owner seats, environment roles, Dataverse in the default environment,
> billing, connections). Where `pac solution export/import` works
> for your build (`[verify]` in [`../PLANNING.md`](../PLANNING.md)), export the finished agents to a
> solution so re-provisioning is fast.

## Estate names

Every name below is **canonical**. Build with your estate's live names ([`../AGENTS.md`](../AGENTS.md) →
*Live estate naming*; RUNBOOK → *Estates*), for estate `<estate>` on tenant domain `<domain>`:

| Canonical, below | Build with |
|---|---|
| owner / connection owner `marcus.webb`, `tom.dean`, `svc-claims`, `it.helpdesk` | `marcus.webb.<estate>@<domain>`, `tom.dean.<estate>@<domain>`, … |
| environments `Halcourt-Prod`, `Claims-Test`, `Maker-Sandbox` | `Halcourt-Prod-<estate>`, `Claims-Test-<estate>`, `Maker-Sandbox-<estate>` |
| sites `HR-Benefits`, `Claims-Knowledge` | `/sites/HR-Benefits-<estate>`, `/sites/Claims-Knowledge-<estate>` |
| environment `Halcourt (default)` | the same — it is the tenant's only default environment, **shared** by every estate |

Agents keep their canonical names — except the two in the shared default environment, which get
` (<estate>)` so every estate's are told apart: **Expense Helper (\<estate\>)**, **Onboarding Guide
(\<estate\>)**. The Phase 7 export picks this estate's agents there by owner.

## General steps (every agent)

1. Sign in to Copilot Studio as the **owner** listed for the agent (this sets the agent owner correctly).
2. Create the agent **in the specified environment** (this matters — Default vs Prod vs Claims-Test vs
   Maker-Sandbox is part of each scenario).
3. Configure **grounding**, **connections**, and **actions/tools** as specified.
4. **Publish** the agent and capture its Entra identity's app id for `agent-identities-export.csv`. The
   identity appears as soon as the agent is created, as an `agentIdentity` service principal named
   **`<agent name> (Microsoft Copilot Studio)`** — not `cs-agent-<slug>-<env>`, which is only the pack's
   canonical label (verified 2026-09-19). The name carries no estate id, so tell estates' identities
   apart by app id (`bots.synchronizationstatus` → `botRegistration.applicationId`).
5. Confirm the planted problem reproduces before moving on.

{: warning}
Owner and connection ownership are distinct. For Onboarding Guide and Sales Nudge, the **connection**
must be owned by `tom.dean` even though the agent owner differs — build those connections while signed in
as Tom, then attach them.

## Per-agent recipe

### Benefits Buddy  (Halcourt-Prod, owner marcus.webb)
- Ground on the **whole `HR-Benefits` site**, including `Leadership/`. Do not scope it down.
- Connection: SharePoint as Marcus (user/delegated).
- No custom actions. Share chat with `All-Employees`. Publish. Verify Scenario A (poisoned FAQ steers the
  answer) and Scenario B (an employee can pull `Leadership/2026-comp-bands.xlsx`).
- **Built this way on the verified tenant (2026-09-19)** — whole-site SharePoint knowledge, no tools,
  chat limited to `All-Employees-<estate>`. Two things to check in Phase 8, both **[verify]**:
  - **Scenario B may not reproduce from knowledge alone.** SharePoint knowledge answers with the *asker's*
    permissions, and `Leadership/` drops the visitors, so Jordan may get nothing from it. If so, record it
    — the canon's "data the agent can read but the user cannot" needs a different mechanism.
  - **Marcus's `SP-HR-Benefits` connection isn't used.** SharePoint knowledge needs no connection, so a
    knowledge-only agent leaves it unattached, and Phase 7 will export it with no `used_by_agent`.

### Claims Copilot  (Claims-Test, owner priya.nair)
- Connection: **shared Dataverse connection running as `svc-claims`** (the over-broad role from Phase 5).
- Tools: Dataverse *List rows* on Claim and Customer; *Update claim status*.
- Ground on `Claims-Knowledge`. Publish. Verify Scenarios C (reads all rows + PII), D (Jordan Blake can
  read/modify any claim), F (it is a "test" env doing prod work).

### Policy Lookup Bot  (Halcourt-Prod, owner = it.helpdesk shared mailbox)
- Add an **HTTP action** to `https://<policy-api-fqdn>/policy/{id}` (`<policy-api-fqdn>` = the Policy API
  Container App FQDN from the Phase 1 deployment outputs), with the **static API key in
  the action header config** (the key you deployed in Phase 1). Take `{id}` straight from user input.
- No input validation. Publish. Verify Scenario E (key in config; input crosses; `/policy/all` and
  `/customer/{id}` reachable).

### Underwriting Assistant  (Halcourt-Prod, owner priya.nair)
- Add the **Underwriting MCP** tool connection to `https://<mcp-fqdn>/underwriting` (`<mcp-fqdn>` = the
  Underwriting MCP Container App FQDN from the Phase 1 deployment outputs) with
  the **static bearer**. Import the full tool set including `run_query`.
- Publish. Verify Scenario E (weak auth; over-wide tool schema; `run_query` returns broad rows).

### Expense Helper  (Halcourt (default), owner sam.olsen)
- Add a Power Automate flow **"Submit and auto-approve expense under $500"** that runs as **Sam** (an
  approver). Trigger it from the agent.
- Publish. Verify Scenario D (a requester auto-approves via the agent's authority, not their own).

### Onboarding Guide  (Halcourt (default), owner tom.dean → departed, still enabled)
- Build **as Tom**: SharePoint + Office 365 Outlook (send mail) connections **owned by Tom**.
- Publish. In **Phase 6.5**, mark Tom departed (`01_provision_entra.ps1 -MarkDepartedOwner`): a leave date,
  account left **enabled**. Never disable him: Entra then refuses his token refresh and both connections
  go to Error. Verify Scenario F / orphan (still published, still can send mail, owner has left).

### Team Wiki  (Maker-Sandbox, owner dev.kim)
- Build **as Dev**: SharePoint + Microsoft Graph search across the sites Dev can see (broad).
- Publish. Verify it is a **shadow** agent — present only if you inventory the sandbox environment.

### Sales Nudge  (Halcourt-Prod, owner lena.ford; connection owned by tom.dean)
- Agent owned by **Lena**, but attach a **CRM/Dataverse shared connection owned by `tom.dean`**.
- Publish. Verify the shared-connection / hidden-effective-owner finding (agent owner present, connection
  owner departed).

### HR FAQ v2 (copy)  — DECOY  (Halcourt-Prod, owner marcus.webb)
- Read-only. Ground on the **`HR FAQ` document library only** — `/sites/HR-Benefits-<estate>/HR FAQ`
  (Phase 4 creates it: a dedicated all-staff library with one clean FAQ). **Not** the whole site, **not**
  `Shared Documents` (that holds the poisoned FAQ + `Leadership/`). No actions, no tools. Share chat with
  `All-Employees-<estate>`. Publish. This must be genuinely clean — it is the noise that teaches "risk =
  effective access, not vibes." Verify: ask an FAQ question (answers) and ask about exec comp or a claim
  (declines — it can't reach them).

### Meeting Notes Summarizer  — DECOY  (Maker-Sandbox, owner dev.kim)
- **Prerequisite:** Phase 4b has provisioned and seeded Dev's OneDrive (`03b_provision_onedrive.ps1`).
- Ground on **Dev's own OneDrive only** — the seeded `Dev-Kim-Meeting-Notes.docx` at
  `https://<tenant>-my.sharepoint.com/personal/dev_kim_<estate>_<tenant>_onmicrosoft_com/Documents`. Remove
  the default **"Search all websites"** knowledge chip. No SharePoint, no tools, no actions. Owner-only chat.
  Publish. Benign noise — it summarizes only Dev's own notes and can reach nothing else.

## After authoring

- Run **Phase 6.5** to orphan Tom.
- Run **Phase 7** (`05_export_artifact_pack.ps1`) and diff against the committed artifact pack.
- Run **Phase 8** validation against `AGENTS.md`.
