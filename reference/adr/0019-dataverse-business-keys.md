# ADR-0019: Dataverse tables keep business keys in `…number` columns

**Status:** Accepted
**Applies to:** `setup/scripts/04_provision_dataverse.ps1`, `setup/data/`

## Context

A Dataverse table's primary key is always `<table>id`, so the canon's business keys (`mm_customerid`,
`mm_claimid` in the seed CSVs) can't be the primary key.

## Decision

The business keys live in `mm_customernumber` and `mm_claimnumber`; the seed CSVs' `mm_customerid` /
`mm_claimid` columns map onto them.

## Consequences

- Live records carry a Dataverse GUID primary key alongside the canon's key.
