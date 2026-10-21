# ADR-0024: Attendee accounts are Power Platform Administrators, excluded from admin MFA

**Status:** Accepted
**Applies to:** `setup/RUNBOOK.md` → Phase 8b, `setup/scripts/07_provision_lab_users.ps1`,
`CA-Require-MFA-Admins` ([ADR-0010](0010-ca-baseline-replaces-security-defaults.md))

## Context

Lab 01-01 has attendees enumerate an environment's connections. Only the tenant-admin Power Platform
endpoints under `/scopes/admin/` return another person's connections, and only a Power Platform
Administrator reaches them. Both weaker options were tested on `0zwdt94t`, 2026-10-13, and both fail:

| Option | Result |
|---|---|
| `Global Reader` + unlicensed | Signs in, reads Entra, but **404 `CRMRequestFailed`** on `/scopes/admin/environments` where a tenant admin gets `200` |
| A per-environment role | The maker-facing connections API is **caller-scoped**: `marcus.webb`, owning 1 of Halcourt-Prod's 2 connections, saw exactly 1; `priya.nair` and `dev.kim`, both members, saw 0 |

No environment-level role makes a user see another person's connections, because the API never returns
them. The `404` matters too: the tenant-admin endpoints **hide themselves from an unauthorized caller**
rather than returning `403`, so an attendee sees "not found" and concludes the estate is empty.

Power Platform Administrator sits in `CA-Require-MFA-Admins`, and an account holding it can't sign in with a
handed-out password (`AADSTS50079`).

## Decision

Attendee accounts hold Power Platform Administrator. One group per delivery, `Lab-Students-<estate>`, is
added to `CA-Require-MFA-Admins`' `excludeGroups`. The write is safe to automate because it is:

- **Additive both ways.** The policy is read, one field changes, the whole `conditions` object goes back.
  Another estate's exclusion is never touched, and `-Destroy` drops only this estate's group id.
- **Verified after the write.** The script re-reads the policy and warns if the admin-role count moved —
  this policy keeps MFA on the tenant's real admins.
- **No extra sign-in.** az's delegated `Directory.AccessAsUser.All` covers Conditional Access for a Global
  Administrator (verified `GET` 200, `PATCH` 204), so Phase 8b stays non-interactive.

## Consequences

- **An attendee account is a tenant-wide Power Platform admin exempt from admin MFA.** It can change or
  delete any environment in the tenant, including another facilitator's estate, and it makes Lab 00-01's "a
  security reviewer observes; they do not change the estate" untrue of the account itself. Give a delivery
  its own tenant where you can. Only ever appropriate in an isolated, disposable training tenant.
- Re-running `00_conditional_access_baseline.ps1` never clears the exclusions; recreating the policy does —
  re-run Phase 8b then.

## Alternatives considered

- **`Global Reader` in the PPAC portal.** Not testable from the CLI: whether PPAC's portal shows an
  environment's connections to a `Global Reader`. Worth five minutes before the next delivery — if it does,
  the step could go portal-first and the account back to read-only.
