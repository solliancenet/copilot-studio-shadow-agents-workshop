# Creating or linking a billing plan by hand

The manual equivalent of `02b_provision_billing.ps1` ([RUNBOOK → Phase 3](../setup/RUNBOOK.md#phase-3--environments-and-dlp); why plans are shared: [ADR-0014](adr/0014-shared-billing-plan-per-region.md)).

The scripted path is `02b_provision_billing.ps1`. Two manual equivalents, for when you'd rather click or
when a region has no plan yet. Do either only **after** the environments exist, so the plan's region
matches theirs.

**In the Power Platform admin center (PPAC, https://admin.powerplatform.microsoft.com):**

1. **Read the region from the Phase 3 summary** (the `Region` column — e.g. `canada`), or in PPAC
   (https://admin.powerplatform.microsoft.com) → **Manage → Environments**.
2. **If the region already has a plan, link to it.** PPAC → **Licensing → Billing Plans**. A plan in the
   summary's region with the **Copilot Studio** meter on is the shared one, whatever its name (a Dev
   Program tenant may come with one, e.g. `ppccdevcanada`). Open it → **Edit** → on **Select
   environments**, **check** `Halcourt-Prod-<estate>` and `Claims-Test-<estate>` → **Save**. Done; skip
   step 3.
3. **Otherwise create the region's plan.** First make sure the shared resource group exists in the lab
   subscription — the script would have created it, but this path doesn't. Its location is only metadata
   and need not match the plan's region:

   ```bash
   az group show -n rg-halcourt-billing --subscription <lab-subscription-id> -o none 2>/dev/null ||
     az group create -n rg-halcourt-billing -l eastus --subscription <lab-subscription-id> -o none
   ```

   Then PPAC → **Licensing → Billing Plans → + New billing plan → Azure subscription**. Name it for the region, not your estate — `Halcourt-PAYG-<region>` (e.g.
   `Halcourt-PAYG-canada`) — because every estate in the region will share it. Pick the **Azure
   subscription** and the shared **resource group** `rg-halcourt-billing` → set the **Meter** to
   **Copilot Studio** (Dataverse is auto-included) → **Next**. On **Select environments**, set the
   **Region** filter to the summary's region, then **check** `Halcourt-Prod-<estate>` and
   `Claims-Test-<estate>` → **Save**.
4. **Mind the region-lock.** A plan only lists environments in its own region: if an environment isn't in
   the picker, the plan's region doesn't match it (see errata).

**By API, reusing a plan the region already has.** With `az` signed in as the admin:

```bash
# Plans and their regions; pick one in the region the Phase 3 summary reported (create one in PPAC if none).
az rest --method GET --resource https://api.powerplatform.com/ \
  --url 'https://api.powerplatform.com/licensing/billingPolicies?api-version=2022-03-01-preview' \
  --query "value[].{name:name, id:id, region:location, envs:environmentIds}" -o json
# Link this estate's Prod and Claims-Test (environment ids from the Phase 3 summary).
az rest --method POST --resource https://api.powerplatform.com/ \
  --url "https://api.powerplatform.com/licensing/billingPolicies/<policy-id>/environments/add?api-version=2022-03-01-preview" \
  --body '{"environmentIds":["<Halcourt-Prod-estate-id>","<Claims-Test-estate-id>"]}'
```

Re-run the GET to confirm both ids are listed, and check the plan has the **Copilot Studio** meter on (its
`payGoEntitlements` shows `MCSMessages` with `payAsYouGoState: true`). Note that the policy object's
`environmentIds` reads as null — the authoritative list is the `/environments` sub-resource the script
reads.
