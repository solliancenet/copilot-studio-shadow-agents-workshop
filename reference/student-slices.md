# Per-student slices (Phase 8c): why and how

Reference for [RUNBOOK → Phase 8c](../setup/RUNBOOK.md#phase-8c--per-student-slices-needed-from-exercise-03).

Slices exist so attendees can open the `svc-claims` role as **System Administrator** in 03-01 and 03-02:
the PPAC role editor opens for a System Administrator whatever their licence, and for a reviewer holding
the custom role only if they have a seat (RUNBOOK Phase 8b). Exercise 05 is demonstrated on the shared estate
(RUNBOOK → During delivery), so attendees apply no control in their slice.

**Why this is affordable.** Dataverse security roles and record-level access are **per environment**, so the
one shared `svc-claims` can hold the over-broad role in one attendee's environment and a scoped role in
another's at the same time. The slices need **no new licences** — which matters, because a sandbox tenant has 25 E5 seats and the
estate itself holds eight, and that is what rules out giving each attendee a whole estate.

Each slice is one Sandbox environment with Dataverse, linked to the estate's PAYG billing policy, holding
the Phase 5 seed (Claim and Customer with PII rows, and the over-broad `svc-claims Dataverse Full Access`
role). The attendee is **System Administrator of their own slice only**. Verified 2026-10-13: an attendee
creating a scoped role gets `204` in their slice and `403` in the shared estate.

> {: .important }
> **Not needed while Exercise 05 is demonstrated.** A slice holds no SharePoint grounding site and no
> agents, including the orphaned-connection agent owned by the departed `tom.dean`. That only matters if
> attendees ever apply Exercise 05's controls themselves, in their own slice; it would then need a
> per-environment override in `03_provision_sharepoint.ps1` and `06_provision_agents.ps1`.

Two things learned building it, both verified: a new environment's Dataverse was **Ready in about 30
seconds**, far faster than Phase 3's wait suggests; and the first calls against a brand-new org can fail
with *"Interactive authentication is needed"* while `az` settles a token for the new resource — it clears
on its own, so the script retries rather than failing the slice.
