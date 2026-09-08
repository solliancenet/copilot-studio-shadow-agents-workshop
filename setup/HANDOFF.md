# Runbook Walkthrough — Handoff Notes

> **Date:** 2026-09-08
> **Tenant:** `0zwdt94t.onmicrosoft.com`
> **Tenant ID:** `7f97ff53-b3f5-4d3f-ba10-951a9543f344`
> **Data region:** USA
> **Global admin:** Jim Counts
> **Tenant creator:** Galen Keene (`Galen@solliance.net` — technical contact)

## Where we left off

**Phase 0, step 3 — Licensing.** Partway through.

### What's done

| Step | Status | Notes |
|---|---|---|
| Phase 0.1 — Tenant signup | ✅ Done (Galen) | Dev Program sandbox, add-on-purchases-enabled variant |
| Phase 0.2 — MFA | ✅ Done (Galen) | Enforced during tenant wizard |
| Phase 0.2 — Record region | ✅ USA | Confirmed via Settings → Org settings → Data location |
| Phase 0.2 — Admin roles | ✅ Global Admin | Jim Counts has all roles (can't self-edit — expected) |
| Phase 0.3 — M365 E5 | ✅ Present | "Microsoft 365 E5 Developer SKU V2" — 18/25 seats assigned |
| Phase 0.3 — Copilot Studio credits | ⏳ **Next** | Found the Trial SKU in Marketplace; not yet activated |
| Phase 0.3 — E5 assigned to admin | ✅ | Jim Counts has a seat |
| Phase 0.4 — Power Platform / PPAC | ❌ Not started | |
| Phase 0.5 — Verification checklist | ❌ Not started | |

### What to do next

1. **Activate the Copilot Studio Trial.** In the M365 admin center → **Marketplace** → search "Copilot" → click **Details** on **Microsoft Copilot Studio Trial** → complete the activation. Confirm it shows up in **Billing → Your products** afterward.

2. **Check the Dataverse capacity gate.** Open **PPAC** (https://admin.powerplatform.microsoft.com) → **Resources → Capacity**. Need **≥ 1 GB Dataverse database** before Phase 3. The E5 sandbox ships with 0 GB — if it's still 0, you need a paid capacity add-on (requires the Azure Plan).

3. **Continue Phase 0 steps 4–5** (enable Power Platform, run verification checklist), then Phase 1.

## Content-pack users decision

The tenant has ~16 Dev Program sample users (Adele Vance, Alex Wilber, Diego Siciliani, etc.) already licensed. **Decision made: reuse them** as Halcourt personas instead of creating new ones. Only add accounts the pack doesn't cover (`svc-claims`, `it.helpdesk` shared mailbox, etc.). This saves seats on the 25-license cap.

Phase 2 script will need a mapping of content-pack user → Halcourt persona.

## Domain note

The tenant domain is `0zwdt94t.onmicrosoft.com`, not the canonical `halcourtmutual`. Any script that expects the canonical domain needs `-DomainSuffix 0zwdt94t.onmicrosoft.com` (or equivalent parameter).

## Runbook edits applied (uncommitted)

Six edits to `setup/RUNBOOK.md` sitting in the working tree:

1. Phase 0 step 1 — content pack guidance softened from "do not install" to "fine to install, map to personas"
2. Phase 0 step 2 — MFA bullet softened ("wizard may have already required this")
3. Phase 0 step 2 — "confirm region" → "record region" (it's immutable, not confirmable)
4. Phase 0 step 3 — "Billing → Purchase services" → **Marketplace**; added Trial SKU note and nav instructions
5. Phase 2 — added content-pack user reuse decision point
6. Errata — content pack section: "do not install" → "preferred approach: map to personas"

Run `git diff setup/RUNBOOK.md` to see them.

## Open feedback (not yet applied)

None — all collected feedback was applied in the six edits above.
