# Agent authoring guide (Phase 6)

> **FACILITATOR-ONLY.** Copilot Studio agent authoring is largely manual today. Build all ten agents in
> the maker portal exactly per [`../AGENTS.md`](../AGENTS.md). Where `pac solution export/import` works
> for your build (`[verify]` in [`../PLANNING.md`](../PLANNING.md)), export the finished agents to a
> solution so re-provisioning is fast.

## General steps (every agent)

1. Sign in to Copilot Studio as the **owner** listed for the agent (this sets the agent owner correctly).
2. Create the agent **in the specified environment** (this matters — Default vs Prod vs Claims-Test vs
   Maker-Sandbox is part of each scenario).
3. Configure **grounding**, **connections**, and **actions/tools** as specified.
4. **Publish** the agent (the auto-created Entra identity appears — confirm the `cs-agent-<slug>-<env>`
   naming; capture the app id for `agent-identities-export.csv`).
5. Confirm the planted problem reproduces before moving on.

{: warning}
Owner and connection ownership are distinct. For Onboarding Guide and Sales Nudge, the **connection**
must be owned by `tom.dean` even though the agent owner differs — build those connections while signed in
as Tom, then attach them.

## Per-agent recipe

### Benefits Buddy  (Halcourt-Prod, owner marcus.webb)
- Ground on the **whole `HR-Benefits` site**, including `Leadership/`. Do not scope it down.
- Connection: SharePoint as Marcus (user/delegated).
- No custom actions. Publish. Verify Scenario A (poisoned FAQ steers the answer) and Scenario B
  (an employee can pull `Leadership/2026-comp-bands.xlsx`).

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

### Onboarding Guide  (Halcourt (default), owner tom.dean → later disabled)
- Build **as Tom**: SharePoint + Office 365 Outlook (send mail) connections **owned by Tom**.
- Publish. In **Phase 6.5**, disable Tom (`01_provision_entra.ps1 -DisableDepartedOwner`). Leave the agent
  and connections live. Verify Scenario F / orphan (still published, still can send mail, no owner).

### Team Wiki  (Maker-Sandbox, owner dev.kim)
- Build **as Dev**: SharePoint + Microsoft Graph search across the sites Dev can see (broad).
- Publish. Verify it is a **shadow** agent — present only if you inventory the sandbox environment.

### Sales Nudge  (Halcourt-Prod, owner lena.ford; connection owned by tom.dean)
- Agent owned by **Lena**, but attach a **CRM/Dataverse shared connection owned by `tom.dean`**.
- Publish. Verify the shared-connection / hidden-effective-owner finding (agent owner present, connection
  owner departed).

### HR FAQ v2 (copy)  — DECOY  (Halcourt-Prod, owner marcus.webb)
- Read-only. Ground on a **single all-staff FAQ library only** (not the whole site, no `Leadership/`).
  No actions. Publish. This must be genuinely clean — it is the noise that teaches "risk = effective
  access, not vibes."

### Meeting Notes Summarizer  — DECOY  (Maker-Sandbox, owner dev.kim)
- Ground on **Dev's own OneDrive** only. No shared data, no actions. Publish. Benign noise.

## After authoring

- Run **Phase 6.5** to orphan Tom.
- Run **Phase 7** (`05_export_artifact_pack.ps1`) and diff against the committed artifact pack.
- Run **Phase 8** validation against `AGENTS.md`.
