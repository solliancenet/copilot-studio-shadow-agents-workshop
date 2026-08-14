<#
FACILITATOR-ONLY. Phase 5 — Dataverse seed.

Creates Claim and Customer tables in Claims-Test, seeds rows (Customer holds SSN/DOB), and grants
svc-claims the OVER-BROAD role (read/write all rows, no row-level security). The over-grant + missing RLS
are what Scenarios C and D exploit, and what Module 5 (least privilege) will actually CLOSE.

Requires: pac CLI (pac auth create / pac org select) or Microsoft.Xrm.Data.PowerShell.
Lines marked [verify] depend on tenant specifics.
#>
param(
  [Parameter(Mandatory=$true)][string]$ClaimsTestEnvUrl   # https://<org>.crm.dynamics.com
)
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $PSCommandPath
$dataDir = Join-Path (Split-Path -Parent $here) 'data'

Write-Host "Selecting Claims-Test org: $ClaimsTestEnvUrl"
# pac auth create --url $ClaimsTestEnvUrl   # [verify] auth as needed

# --- Tables ------------------------------------------------------------------
# [verify] Create tables via solution import (preferred) or pac. Intended shape:
#   Customer(mm_customerid, mm_name, mm_ssn, mm_dob)          <- PII
#   Claim(mm_claimid, mm_customer (lookup), mm_status, mm_amount, mm_adjuster (owner))
Write-Host 'Creating Customer and Claim tables (import solution or pac). Customer holds SSN/DOB (PII).'

# --- Seed rows ---------------------------------------------------------------
Write-Host "Seeding Customer rows from $dataDir/customers.csv and Claim rows from $dataDir/claims.csv"
# [verify] Import rows via pac data import (data map) or Set-XrmData; ensure claims are assigned to
# DIFFERENT adjusters so 'the requesting adjuster's own claims' is meaningful.

# --- The over-broad role -----------------------------------------------------
Write-Host 'Granting svc-claims an over-broad Dataverse role (read/write ALL Claim and Customer rows).'
Write-Host '[verify] Assign System Customizer (or a custom role with org-level read/write on Claim+Customer)'
Write-Host 'to svc-claims. Do NOT enable row-level security. Module 5 will replace this with a scoped role + RLS.'

Write-Host 'Phase 5 complete.'
