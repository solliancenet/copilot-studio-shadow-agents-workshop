# Agent Estate Inventory — ANSWER KEY

> **FACILITATOR-ONLY. Do not publish.** Excluded via `worksheets/answer-keys/` and `**/*.answers.md`.
> Derived from `AGENTS.md`. Use to check attendee inventories.

## Completed flags

| Agent | Env | Owner (status) | Data sensitivity | Orphan | Shadow | Test→Prod | Shared conn | Unknown owner | Forgotten |
|---|---|---|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Benefits Buddy | Prod | marcus.webb (ok) | Compensation (whole-site `HR-Benefits` incl. `Leadership/2026-comp-bands.xlsx`) | | | | | | |
| Claims Copilot | Claims-Test | priya.nair (ok) | PII (Dataverse `Customer`: SSN, DOB) | | | ✅ | ✅ (svc-claims) | | |
| Policy Lookup Bot | Prod | it.helpdesk (shared mbx) | PII (full-scope Policy API key reaches `/customer/{id}`) | | | | | ✅ | |
| Underwriting Assistant | Prod | priya.nair (ok) | Internal (pricing DB via `run_query`) | | | | | | |
| Expense Helper | Default | sam.olsen (ok) | Internal (expense records) | | | | | | |
| Onboarding Guide | Default | **tom.dean (DISABLED)** | Internal (SharePoint + mail send) | ✅ | | | ✅ (tom.dean) | | ✅ |
| Team Wiki | Sandbox | dev.kim (ok) | Internal (every site Dev can read — not `Leadership/`) | | ✅ | | | | ✅ |
| Sales Nudge | Prod | lena.ford (ok) | PII (CRM/Dataverse under Tom Dean's broad CRM access) | | | | ✅ (tom.dean CRM) | ✅ (conn≠agent owner) | |
| HR FAQ v2 (copy) | Prod | marcus.webb (ok) | Internal (`HR FAQ` library only) | | | | | | (decoy — clean) |
| Meeting Notes Summarizer | Sandbox | dev.kim (ok) | Internal (Dev's own OneDrive notes) | | | | | | (decoy — clean) |

Data sensitivity is by **reach**, not intent. An attendee working from the artifact pack alone has no
grounding data, so Benefits Buddy may be classified from its SharePoint connection only; accept
"Compensation (from connections only)" or a classify-up equivalent.

## The joins that reveal the findings

- **Onboarding Guide orphan:** `agents-export` owner = `tom.dean`; `users-export` shows `tom.dean` →
  `account_enabled = FALSE`, last sign-in 2026-01-30. Connection still live in `connections-export`.
- **Sales Nudge hidden owner:** agent owner `lena.ford` (enabled) but `connections-export` shows
  `DV-CRM-Shared` owned by `tom.dean` (disabled). The effective authority is a ghost.
- **Claims Copilot:** environment `Claims-Test` (type Sandbox in `environments-export`, no DLP) but doing
  production work; connection `DV-Claims-Shared` owned by `svc-claims` (service account) shared with the
  Claims-Adjusters group.
- **Policy Lookup Bot:** owner `it.helpdesk` = shared mailbox (`users-export` `is_shared_mailbox = TRUE`)
  → nobody personally accountable; connection auth type = "API key in action config".
- **Expense Helper (not flagged):** hunt 4's group-share check surfaces `PA-Expense-AutoApprove`, shared
  with `All-Employees`, running as owner. Expect attendees to raise it. It doesn't take the Shared
  connection flag: it runs as `sam.olsen`, the agent's own enabled owner. Carry the share into Exercise 03.
- **Onboarding Guide is not Unknown / ambiguous owner:** its owner is a known, named, disabled person.
  That is the Orphan flag.
- **Team Wiki:** `Maker-Sandbox`, personal env, not in any sanctioned list — pure shadow.
- **Decoys:** HR FAQ v2 and Meeting Notes Summarizer look risky by name/location but have least-privilege,
  single-source grounding and no actions. Correctly cleared.

**Expected count:** 10 agents, 4 environments; 3 agents flagged Orphaned or Unknown / ambiguous owner
(Onboarding Guide, Policy Lookup Bot, Sales Nudge); 3 agents flagged Shared connection (Claims Copilot on
DV-Claims-Shared, Sales Nudge on DV-CRM-Shared, Onboarding Guide on SP-Onboarding and
O365-Outlook-Onboarding).
