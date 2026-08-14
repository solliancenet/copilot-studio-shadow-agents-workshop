# Agent Estate Inventory — ANSWER KEY

> **FACILITATOR-ONLY. Do not publish.** Excluded via `worksheets/answer-keys/` and `**/*.answers.md`.
> Derived from `AGENTS.md`. Use to check attendee inventories.

## Completed flags

| Agent | Env | Owner (status) | Orphan | Shadow | Test→Prod | Shared conn | Unknown owner | Forgotten |
|---|---|---|:--:|:--:|:--:|:--:|:--:|:--:|
| Benefits Buddy | Prod | marcus.webb (ok) | | | | | | |
| Claims Copilot | Claims-Test | priya.nair (ok) | | | ✅ | ✅ (svc-claims) | | |
| Policy Lookup Bot | Prod | it.helpdesk (shared mbx) | | | | | ✅ | |
| Underwriting Assistant | Prod | priya.nair (ok) | | | | | | |
| Expense Helper | Default | sam.olsen (ok) | | | | | | |
| Onboarding Guide | Default | **tom.dean (DISABLED)** | ✅ | | | ✅ (tom.dean) | ✅ | ✅ |
| Team Wiki | Sandbox | dev.kim (ok) | | ✅ | | | | ✅ |
| Sales Nudge | Prod | lena.ford (ok) | | | | ✅ (tom.dean CRM) | ✅ (conn≠agent owner) | |
| HR FAQ v2 (copy) | Prod | marcus.webb (ok) | | | | | | (decoy — clean) |
| Meeting Notes Summarizer | Sandbox | dev.kim (ok) | | | | | | (decoy — clean) |

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
- **Team Wiki:** `Maker-Sandbox`, personal env, not in any sanctioned list — pure shadow.
- **Decoys:** HR FAQ v2 and Meeting Notes Summarizer look risky by name/location but have least-privilege,
  single-source grounding and no actions. Correctly cleared.

**Expected count:** 10 agents, 4 environments; 2 disabled/ambiguous owners (tom.dean, it.helpdesk);
3 shared/service-account connections (DV-Claims-Shared, DV-CRM-Shared, SP/O365-Onboarding).
