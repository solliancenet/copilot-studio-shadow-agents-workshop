# What the Dataverse seed creates

What `04_provision_dataverse.ps1` builds in `Claims-Test-<estate>` (RUNBOOK → Phase 5): the `mm` publisher,
two tables seeded from `setup/data/`, and the over-broad role Scenarios C and D exploit. Why the keys are
`…number` columns: [ADR-0019](adr/0019-dataverse-business-keys.md).

| Table | Columns | Rows |
|---|---|---|
| `mm_customer` | `mm_name` (primary), `mm_customernumber`, `mm_ssn`, `mm_dob` — **PII** | `customers.csv` (5) |
| `mm_claim` | `mm_claimnumber` (primary), `mm_status`, `mm_amount`, `mm_adjuster`, `mm_customer` (lookup) | `claims.csv` (5) |

`svc-claims Dataverse Full Access` holds create / read / write / append / append-to / assign / share on **both
tables at Global depth** — every row, PII included, nothing narrowing record-level access — and is assigned to
`svc-claims.<estate>`. Least privilege here is what Task 05-03 will *close*. It reads the rows, privileges and
assignment back at the end. Safe to re-run.
