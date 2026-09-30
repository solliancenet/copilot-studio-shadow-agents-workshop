# Screenshot capture list

> **FACILITATOR-ONLY.** Screenshots the lab pages reference. Capture each from the provisioned
> Halcourt Mutual demo tenant and save to `media/<filename>`. Naming: `exNN_tMM_ktKK_sSS.png`
> (exercise, task, key-task, step). Redact any real values that are not part of the canon.

Total: 13 screenshots.

| File (`media/`) | Referenced by | What to capture (alt text) |
|---|---|---|
| `ex00_t01_kt01_s01.png` | `docs/00_lab_environment/00_01.md` | Power Platform admin center showing the Halcourt Mutual environments list in read-only view |
| `ex01_t01_kt01_s01.png` | `docs/01_the_agent_estate/01_01.md` | Screenshot of agents-export.csv open in a spreadsheet, one row per agent |
| `ex02_t01_kt01_s01.png` | `docs/02_discover_and_inventory/02_01.md` | Power Platform admin center Inventory page listing Copilot Studio agents across environments |
| `ex02_t02_kt01_s01.png` | `docs/02_discover_and_inventory/02_02.md` | The five artifact-pack exports joined on agent name, owner UPN, and environment |
| `ex03_t01_kt02_s01.png` | `docs/03_identity_and_effective_access/03_01.md` | Connection detail in the Power Platform admin center showing owner and authentication type |
| `ex03_t04_kt03_s01.png` | `docs/03_identity_and_effective_access/03_04.md` | A completed Agent Access Map block with the seven layer rows filled and the gap classified |
| `ex04_t01_kt01_s01.png` | `docs/04_break_the_agents/04_01.md` | Benefits Buddy grounding configuration showing the whole HR-Benefits SharePoint site in scope, including a Leadership subfolder |
| `ex04_t03_kt02_s01.png` | `docs/04_break_the_agents/04_03.md` | Underwriting Assistant's topics, each calling one Underwriting MCP tool: get_quote, get_risk_score, and a broad run_query (the calls are topic nodes, not tools — capture the Topics list, bearer value redacted if shown) |
| `ex04_t05_kt02_s01.png` | `docs/04_break_the_agents/04_05.md` | Policy Lookup Bot's topic with the HTTP request node, the API key value redacted (the request is a node in the *Look up policy* topic, not a tool) |
| `ex05_t03_kt01_s01.png` | `docs/05_test_the_controls/05_03.md` | Dataverse custom security role scoped to user-level read on Claim and Customer, with organization-wide privileges removed |
| `ex05_t06_kt01_s01.png` | `docs/05_test_the_controls/05_06.md` | Applying the Confidential-PII sensitivity label to 2026-comp-bands.xlsx in the HR-Benefits site |
| `ex06_t02_kt03_s01.png` | `docs/06_security_baseline/06_02.md` | Where to read connection owners in the Power Platform admin center — the owner column that inventories built from the agent list alone never surface. |
| `ex06_t04_kt01_s01.png` | `docs/06_security_baseline/06_04.md` | The DLP policy view in the Power Platform admin center — confirm the environment an agent lives in is actually covered, not just named "prod". |
