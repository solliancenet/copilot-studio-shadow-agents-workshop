# Halcourt Mutual Claims Triage Console

The internal, adjuster-facing **Claims Triage Console** for **Halcourt Mutual**, the fictional
insurer the workshop is built around. It is an ASP.NET Core MVC app on .NET 8 with EF Core over
SQLite. The home page is a **triage queue** of claims needing review; opening a claim shows the
claim and policy context and a **Generate triage briefing** action that calls the Foundry
**Claims-Triage** agent.

It still publishes the same **REST API** that an agent (or any other external caller) can call to
answer questions about a policy, premium standing, and claims — this is the surface the agent's
OpenAPI tool calls, so its routes and shapes are unchanged.

Auth to Foundry uses the app's **managed identity** via `DefaultAzureCredential` (no secrets); the
agent flow is configured with the Foundry project endpoint + agent name in `appsettings`/env.

> The published attendee site never renders this folder — `src/` is in the `exclude:` list in
> `_config.yml`.

## Technology stack

- .NET 8, ASP.NET Core MVC
- EF Core 8 with SQLite
- Swashbuckle (OpenAPI at `/swagger`)
- xUnit, with `WebApplicationFactory` for the API tests

## Running

```bash
cd src
dotnet run
```

The default launch profile listens on `https://localhost:7060` and `http://localhost:5256` and
opens `/swagger`. On start-up the app applies EF Core migrations and, if the database is empty,
loads the demonstration data set.

```bash
cd src
dotnet test
```

## Member API

No authentication — deliberately. The API is meant to be reachable by an external caller in the
lab, and it only ever serves fabricated data.

| Method | Route | Returns |
|---|---|---|
| GET | `/api/policyholders/{id}` | The member |
| GET | `/api/policies?policyholderId={id}` | Every policy the member holds |
| GET | `/api/policies/{policyNumber}` | One policy |
| GET | `/api/policies/{policyNumber}/premium-payments` | Premium payments, newest first |
| GET | `/api/claims?policyNumber={n}` | Claims filed against a policy |
| GET | `/api/claims/{claimNumber}` | One claim |
| POST | `/api/claims` | Files a claim; returns the new claim number |

`POST /api/claims` takes `{ "policyNumber": "...", "amount": 0.00, "description": "..." }` and
answers `201 Created` with the claim number, its status (`Open`), and the filing date.

```bash
curl http://localhost:5256/api/policies/MM-AUTO-004417

curl -X POST http://localhost:5256/api/claims \
  -H 'Content-Type: application/json' \
  -d '{"policyNumber":"MM-AUTO-004417","amount":1450.00,"description":"Hail damage to the roof panel and hood."}'
```

## Domain

- **Policyholder** — a member of the mutual.
- **Policy** — `Auto`, `Home` or `Life`; `Active` or `Lapsed`; carries the monthly premium,
  effective and renewal dates, and a plain-language coverage summary.
- **PremiumPayment** — a payment against a policy (`AutoPay`, `Card`, `Check`, `BankTransfer`;
  `Pending`, `Cleared`, `Returned`). This is what answers "did my premium clear?".
- **Claim** — `Open`, `UnderReview`, `Approved` or `Denied`, with an amount, filing date and
  description.

## Demonstration data

`Data/PolicySeeder.cs` seeds the primary demo member, Dana Whitfield, with two active policies —
auto `MM-AUTO-004417` and home `MM-HOME-002289` — four billing months of premium payments per
policy (including the current month), and one auto claim under review, `CLM-2026-00841` (still the
only claim on its policy, so "no prior claims"). To make the triage queue read like a real
worklist, two more policyholders (Marcus Reyes, Priya Nadella) carry three additional open /
under-review claims (`CLM-2026-00842`..`00844`) across their own policies. Dates are anchored to
today, so the seeded book never goes stale. The seed lives in `PolicySeeder` (run at startup), not
in a migration, so adding claims does not require a schema migration.

## Project structure

```
src/
├── Controllers/
│   ├── HomeController.cs                 # Triage queue (claims needing review)
│   ├── ClaimsController.cs               # Adjuster claim view + Generate triage briefing
│   ├── PoliciesController.cs             # Policy detail (premiums + claims)
│   └── Api/                              # The REST API
│       ├── PolicyholdersApiController.cs
│       ├── PoliciesApiController.cs
│       └── ClaimsApiController.cs
├── Data/
│   ├── HalcourtMutualDbContext.cs
│   ├── PolicySeeder.cs
│   └── Migrations/
├── Models/
│   ├── Policyholder.cs, Policy.cs, PremiumPayment.cs, Claim.cs
│   └── Api/ApiContracts.cs               # Request/response records
├── Services/
│   ├── PolicyService.cs, PremiumService.cs, ClaimService.cs
├── Views/
│   ├── Home/Index.cshtml, Policies/Details.cshtml, Shared/_Layout.cshtml
├── HalcourtMutual.Tests/                 # xUnit
└── wwwroot/                              # Bootstrap, jQuery (vendored)
```
