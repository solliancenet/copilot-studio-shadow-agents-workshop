# RUNBOOK.md — Facilitator provisioning

> **FACILITATOR-ONLY. Not published** (the whole `setup/` folder is excluded in `_config.yml`).
> Provisions the intentionally-vulnerable **Halcourt Mutual** demo estate. Everything here is keyed to the
> canon in [`../AGENTS.md`](../AGENTS.md) — that file is the source of truth; this file is how you build it.
>
> **This file is the instructions.** The reasoning lives in
> [`../reference/adr/`](../reference/adr/README.md) (decision records: why it is built this way,
> tradeoffs, alternatives) and [`../reference/runbook-errata.md`](../reference/runbook-errata.md)
> (what goes wrong, troubleshooting, open `[verify]` risks). Each phase links to its own section there.

Attendees share one live estate for Exercise 04 and 05; Exercise 05 is demonstrated by the facilitator.
The artifact pack is the offline fallback. Why:
[ADR-0002](../reference/adr/0002-shared-vs-individual-estates.md).

{: .important }
> The estate is deliberately broken. Provision it in an **isolated training tenant** you control. Never
> point these scripts at a production tenant.

## Before you start

You run this runbook from VS Code, inside the repo's **dev container** — a Linux container that has every
tool the scripts need already installed.

1. Install [VS Code](https://code.visualstudio.com/), its
   [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
   and [Docker Desktop](https://www.docker.com/products/docker-desktop/). Start Docker Desktop.
2. Clone this repo and open its folder in VS Code.
3. Open the Command Palette (**⇧⌘P** on a Mac, **Ctrl+Shift+P** on Windows) and run
   **Dev Containers: Reopen in Container**. The first build takes about 15 minutes; later opens take
   seconds. The bottom-left corner of the window shows **Dev Container** when it is done.
4. Open a terminal: **Terminal → New Terminal**. Run every command in this runbook in that terminal unless
   a step says otherwise, and sign in to `az` and `pac` only from it — a sign-in made outside the container
   isn't seen by the scripts ([ADR-0003](../reference/adr/0003-project-local-sign-in.md)).
5. Make sure you hold **Contributor** on the lab subscription. Phase 3 may create the shared billing plan
   and Phase 4c the Graph billing resource, both Azure resources. The **owner of the shared Azure
   deployment** (Phase 1) needs **Owner** (or Contributor + User Access Administrator): the deployment
   creates role assignments, which Contributor alone can't.

**The admin portals.** This runbook names each portal in full; "PPAC" is the Power Platform admin center.

| Portal | Address |
|---|---|
| Microsoft 365 admin center | https://admin.microsoft.com |
| Microsoft Entra admin center | https://entra.microsoft.com |
| Power Platform admin center (PPAC) | https://admin.powerplatform.microsoft.com |
| Azure portal | https://portal.azure.com |

The container's tools and what each phase uses them for: [toolchain](../reference/toolchain.md). Want a
real Windows desktop browser for interactive sign-in and MFA? See
[`windows-vm/README.md`](windows-vm/README.md) — optional.


## Phase order (do NOT reorder)

```
0. Provision isolated tenant   → fresh *.onmicrosoft.com, licensing, security defaults → CA baseline
0b. Choose your estate id      → once per build, in a tenant that already exists
1. Azure infra (Bicep)        → Policy API + Underwriting MCP endpoints
2. Entra identities/personas  → users, groups (tom.dean: leave date in 6.5, stays enabled)
3. Environments + DLP          → 4 environments, prod DLP, PAYG billing plan
4. SharePoint seed             → HR-Benefits + Claims-Knowledge, PLANT the poisoned doc
4b. Maker OneDrive             → provision + seed dev.kim's OneDrive (Meeting Notes grounding)
4c. Purview                    → Confidential-PII label + labelled comp copy (05-06); DAYS before delivery
5. Dataverse seed              → Claim + Customer tables, PII rows, the over-broad role
6. Author the agents           → as each owner, from the committed workspaces
7. Export the artifact pack    → regenerate ../worksheets/artifact-pack/*.csv
8. Validate                    → every planted problem reproduces; verdicts hold
8b. Lab (attendee) accounts    → per delivery: N native accounts to hand out, removed again afterwards
8c. Per-student slices         → an environment each, BEFORE Exercise 03: attendees open the svc-claims role
                                 there as System Administrator (03-02/03-04)
9. Teardown / reseed
```

---

### Phase 0 — Provision the isolated training tenant

Once per lab tenant. Mostly a portal flow. **Building in a tenant someone else already set up?** Skip to
[Phase 0b](#phase-0b--choose-your-estate-id); you need its global admin sign-in.

{: .important }
> This tenant **must not** be linked to any production or corporate tenant. Sign up with a **personal or
> lab-dedicated admin credential — never corporate SSO**.

1. **Sign up for a new M365 tenant.** Skip if the tenant already exists.
   - Create an **Azure billing account** first. Signup uses it for a one-time verification and doesn't
     charge it. It can take hours to appear.
   - Go to the **Microsoft 365 Developer Program**: https://developer.microsoft.com/microsoft-365/dev-program
   - Join with a **personal or lab email**, never your corporate account.
   - Choose **Instant sandbox (Add-on purchases enabled)** — a 90-day renewable E5 sandbox.
   - Pick the **data-center region**. You can't change it later.
   - Accept whatever **domain** signup assigns (e.g. `0zwdt94t.onmicrosoft.com`). The scripts use it as is.
   - **Install the content pack** if signup offers it. Its ~16 sample users take E5 seats — you free them
     in step 3.
   - Trouble with the variant, a billing account that doesn't show up, or no Developer Program:
     [errata → Phase 0](../reference/runbook-errata.md).

2. **Complete initial tenant setup.**
   - Create the **global administrator**. Record its UPN — you sign in as it throughout.
   - Existing tenant: any account that holds **Global Administrator** will do. "The global admin" in this
     runbook means whichever account you use.
   - Confirm **MFA is registered** on it: **Microsoft Entra admin center** → **Users** → the admin user → **Authentication
     methods**.
   - Record the **data-center region**: **Microsoft 365 admin center** → **Settings → Org settings → Organization profile →
     Data location**. Phase 1 uses it as `AZURE_LOCATION`.
   - Confirm the admin can open **Power Platform, Entra, SharePoint, Purview, Conditional Access and
     Defender**. Global Administrator covers all of them in a fresh tenant.

3. **Assign licensing.**
   - **Free the content pack's seats.** **Microsoft 365 admin center** → **Billing → Licenses** → the E5 developer
     licence → select the sample users → **Unassign licenses**. Leave the users themselves.
   - In a new tenant that is everyone except the global admin. In a tenant where estates are already built,
     **don't** unassign estate accounts — they carry an estate id (`marcus.webb.jsmith@…`,
     `student01.jsmith@…`).
   - The personas (Phase 2) and attendees (Phase 8b) need those seats.
   - **Microsoft 365 admin center** → **Billing → Licenses** → assign an **E5** seat to the global admin.
   - E5 comes with the sandbox and covers the Purview features the labs use.
   - The personas get their seats in Phase 2.

4. **Replace security defaults with the Conditional Access baseline.** Once per tenant.
   - Run it in the dev container terminal. It prints a web address and a code; open the address, enter the
     code, and sign in as the global admin. Safe to re-run: in a tenant that already has the baseline it
     changes nothing and prints the policies' state.

     ```bash
     pwsh setup/scripts/00_conditional_access_baseline.ps1 -TenantId <tenant domain> -UseDeviceCode
     ```

   - Sign-in refused with **AADSTS530035**? Security defaults are still on (a new tenant) and block
     device-code sign-in. Run it instead in a terminal on your own machine, from your clone of the repo,
     without `-UseDeviceCode`. That needs PowerShell 7 and `pwsh -c "Install-Module Microsoft.Graph -Scope
     CurrentUser"`. A browser tab opens; pick the global admin **within two minutes**.
   - First run only: it asks for `Policy.ReadWrite.ConditionalAccess` and `Policy.Read.All`. Tick
     **Consent on behalf of your organization**.
   - It turns security defaults off and creates two policies:

     | Policy | Applies to | Control |
     |---|---|---|
     | `CA-Require-MFA-Admins` | 15 admin roles — Microsoft's *Require MFA for admins* template set, plus Power Platform Administrator | Require MFA |
     | `CA-Block-Legacy-Auth` | All users | Block Exchange ActiveSync and other legacy clients |

   - If a policy fails, it rolls back and turns security defaults back on. Safe to re-run.
   - **Wait ~10 minutes** before the first device-code sign-in. Sign-ins take a while to stop seeing
     security defaults.
   - Why the swap is mandatory and what it gives up:
     [ADR-0010](../reference/adr/0010-ca-baseline-replaces-security-defaults.md).

5. **Consent to the Graph scopes.** Once, for the whole organization, as the global admin.
   - Run it in the dev container terminal. Safe to re-run: scopes already granted are skipped, and only
     missing ones are asked for.

     ```bash
     pwsh -c "Connect-MgGraph -TenantId <tenant domain> -UseDeviceCode -Scopes Policy.ReadWrite.ConditionalAccess,Policy.Read.All,User.ReadWrite.All,Group.ReadWrite.All,User.Read.All,Application.Read.All,AuditLog.Read.All"
     ```

   - It prints a web address and a code; open the address, enter the code, and sign in as the global admin.
   - If a consent screen appears, tick **Consent on behalf of your organization**, then **Accept**. No
     screen means everything was already granted.
   - Check it: **Entra admin center → Enterprise applications → Microsoft Graph Command Line Tools →
     Permissions**.
   - What each scope is for:

     | Scope | Used by |
     |---|---|
     | `Policy.ReadWrite.ConditionalAccess`, `Policy.Read.All` | `00_conditional_access_baseline.ps1` (step 4) |
     | `User.ReadWrite.All`, `Group.ReadWrite.All` | `01_provision_entra.ps1` (Phase 2), `99_teardown.ps1` |
     | `User.Read.All`, `Application.Read.All` | `05_export_artifact_pack.ps1` (Phase 7) |
     | `AuditLog.Read.All` | `05_…` — its users export reads `signInActivity` |

   - `pac` needs nothing granted. PnP.PowerShell gets its own app registration in Phase 4.

6. **Verify Phase 0.**
   - [ ] The global admin can sign in to https://admin.microsoft.com with MFA.
   - [ ] **Security defaults are off**, and both baseline policies are **On**.
   - [ ] The admin account has an **E5** licence assigned.
   - [ ] You hold **Contributor** on the lab subscription; the shared Azure deployment's owner holds
     **Owner** (or Contributor + User Access Administrator) - see step 5 of the dev container setup.
   - [ ] The tools are signed in to the lab tenant. In the dev container terminal:

     ```bash
     az login --allow-no-subscriptions --use-device-code   # sign in as the lab global admin
     az account show                                       # confirm the lab tenant id
     pac auth create --name halcourt-lab --deviceCode      # Power Platform CLI → lab tenant
     pac org list                                          # "Connected as <admin>"; a new tenant lists only the default env
     ```

   - Device-code sign-in fails with *AADSTS530035*? Step 4 hasn't taken effect yet. Wait, or sign in with a
     browser from your own machine or the Windows VM: drop `--use-device-code` / `--deviceCode` /
     `-UseDeviceCode`.

### Phase 0b — Choose your estate id

Once per build. Several people can build Halcourt Mutual in the same tenant; each build is an **estate**,
and every name it creates carries its estate id. With the id `jsmith`, `Claims-Test` becomes
`Claims-Test-jsmith` and Marcus becomes `marcus.webb.jsmith@<tenant domain>`. What an estate is and what
stays shared: [ADR-0001](../reference/adr/0001-estates.md).

1. Pick an estate id: your alias, 2–12 lowercase letters or digits.
2. Sign in to the tenant as its global admin. If you just finished Phase 0 you already are — skip to 2b to
   confirm it.

   a. In the dev container terminal, run:

      ```bash
      az login --use-device-code --allow-no-subscriptions
      ```

      It prints a web address and a code. Open the address in your browser, enter the code, and sign in
      with the tenant's global admin account.

   b. Confirm you are in the right tenant:

      ```bash
      az account show --query user.name -o tsv
      ```

      It prints the account you signed in as (`you@<something>.onmicrosoft.com`). The part after the `@`
      must be the training tenant's domain, not your company's.

3. Check nobody in the tenant uses your id. This lists every estate's Ana Reyes account; yours must not be
   there:

   ```bash
   az ad user list --filter "startswith(userPrincipalName,'ana.reyes.')" --query "[].userPrincipalName" -o tsv
   ```

4. Set the id in the terminal. Every script reads it; do this again in each new terminal:

   ```bash
   export HALCOURT_ESTATE=jsmith         # your id
   ```

5. Give attendees the estate id along with the tenant domain.

### Phase 1 — Azure infrastructure (shared)

The agents call two intentionally weak Container Apps — the internal **Policy API** and the
**Underwriting MCP** server (static-secret auth, over-scoped surface; see `setup/infra/policy-api/` and
`setup/infra/mcp-underwriting/`). **One deployment serves every estate**
([ADR-0005](../reference/adr/0005-shared-azure-deployment.md)): the apps hold no estate state, no exercise
changes them, and they take static secrets rather than Entra, so they work from any estate in any tenant.

**Building an estate:** get `setup/lab-endpoints.local.json` from the deployment's owner and save it at
that path (gitignored). It holds the four values Phase 6 puts into the agents — `POLICY_API_FQDN`,
`POLICY_API_KEY`, `UNDERWRITING_MCP_FQDN`, `MCP_BEARER`. Then check it — every line must say `ok`:

```bash
F=setup/lab-endpoints.local.json
bash setup/infra/smoke-test.sh "$(jq -r .POLICY_API_FQDN $F)" "$(jq -r .POLICY_API_KEY $F)" \
  "$(jq -r .UNDERWRITING_MCP_FQDN $F)" "$(jq -r .MCP_BEARER $F)"
```

The preflight (`00b_preflight.ps1`, *Training endpoints*) runs the same check again before a delivery.

Don't run `azd up` for your estate, and don't change the secrets: every estate's agents carry them.

#### Once per lab: the owner deploys it

One named facilitator owns the deployment. Only the owner redeploys or tears it down, and the secrets stay
fixed for its life — **a redeploy with new secrets, or a teardown, breaks every estate's agents** until
each re-runs Phase 6. The deployment also brings the demo web app and Foundry; the agents don't use them.

```bash
azd auth login --use-device-code  # skip if `azd config get auth.useAzCliAuth` says true — az login covers it

az group list --subscription <lab-subscription-id> --query "[?starts_with(name, 'rg-halcourt')].name" -o tsv   # names already used
ENV_NAME=halcourt-shared-lab      # a name nobody has used in this subscription
azd env new "$ENV_NAME" --subscription <lab-subscription-id> --location eastus2   # RG: rg-$ENV_NAME
azd env set POLICY_API_KEY "lab-$(openssl rand -hex 8)"   # any lab-only string
azd env set MCP_BEARER   "lab-$(openssl rand -hex 8)"     # any lab-only string
azd up                            # provisions + builds/pushes all images + deploys
pwsh -c '. setup/scripts/_lab_endpoints.ps1; Save-LabEndpoints'   # writes setup/lab-endpoints.local.json
```

- **Hand `setup/lab-endpoints.local.json` to each facilitator out of band** (it holds two lab secrets;
  never commit it). Phase 6 and the preflight read it, falling back to the selected azd environment — so
  the owner's own builds work either way.
- **Use an environment name nobody has used in this subscription.** Reusing a live name redeploys that
  deployment and replaces its secrets; reusing a *torn-down* name hits the Foundry soft-delete trap. Add a
  suffix (`-2`, a date) when you rebuild.
- Pass `--subscription` and `--location` explicitly — azd's global defaults can point outside the lab
  tenant. `eastus2` is tested; any region with gpt-5-mini (GlobalStandard) quota works.
- The Policy API key is the one that ends up hard-coded in Policy Lookup Bot (Scenario E). Despite the
  `_FQDN` names, both addresses are full URLs.

Name derivation and the FQDN shape:
[ADR-0012](../reference/adr/0012-azd-environment-per-estate.md) and
[azure-endpoints.md](../reference/azure-endpoints.md). `azd up` failures and Foundry
soft-delete: [errata → Phase 1](../reference/runbook-errata.md).

### Phase 2 — Entra identities & personas

1. **Create and license the estate's people and groups.** The script creates nine accounts (eight
   personas and `svc-claims`), the `it.helpdesk` shared mailbox and four groups, each named with your
   estate id ([ADR-0006](../reference/adr/0006-personas-on-the-tenant-domain.md),
   [ADR-0007](../reference/adr/0007-shared-mailbox-via-exchange.md)). Then it gives an E5 licence to the
   eight accounts that need one ([ADR-0009](../reference/adr/0009-eight-licences-per-estate.md)). Safe to
   re-run. In the dev container terminal:

   ```bash
   pwsh setup/scripts/01_provision_entra.ps1 -TenantId <tenant domain>
   ```

   - It reuses your `az` sign-in, so there's no code to enter.
   - Its first lines show the estate and domain (`Estate: jsmith   Persona domain: <tenant domain>`).
     Check both.
   - It ends with `Phase 2 complete for estate '<id>'`.

2. **Check the licences.** The `Licences:` lines must show all eight accounts `Assigned` or `Licensed`.
   A `Not licensed:` warning means the tenant ran out of seats: free some (Phase 0, step 3) and re-run.

3. **Leave Tom Dean enabled**, always. Phase 6.5 marks him departed
   ([ADR-0008](../reference/adr/0008-departed-owner-stays-enabled.md)).

### Phase 3 — Environments and DLP

1. **Create the estate's environments and Prod's data policy.** The script creates three environments
   with Dataverse — `Halcourt-Prod-<estate>` (Production, Managed Environment), `Claims-Test-<estate>`
   (Sandbox) and `Maker-Sandbox-<estate>` (Developer, for `dev.kim.<estate>`) — and the DLP policy
   `Halcourt-Prod-DLP-<estate>`, on Prod only. It waits for each Dataverse org (a few minutes), then prints
   a summary. Safe to re-run. In the dev container terminal:

   ```bash
   pwsh setup/scripts/02_provision_environments_dlp.ps1
   ```

   - It reuses your `az` sign-in, so there's no code to enter.
   - The summary lists each environment's **Region**. All three must match; note it for step 2.
   - It ends with `Phase 3 complete`.
   - The platform picks the region ([ADR-0013](../reference/adr/0013-environment-region-assigned.md)). The other
     environments get no DLP and no agent Conditional Access is created — on purpose
     ([ADR-0028](../reference/adr/0028-planted-governance-gaps.md)).

2. **Link Prod and Claims-Test to a pay-as-you-go billing plan.** Without one, agents publish but nobody
   can chat with them. The script finds the plan in your environments' region with the Copilot Studio
   meter on, creating one if the region has none, then links both environments and checks the link.
   Estates share a plan per region ([ADR-0014](../reference/adr/0014-shared-billing-plan-per-region.md)). Safe to
   re-run.

   ```bash
   pwsh setup/scripts/02b_provision_billing.ps1
   ```

   - Creating a new plan is untested (`[verify]`); reusing one is the normal path.
   - By hand instead: [billing-plan-by-hand.md](../reference/billing-plan-by-hand.md). Trouble with the
     region lock: [errata → Phase 3](../reference/runbook-errata.md).

### Phase 4 — SharePoint seed (plant the poisoned doc)

1. **Check the PnP app exists.** SharePoint needs its own app registration, `Halcourt PnP`, shared by every
   estate in the tenant ([ADR-0016](../reference/adr/0016-pnp-app-registration.md)). This prints its app
   id, or nothing:

   ```bash
   az ad app list --display-name "Halcourt PnP" --query "[0].appId" -o tsv
   ```

   - Nothing printed: register it once for the tenant —
     [pnp-app-setup.md](../reference/pnp-app-setup.md) — then continue.

2. **Add your own certificate to the app.** It lets the seed run without a sign-in. Once per facilitator;
   the files stay in the repo's gitignored `setup/` folder. Pick a password and keep it:

   ```bash
   export ENTRAID_APP_ID=$(az ad app list --display-name "Halcourt PnP" --query "[0].appId" -o tsv)
   openssl req -x509 -newkey rsa:2048 -keyout setup/pnp.local.key -out setup/pnp.local.cer -days 90 -nodes -subj "/CN=HalcourtPnP"
   openssl pkcs12 -export -out setup/pnp.local.pfx -inkey setup/pnp.local.key -in setup/pnp.local.cer -passout pass:<cert-pw>
   az ad app credential reset --id $ENTRAID_APP_ID --cert @setup/pnp.local.cer --append -o none
   ```

   - The certificate lasts 90 days; repeat this step when it expires.

3. **Seed the SharePoint sites.** The script creates two private team sites, `HR-Benefits-<estate>` and
   `Claims-Knowledge-<estate>`, uploads their files — including the poisoned `Open-Enrollment-FAQ.docx`
   with its hidden instructions — and sets who can read what, which Scenarios A and B depend on. It ends
   by reading everything back. Safe to re-run. Details:
   [sharepoint-seed.md](../reference/sharepoint-seed.md).

   ```bash
   export HALCOURT_PNP_CERT_PFX=setup/pnp.local.pfx HALCOURT_PNP_CERT_PW=<cert-pw>
   pwsh setup/scripts/03_provision_sharepoint.ps1 -RootSiteUrl https://<tenant>.sharepoint.com
   ```

   - New sites can take up to 15 minutes each to appear in a fresh tenant.
   - The read-back must show `Leadership/` readable by `HR-Team-<estate>` and not by
     `All-Employees-<estate>`.
   - Times out waiting for a site? A soft-deleted site from an earlier run may hold the URL — purge it with
     `Remove-PnPTenantDeletedSite` ([errata → Phase 4](../reference/runbook-errata.md)).
   - No certificate? Unset the two variables and it signs in with a device code instead.

### Phase 4b — Provision and seed the maker OneDrive

1. **Create Dev Kim's OneDrive and put his meeting notes in it.** The Meeting Notes Summarizer decoy
   (Phase 6) grounds on those notes. The script signs in as Dev to make SharePoint create his OneDrive,
   waits for it, then uploads `Dev-Kim-Meeting-Notes.docx` with your PnP certificate. If the OneDrive
   already exists it just uploads. It uses the same variables as Phase 4 step 3:

   ```bash
   export ENTRAID_APP_ID=$(az ad app list --display-name "Halcourt PnP" --query "[0].appId" -o tsv)
   export HALCOURT_PNP_CERT_PFX=setup/pnp.local.pfx HALCOURT_PNP_CERT_PW=<cert-pw>
   pwsh setup/scripts/03b_provision_onedrive.ps1
   ```

   - It ends by printing Dev's OneDrive address
     (`https://<tenant>-my.sharepoint.com/personal/dev_kim_<estate>_…/Documents`).
   - Creating the OneDrive is best effort
     ([ADR-0017](../reference/adr/0017-maker-provisions-own-onedrive.md)). If it fails, go to step 2.

2. **Only if step 1 failed: create the OneDrive by hand, then re-run step 1.** This asks SharePoint for it
   as the admin; it prints a code to enter, like the other sign-ins:

   ```bash
   pwsh -NoProfile -Command "Connect-PnPOnline -Url https://<tenant>-admin.sharepoint.com -DeviceLogin -ClientId $ENTRAID_APP_ID; Request-PnPPersonalSite -UserEmails dev.kim.<estate>@<tenant domain>"
   ```

### Phase 4c — Purview: the label and the labelled comp copy (Task 05-06)

1. **Create the sensitivity label and label a copy of the comp workbook.** Do this **days before the
   delivery**: the label reaches SharePoint late, and search must index the copy before 05-06 can be
   retested. The script creates the group `HR-Leadership-<estate>` (Marcus), the encrypting label
   `Confidential-PII-<estate>` and its policy, then copies `Leadership/2026-comp-bands.xlsx` to
   `2026-comp-bands-labeled.xlsx` and labels the copy; the original stays unlabelled. The first run in a
   tenant also creates the app it signs in as ([ADR-0029](../reference/adr/0029-purview-app-only-identity.md)).
   Safe to re-run.

   ```bash
   pwsh setup/scripts/03c_provision_purview.ps1
   ```

2. **Re-run until the copy is labelled.** It ends with checks; repeat step 1 until they show
   `copy labelled: True` and `original unlabelled: True`. Expect a few re-runs while the
   new group and label replicate ([errata → Phase 4c](../reference/runbook-errata.md#phase-4c--purview-the-label-arrives-late-and-the-token-is-app-only-2026-10-18)).

### Phase 5 — Dataverse seed

1. **Create the claims data and give `svc-claims` too much access to it.** In `Claims-Test-<estate>`, the
   script creates a Customer table (with SSNs and dates of birth) and a Claim table, seeds five rows each,
   and assigns `svc-claims.<estate>` an over-broad role: full access to every row. Scenarios C and D
   exploit that role; Task 05-03 narrows it. It ends by reading everything back. Safe to re-run.
   Details: [dataverse-seed.md](../reference/dataverse-seed.md).

   ```bash
   pwsh setup/scripts/04_provision_dataverse.ps1
   ```

   - It reuses your `az` sign-in and finds `Claims-Test-<estate>` itself.
   - The role assignment must read as done. **PENDING** means `svc-claims.<estate>` has no licence
     ([ADR-0018](../reference/adr/0018-svc-claims-licensed-e5.md)): re-run Phase 2 step 1, which licenses
     it, then re-run this step.

### Phase 5b — Auditing (Lab 05-07)

1. **Turn on the auditing 05-07 reads.** Run it **at least an hour before Exercise 04** — on the build day:
   a log only holds what happened after it was switched on. The script turns on Purview Audit, auditing for
   `Claims-Test-<estate>`, and change auditing for the Claim table
   ([ADR-0030](../reference/adr/0030-audit-claim-changes-only.md)). Safe to re-run.

   ```bash
   pwsh setup/scripts/04b_provision_audit.ps1
   ```

   - It ends with a `Check` line: `unified audit ingestion`, `environment audit` and `mm_claim` must be
     `True`, and `mm_customer` must be `False` — Customer stays unaudited on purpose.
   - Purview Audit can take up to 60 minutes to start recording.
   - Defender real-time protection for agents isn't set up — the tenant lacks its licence
     ([ADR-0031](../reference/adr/0031-no-defender-realtime-protection.md)).

### Phase 6 — Author the agents

1. **Check the default environment has Dataverse.** Once per tenant: Expense Helper and Onboarding Guide
   live in `Halcourt (default)` and can't be built without it. This prints its Dataverse address, or nothing:

   ```bash
   az rest --method GET --resource https://service.powerapps.com/ \
     --url "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments/Default-$(az account show --query tenantId -o tsv)?api-version=2021-04-01" \
     --query properties.linkedEnvironmentMetadata.instanceUrl -o tsv
   ```

   - Nothing printed: add it (a few minutes), then continue:

     ```bash
     az rest --method POST --resource https://service.powerapps.com/ \
       --url "https://api.bap.microsoft.com/providers/Microsoft.BusinessAppPlatform/environments/Default-$(az account show --query tenantId -o tsv)/provisionInstance?api-version=2018-01-01" \
       --body '{"baseLanguage":1033,"currency":{"code":"USD"},"templates":[]}'
     ```

2. **Preview the build.** The engine reports what it would do — owners, roles, connections, flows and
   agents — and changes nothing:

   ```bash
   pwsh setup/scripts/06_provision_agents.ps1 -VerifyOnly
   ```

3. **Build the agents.** The engine builds all ten agents as their owners: it turns on `it.helpdesk`'s
   sign-in, adds each owner to its environment with a maker role, creates and consents each connection
   (headless, as its owner), creates the flows, then pushes and publishes each committed agent. Safe to
   re-run. What it builds: [agents-build.md](../reference/agents-build.md).

   ```bash
   pwsh setup/scripts/06_provision_agents.ps1
   ```

   - It needs Phases 2–5 done, Prod and Claims-Test linked to a billing plan (Phase 3), and Dev's OneDrive
     seeded (Phase 4b).
   - Rebuild one agent: `-Agents <slug>` (slugs in `setup/agents/manifest.json`).
   - A transient *instanceNotFound* while adding a user: run it again.

### Phase 6.5 — Mark Tom Dean departed

1. **Record Tom's departure without disabling him.** After Onboarding Guide and Sales Nudge exist and run on
   his connections, this sets his Entra leave date and leaves the account enabled
   ([ADR-0008](../reference/adr/0008-departed-owner-stays-enabled.md)):

   ```bash
   pwsh setup/scripts/01_provision_entra.ps1 -MarkDepartedOwner
   ```

   - **Never disable Tom**: both connections go to Error within the hour and Scenario F stops reproducing.

### Phase 7 — Export the artifact pack

```powershell
pwsh setup/scripts/05_export_artifact_pack.ps1 -Canonicalize    # estate from HALCOURT_ESTATE (or -Estate <id>)
git diff worksheets/artifact-pack
```

Pulls **this estate** — its environments, its agents and connections in the shared default environment,
and its accounts (no admins, no sample users) — from the PPAC admin APIs + Microsoft Graph, and writes the
five estate CSVs, plus `files-export.csv` for 05-06 (the knowledge sites' files and their sensitivity labels).
That one reads SharePoint with the lab app Phase 4c creates, so run Phase 4c first. `-Canonicalize` maps live names back to the canon's so the export lands on the committed pack
and `git diff` shows the drift. Without it the script refuses to write into the committed pack; pass
`-OutDir` for a live-named export.

**One prerequisite: the admin needs a security role in every Dataverse environment**, because the agent
inventory reads each environment's `bot` table. Environments the admin created in Phase 3 already have it;
a **Developer** environment does not:

```bash
pac admin assign-user --environment <environment-id> --user <admin UPN> --role "System Administrator"
```

{: .important }
> **The committed pack is not a pure export, so do not expect an empty `git diff`.** Three columns are
> hand-written canon that no API returns: agent `description`, the friendly connector names, and the rows
> for things that aren't Power Platform connections at all. Read the diff as *drift to review*, not as a
> test that should come out empty —
> [ADR-0023](../reference/adr/0023-committed-pack-not-pure-export.md).

### Phase 8 — Validate

Walk `AGENTS.md` and confirm, in the live tenant:

- Every **PLANTED PROBLEM** reproduces (A–F fire; discovery targets are findable).
- Every **CONTROL EFFICACY** verdict holds; resolve any `[verify]` items and update `AGENTS.md`.
- A student account (Phase 8b) signs in, sees its slice (Phase 8c), opens each Teams install link, and
  Claims Copilot returns CLM-9002 to it while the account's own Claims-Test roles grant no claim access —
  the confused-deputy path, with the attendee as the requester.
- **Phase 6.5 has run** — Tom has a leave date and is still **enabled**, and both of his connections
  show `Connected`; otherwise the departed-owner thread reads wrong and `users-export` disagrees with the canon.
- **The agent registry shows the estate (05-05).** All ten estate agents appear in Microsoft 365 admin
  center → Agents, and **Block** is available on Onboarding Guide there - as the facilitator account with AI
  Administrator activated, the way 05-05 is demonstrated. If you try it, Unblock straight away. Whether the
  tenant's Agent 365 licensing holds for the delivery is an open question:
  [PLANNING item 8](../PLANNING.md).
- Re-run Phase 7 and **review** `git diff worksheets/artifact-pack`. It will not be empty; look for
  *unexpected* drift — an agent missing, an owner that changed, a connection that lost its sharing, an
  environment that lost its DLP.

What the export confirms on its own, without driving an agent: every published agent is present with the
right owner and environment; each has exactly one Entra identity; DLP is attached to Prod and nowhere
else; and the accounts are as Phase 2 left them. Reproducing Scenarios A–F still means talking to the
agents.

### Phase 8b — Lab (attendee) accounts

Per *delivery*, not per estate: attendees sign in to the lab tenant with a native account you hand out, so
they review the estate from inside the tenant rather than as guests. Run it shortly before the delivery and
tear it down after.

First count your free E5 seats (**Microsoft 365 admin center** → **Billing → Licenses**). That number is the most
attendees you can run: use it for `-Count` and `-Attendees`
([ADR-0004](../reference/adr/0004-one-licence-per-attendee.md)).

```bash
# N = your free E5 seats (ADR-0004) - 14 here
pwsh setup/scripts/00b_preflight.ps1 -Attendees 14                           # the day before: seats, service plans, endpoints, the access model
pwsh setup/scripts/07_provision_lab_users.ps1 -Count 14                      # student01.<estate> .. student14.<estate>
pwsh setup/scripts/07_provision_lab_users.ps1 -Count 14 -UniquePasswords     # a distinct password each
pwsh setup/scripts/07_provision_lab_users.ps1 -Destroy                       # delete AND purge, after the delivery
pwsh setup/scripts/07c_provision_purview_roles.ps1                           # attendees -> DSPM transcript role; one admin device-code approval
```

Accounts are estate-scoped (`student01.<estate>@<domain>`), so two facilitators can run deliveries in one
tenant. The run prints a handout table and writes `setup/lab-users-<estate>.local.csv` — **plaintext
passwords, gitignored; delete it afterwards**. Re-running is safe: existing accounts are left alone and their passwords are carried forward from the
previous handout (the script cannot read one back from Entra).

It also consents **Graph Explorer** tenant-wide for a few read scopes (`User.Read.All`, `AuditLog.Read.All`,
`Application.Read.All`, `AgentIdentity.Read.All`; the list is `$GraphExplorerScopes` in `_access_model.ps1`).
01-02, 02-01 and 06-01 send attendees there, and each of those reads is admin-consent-only: without the grant
the query answers `Authorization_RequestDenied`. The grant is shared by every estate, so `-Destroy` leaves it.

**Attendees get four Entra directory roles (`$DirectoryRoles` in `_access_model.ps1`), and enrol MFA at
first sign-in:**

| Role | Serves |
|---|---|
| `Power Platform Administrator` | the `/scopes/admin/` connection reads (Task 01-01) |
| `AI Reader` | Microsoft 365 admin center → Agents (Agent 365): 01-01 KT01 s3, 02-01 KT01 s1, 04-06 KT01 s1, 05-05 KT01. Without it the Agents page is missing from the nav |
| `Security Reader` | Entra Conditional Access policies (05-04 KT01) and the Defender portal's Alerts, Incidents and AI agents (05-07) |
| `Global Reader` | Purview Information Protection and DSPM for AI (05-06, 05-07) |

Only Power Platform Administrator can write. Task 01-01 has attendees enumerate an environment's
connections, and only the tenant-admin endpoints under `/scopes/admin/` can do that. Nothing weaker
reaches them - verified live 2026-10-13:

| Weaker option | Result |
|---|---|
| `Global Reader` | **404 `CRMRequestFailed`** where a tenant admin gets `200`. The endpoint hides itself from an unauthorized caller rather than returning `403`, so the attendee sees an empty estate, not an error. |
| A per-environment role | No help. The maker-facing connections API is caller-scoped: a maker owning 1 of an environment's 2 connections sees exactly that one; members owning none see zero. |

**Tell attendees to bring an authenticator app.** Holding a tenant admin role means Entra asks each of
them to register MFA on their first sign-in. That is the point, not a snag: it is what gives them the
Entra, Microsoft 365 and Exchange admin centers the labs use. It costs about two minutes each, once.

> {: .important }
> **Do not try to avoid this with a Conditional Access exclusion.** An earlier design excluded these
> accounts from `CA-Require-MFA-Admins` so a handed-out password alone would work. It buys **PPAC and
> nothing else**: Entra, Microsoft 365 and Exchange admin centers enforce MFA for admin portals through
> *Microsoft's* policy, which tenant Conditional Access cannot exclude. Verified by signing a lab account
> into each - all three answer *"Let's keep your account secure"*, with no skip offered. Enrolling is
> strictly better: every portal comes back, and `CA-Require-MFA-Admins` is left intact.
>
> `-ExcludeFromAdminMfa` restores the old behaviour for a delivery that genuinely cannot use authenticator
> apps - and as of 2026-10-17 it buys **the PPAC shell and nothing more**: every data call then fails with
> *"Sign in required - AADSTS50076: you must use multi-factor authentication"* (the Power Platform API), and
> Copilot Studio fails the same way. Microsoft requires MFA for the admin APIs as well as the portals, and
> tenant Conditional Access cannot exclude it. Treat the switch as inoperative; attendees enrol.

> {: .caution }
> **An attendee account is a tenant-wide Power Platform admin.** It can change or delete any environment in
> the tenant, including another facilitator's estate. Give a delivery its own tenant where you can, and run
> `-Destroy` the moment it ends.

**Attendees also get Dataverse access inside each estate environment, defined by an access model.**
Power Platform Administrator is a **tenant** role and grants nothing inside a Dataverse environment, and
most of the day's tasks read something that lives there: a security role's scope (03-02, 03-04), an
agent's Knowledge, Topics, Tools and Connection Settings in Copilot Studio (01-01, 01-02, 02-01..03, all of
Exercise 04). So the script assigns two roles in each of the estate's three Dataverse environments:

- **`Lab Reviewer (read-only)`**, a custom role it creates and **reconciles on every run to exactly the
  privileges listed in `setup/scripts/_access_model.ps1`** - every one of them `prvRead*`, every one tied to
  the exercise step that needs it. Anything on the role that the model does not list is removed (Dataverse's
  own unremovable baseline is recognised and reported, not treated as drift). `-KeepExtraPrivileges` reports
  instead of removing.
- **`Bot Viewer`**, Microsoft's built-in role, assigned alongside. The two are needed together: Copilot
  Studio needs bot reads at *Global* depth (the agents belong to the personas, not the attendee), which the
  custom role carries, **and** reads of connection references, AI plugins, workflows and solutions at the
  depths Copilot Studio expects, which `Bot Viewer` carries. Either alone fails - verified one at a time.

Never System Administrator, which would hand every attendee write access to the estate they are reviewing.
The reviewer stance - observe the shared estate, change nothing - holds; attendees change only their own
slice (Phase 8c), where they *are* System Administrator. `-NoDataverseRole` skips all of it.

Extend the model from an exercise's requirement, never from a failing probe. Three exercises in a row (03-02,
03-04, Exercise 04) had their live path blocked because the role had been sized for 01-02 and grown
reactively; the preflight now fails before a delivery if an environment's role has drifted from the model.

Two things that bite here, both verified:

- **Create the accounts well before the delivery.** Group membership takes time to reach Conditional
  Access. An account minutes old can fail its first sign-in with `AADSTS50079` on Dataverse-backed pages,
  then work fine later.
- **A re-run carries passwords forward, but cannot invent one.** An account that already exists is left
  alone and its password is read back from the previous handout. If that file is gone, the row says so -
  reset the password or destroy and recreate rather than guessing.


**Exercise 04 chat needs a seat, and each agent needs its Teams channel added.** Attendees drive Benefits
Buddy, Claims Copilot and Expense Helper with their own account, and send Policy Lookup Bot one benign
lookup (04-05 KT02 s2). The agents authenticate with Microsoft,
so the only channel is **Microsoft 365 and Microsoft Teams** (the *Make agent available in Microsoft 365
Copilot* option is greyed out on this tenant) - and Teams refuses an unlicensed account outright (*"You
don't have the required permissions to access this org"*, verified 2026-10-17). Phase 6 adds that channel
for every agent marked `teamsChannel` in the manifest and reads each agent's **install link** (Channels →
*Microsoft 365 and Microsoft Teams* → **Availability options** → **Copy link**) into
`setup/teams-links-<estate>.local.csv`. Those are the links Exercise 04 says the facilitator hands out. They
work for users the agent is shared with, which 07 arranges by adding attendees to `All-Employees-<estate>`;
the attendee sees an **Add** dialog, then the chat. A plain chat link (`/l/chat/0/0?users=28:<app id>`) is
refused: *"You do not have permission to use this app here"* (verified as student03, 2026-10-19).

**Each attendee needs a licence** ([ADR-0004](../reference/adr/0004-one-licence-per-attendee.md); [PLANNING item
15](../PLANNING.md)): Exercise 04's Teams chat, 05-07's `CopilotInteraction` events and the access model all
depend on one. Verified 2026-10-17 with three accounts holding the identical access model: the one with an E5
seat (`accessmode=0`) opened the PPAC role editor and the Copilot Studio agent pages; the two without
(`accessmode=1`, Administrative) got *"You don't have permission to view these items."* Administrative access
mode **filters** a custom role's privileges. What survives filtering is System Administrator - so an
unlicensed attendee can do those steps only in **their own slice** (Phase 8c), never in the shared estate.
Without seats, the steps that read a role or an agent's configuration in the shared estate fall back to the
artifact pack: the Copilot Studio parts of 01-01 KT02 s6, 01-02, 01-03, 02-01..03, 03-01, 03-02 KT02 s2 and
03-04; Exercise 04's configuration reads (04-01..06) and 04-03 KT02 s2's role editor in Claims-Test; and 05-01
KT02 s2, 05-03 KT01 s1, 05-04 KT06 s2. The role editor in 03-02 and 03-04 already routes to the slice. Entra
reads, PPAC lists and the admin APIs work either way.

The script attempts assignment, never fatally, and the end-of-run table reports who got one - so an attendee
without a seat is a delivery decision you make, not a surprise: they take the artifact-pack route for those
tasks. **Licence attendees the day before**: Dataverse keeps its own copy of licence state and re-reads it
hours later, in both directions - an account licensed that morning still reports unlicensed, and one created
unlicensed reports *licensed* for about an hour, so a rehearsal can pass and the delivery fail. The
preflight checks `accessmode` per attendee. The build tenant's 25 E5 seats were held by estate personas,
admins and 14 unused Microsoft sample users; the sample users' seats were released
(`setup/licence-restore-2026-10-14.local.json` is the undo), so up to 14 attendees can be licensed - size
the delivery to that.
`FLOW_FREE` does nothing for Dataverse.

Why this role and not something weaker:
[ADR-0024](../reference/adr/0024-attendees-are-power-platform-admins.md); licences, teardown and the access model:
[ADR-0025](../reference/adr/0025-attendee-licences-best-effort.md), [ADR-0026](../reference/adr/0026-attendee-teardown-purges.md),
[ADR-0027](../reference/adr/0027-attendee-dataverse-access-model.md).


**Attendees hold no Exercise 05 write role.** Exercise 05 is demonstrated: you apply each control to the
shared estate and restore it (below), and attendees retest. An older kit made attendees PIM-eligible for AI
Administrator and Security Administrator; 07 withdraws both on its next run (`$RetiredEligibleRoles`).
Why: Security Administrator,
[errata → Review fixes to this branch](../reference/runbook-errata.md#review-fixes-to-this-branch-2026-10-19);
AI Administrator,
[errata → Exercise 05 is demonstrated](../reference/runbook-errata.md#delivery--exercise-05-is-demonstrated-not-done-by-attendees-2026-10-19).

### Exercise 05 demonstrations (during delivery)

Attendees share one estate, so **you** apply each Exercise 05 control, once, live; the room retests; you put
the estate back. Demonstrate as the **facilitator account** (`facilitator.<estate>`, "Lab Facilitator
(<estate>)"), not your own tenant admin: it holds Power Platform Administrator, and AI Administrator only
as PIM-eligible - activate it for the step that needs it (05-05) and let it lapse. (Security Administrator
was eligible for 05-07's Defender step; that step is reasoned now, so 07b removes it.) Create it once, after the attendee accounts:

```powershell
pwsh setup/scripts/07b_provision_facilitator.ps1     # password -> setup/lab-facilitator-<estate>.local.csv
```

Sign in with it once before the delivery to enrol MFA (it is an admin, so `CA-Require-MFA-Admins` applies). Snapshot everything before the session, restore each control as soon as its retests are
done, and finish with a diff.

```powershell
pwsh setup/scripts/09_ex05_demo_state.ps1 -Action Snapshot -Control All     # before Exercise 05 starts
# ... demonstrate, let the room retest ...
pwsh setup/scripts/09_ex05_demo_state.ps1 -Action Restore -Control Dlp       # or DefaultMakers / ClaimsRoles
pwsh setup/scripts/09_ex05_demo_state.ps1 -Action Diff -Control All         # at the end: all "same as the snapshot"
```

| Task | You demonstrate | Back to the estate |
|---|---|---|
| 05-01 | Halcourt-Prod's data policy: HTTP and custom connectors to **Blocked** | `-Action Restore -Control Dlp` |
| 05-02 | default environment: a data policy named `Halcourt-Default-DLP-<estate>` that blocks **HTTP** and **custom connectors** (the 05-01 blocks). Nothing else: every licensed user is an Environment Maker there automatically, so swapping the role's members for `Halcourt-Makers-<estate>` restricts nobody - attendees record that as a finding | `-Action Restore -Control Dlp` (deletes the new policy - the estate id in its name is what allows that) |
| 05-03 | **Scenario B, the SharePoint-permission route (preferred):** remove the knowledge source's effective reader's permission on `Leadership/` - the route 05-03 KT01 s3 offers. Narrowing Benefits Buddy's Knowledge to the open-enrollment FAQ (as its owner, Marcus, then publish) did **not** stop the leak within an hour ([errata, 2026-10-20](../reference/runbook-errata.md#exercise-05-03--narrowing-benefits-buddys-grounding-did-not-stop-the-leak-within-an-hour-2026-10-20)); if you demonstrate that route anyway, warn the room to expect DENTS IT. **Scenarios C/D:** a scoped role and fixed subset for svc-claims: `pwsh setup/scripts/09b_ex05_scoped_claims_role.ps1` | permission: restore it by hand; knowledge (if narrowed): `06 -Agents benefits-buddy` (the committed workspace is the whole site); the role, Basic User and record owners: `-Action Restore -Control ClaimsRoles` |
| 05-04 | nothing - the CA policy is specified, never created (one wrong policy locks out the tenant) | - |
| 05-05 | Agent 365 registry: **Block** Onboarding Guide (never Delete) | **by hand**: Unblock |
| 05-06 | nothing changes - **show** `HR-Benefits` → `Leadership/` as Marcus (HR leadership): select each comp file → **Details** - the labelled copy shows **Sensitivity** `Confidential-PII-<estate>`, the original none (the library view has no Sensitivity column); attendees can't open the folder | - |
| 05-07 | nothing - real-time protection is **reasoned** (KT06): it needs a Microsoft Agent 365 licence, which the lab tenant lacks | - |

The default environment and the tenant's Defender setting are shared with every estate in the tenant:
coordinate with any other facilitator delivering at the same time.

### Phase 8c — Per-student slices (needed from Exercise 03)

Slices exist so attendees can open the `svc-claims` role as **System Administrator** in 03-02 and 03-04:
the PPAC role editor opens for a System Administrator whatever their licence, and for a reviewer holding
the custom role only if they have a seat (see Phase 8b). Exercise 05 is demonstrated on the shared estate
(above), so attendees apply no control in their slice.

**Build the slices before the delivery starts** — Exercise 03 is the first to need them. Exercise 00
introduces the slice by name (`Lab-<estate>-NN`), so the number on each attendee's handout must match the
slice built for them: `studentNN` gets `Lab-<estate>-NN`.

```bash
pwsh setup/scripts/07_provision_lab_users.ps1 -Count 14        # accounts first - one per licensable seat
pwsh setup/scripts/08_provision_student_slices.ps1 -Count 14   # then a slice each - the same N
pwsh setup/scripts/08_provision_student_slices.ps1 -Destroy    # after the delivery
```

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

### Before delivery — preflight, audit and Exercise 04 notes

**The day before the delivery, run the preflight.** It checks the tenant capabilities in
[tenant capabilities](../reference/tenant-capabilities.md), the estate and the attendee access model, and
names the exercise steps each failed check would break.

1. In the dev container terminal, sign in as the tenant's global admin and set your estate id, as in
   [Phase 0b](#phase-0b--choose-your-estate-id) steps 2 and 4.
2. Run it with the attendee count — no more attendees than you have Microsoft 365 seats to give them
   (count your free E5 seats; [ADR-0004](../reference/adr/0004-one-licence-per-attendee.md)):

   ```bash
   pwsh setup/scripts/00b_preflight.ps1 -Attendees 14     # one per seat available: up to 14 in the build tenant
   ```

3. Fix every FAIL before the delivery. A WARN names the fallback attendees will use.

Manual, not scripted. **Do these before Exercise 04 runs**: 05-07 reconstructs Exercise 04 from the logs,
and nothing recorded before auditing was on can be found afterwards ([PLANNING item 16](../PLANNING.md)).

- [ ] **Dataverse auditing in `Claims-Test-<estate>`** - Phase 5b's `04b_provision_audit.ps1` turns it on
      for the environment and the `Claim` table - **not** `Customer`, whose changes would carry SSN and date
      of birth into records attendees can read (by hand: PPAC → the environment → **Settings** → **Audit and
      logs** → **Audit settings**, then the table's properties). This records **changes** (create, update,
      delete, sharing), which is what the 05-03 demonstration makes.
- [ ] **Attendees can search Purview Audit** (05-07 KT01, KT02, KT05). Global Reader is enough once
      ingestion is on: as an attendee, run a search covering the Exercise 04 rehearsal, filtered to record
      type `CopilotInteraction`. Verified 2026-10-21 as student03 (jobs finish in 4-7 minutes).
- [ ] **No setting makes Claims Copilot's reads visible in `Claims-Test`.** Dataverse auditing never logs a
      read, so the Audit summary view shows none. Reads are logged only by activity logging (the **Read
      logs** setting plus the table's single- and multiple-record settings), and those events reach Purview
      only for production environments. `Claims-Test` is a sandbox. Don't try to work around it: 05-07 KT03
      now teaches that gap instead of relying on a read event.
- [ ] **Purview Audit is on** - also Phase 5b. It is **not** always on by default: on this developer tenant
      unified audit ingestion was off (2026-10-20), and only activity after it is switched on (allow up to an
      hour) is ever searchable. Check: Purview portal → **Audit** shows no "start recording" banner.
- [ ] **Defender real-time protection for agents** is not used: 05-07 KT06 reasons it through. Since July
      2026 it needs a Microsoft Agent 365 licence. Purchase services offered no self-service trial on the
      build tenant (an admin-led trial needs Microsoft or the account team).
- [ ] **The DSPM transcript role** - `pwsh setup/scripts/07c_provision_purview_roles.ps1` (Phase 8b). 05-07 KT04
      reads the chat's **interaction record** in **DSPM for AI → Activity explorer** (user, agent, time,
      resources); the prompt and response text is optional. Global Reader shows the record; the text needs
      Purview's **Data Security AI Content Viewers**, which 07c gives each lab account (`student<NN>.<estate>`).
      Role-group membership needs Organization Management, which the lab app can't hold, so 07c asks for
      **one device-code approval** from a Global Administrator. `-Remove` after the delivery.
      **Check it as an attendee:** after the Exercise 04 rehearsal chat, open the interaction in Activity
      explorer. The record (user, agent, resources) must show; that is what KT04 needs. Note whether
      **Interaction details** shows text or *"We couldn't retrieve this prompt and response"* - in the build
      tenant it never showed text, even with the role in place for hours ([errata → Phase 8b](../reference/runbook-errata.md)),
      so tell the room the transcript is optional and expect it to be unavailable.
      Microsoft retires *DSPM for AI (classic)* on 30 November 2026; check the step's wording against the
      portal before a later delivery.
- [ ] **Attendees read audit records, not claims.** 05-07 KT03 sends each attendee to `Claims-Test`'s **Audit
      summary view** to see that it shows no read. Phase 8b's lab role carries `prvReadRecordAuditHistory`,
      `prvReadAuditSummary` and `prvReadQuery` for that (`_access_model.ps1`); it still has no read on claims,
      so the attendee can't open the claim itself - Scenario D depends on that.

**04-04 has no test claim.** Claims Copilot's only tools are *List claims* and *List customers* - its
instructions mention status updates, but it has no update tool - so no test claim is designated. Tell the
room the write half of Scenario D is reasoned, not exercised.

### Phase 9 — Teardown / reseed

`99_teardown.ps1` removes ONE estate and nothing another estate owns, in dependency order: the shared
default environment's agents + the auto-approve flow (as their owners) → the SharePoint sites (purged from
the recycle bin so the URLs are reusable) → the three estate environments (their Dataverse, agents and
connections go with them) → the DLP policy → billing unlink.

```bash
export ENTRAID_APP_ID=<PnP app id>  HALCOURT_PNP_CERT_PFX=setup/pnp.local.pfx  HALCOURT_PNP_CERT_PW=<cert-pw>   # for site removal
pwsh setup/scripts/99_teardown.ps1                                  # estate artifacts; KEEPS personas + shared infra
pwsh setup/scripts/99_teardown.ps1 -RemovePersonas                  # also the Phase 2 personas + *-<estate> groups
pwsh setup/scripts/99_teardown.ps1 -RemovePersonas -RemoveShared    # also the shared authors group + PnP app registration
```

Environments delete asynchronously (a few minutes). It KEEPS Phase 0 (tenant, CA baseline, security
defaults) and the shared **default environment** and its Dataverse — that can't be un-provisioned. It
also keeps the **shared Azure deployment** (Phase 1): it is every estate's, not this one's. To reseed,
re-run Phases 2–6 with the same `setup/lab-endpoints.local.json`.

**Shared Azure deployment — owner only, after the last estate.** Tearing it down breaks every estate's
agents, so do it only when no estate still needs it:

```bash
azd env select <shared env name>   # from the repo root
azd down --purge --force
rm setup/lab-endpoints.local.json  # and ask facilitators to delete their copies
```

If it has to be rebuilt while estates still use it, use a **new** azd environment name, write the new
values file (`Save-LabEndpoints -Force`: it refuses to replace different values otherwise), hand it out, and
have every estate re-run Phase 6: the agents' `${…}` action tokens
re-inject the new addresses and secrets at provision time.

**What `99_teardown.ps1` does not remove.** Run these by hand after the delivery:

- [ ] **Per-student slices** (Phase 8c): `pwsh setup/scripts/08_provision_student_slices.ps1 -Destroy`
      (`-Force` skips the prompt). **Run it before `99_teardown.ps1`**: it finds the billing policy to unlink
      through the estate's Prod environment, and once Prod is gone it warns and skips the unlink unless you
      pass `-BillingPolicyId`.
- [ ] **The attendees' Purview role** (Phase 8b): `pwsh setup/scripts/07c_provision_purview_roles.ps1 -Remove`
      (one admin device-code approval). Run it before `07 -Destroy`, while the lab accounts still exist:
      07c matches role-group members by display name, so a member left behind would be taken for a rebuilt
      account of the same name. The role is tenant-wide - it shows every Copilot interaction in the tenant,
      every estate's - so don't leave it in place between deliveries.
- [ ] **Shared grants 07 and 04b leave in place** (tenant-wide, shared by every estate - remove only when
      no estate needs them): Graph Explorer's all-users consent (`$GraphExplorerScopes`) -
      `az rest --method DELETE --url https://graph.microsoft.com/v1.0/oauth2PermissionGrants/<id>` (find the
      id with `oauth2PermissionGrants?$filter=clientId eq '<Graph Explorer service principal id>'`); and unified
      audit ingestion, which is best left on.
- [ ] **Lab accounts** (Phase 8b): `pwsh setup/scripts/07_provision_lab_users.ps1 -Destroy` (`-Force` skips
      the prompt), then delete `setup/lab-users-<estate>.local.csv`.
- [ ] **The facilitator account**: `pwsh setup/scripts/07b_provision_facilitator.ps1 -Destroy` (it also
      deletes `setup/lab-facilitator-<estate>.local.csv`).
- [ ] **Phase 4c's Purview artifacts.** The label policy `Halcourt-Labels-<estate>` and the sensitivity label
      `Confidential-PII-<estate>` (delete the policy first; Purview portal → Information Protection), and the
      group `HR-Leadership-<estate>`. The labelled copy goes with the `HR-Benefits-<estate>` site.
- [ ] **Shared per-tenant, only when the last estate in the tenant goes:** the app registration
      `halcourt-lab-compliance` (03c, 07 and 07b sign in with it) with its local
      `setup/lab-compliance-app.local.{json,pfx}`, and the resource group `rg-halcourt-graph-billing` holding
      its Graph billing resource `halcourt-lab-compliance-billing`. `azd down` does not touch either.

`-RemovePersonas` deletes every user whose UPN ends `.<estate>@<domain>` and every group named `*-<estate>`,
so it also catches the lab accounts, the facilitator and `HR-Leadership-<estate>`. Run the scripts above
anyway: they are the intended path, and 07 `-Destroy` purges what it deletes.

## File index (this kit)

| Path | Purpose |
|---|---|
| `infra/` (root azd project) | Deploys web + Foundry + Policy API + Underwriting MCP Container Apps via `azd up` |
| `setup/infra/policy-api/` | Minimal, intentionally over-scoped Policy API (static key) |
| `setup/infra/mcp-underwriting/` | Minimal Underwriting MCP server (static bearer, `run_query`) |
| `setup/infra/smoke-test.sh` | Phase 1 check: both endpoints reject a bad credential and serve the scenario behaviour with the right one |
| `windows-vm/` | Optional Windows 11 build VM in Docker, for a desktop browser for interactive sign-in and MFA |
| `screenshot-capture-list.md` | Screenshots the lab pages reference, to capture from the demo tenant |
| `scripts/00_conditional_access_baseline.ps1` | Security defaults off → `CA-Require-MFA-Admins` + `CA-Block-Legacy-Auth` |
| `scripts/00b_preflight.ps1` | The day before a delivery: tenant capabilities, seats, endpoints, the estate and the access model |
| `scripts/_estate.ps1` | Estate naming rule, dot-sourced by the scripts |
| `scripts/_access_model.ps1` | The attendee access model: directory roles, groups, every Dataverse privilege and the step it serves |
| `scripts/_auth.ps1` | Graph sign-in reuse: the az token when it covers the scopes, else device code |
| `scripts/_labapp.ps1` | The kit's app-only identity (`halcourt-lab-compliance`), for 03c and 07 |
| `scripts/01_provision_entra.ps1` | Personas, groups, `svc-claims`, shared mailbox |
| `scripts/02_provision_environments_dlp.ps1` | Environments, Managed Prod, prod DLP |
| `scripts/02b_provision_billing.ps1` | Copilot Studio PAYG billing plan; links Prod + Claims-Test |
| `scripts/03_provision_sharepoint.ps1` | Sites + clean FAQ library + **plant poisoned doc** |
| `scripts/03b_provision_onedrive.ps1` | Provision + seed dev.kim's OneDrive (Meeting Notes grounding) |
| `scripts/04_provision_dataverse.ps1` | Claim/Customer tables, PII rows, over-broad role |
| `scripts/04b_provision_audit.ps1` | Phase 5b: Purview Audit and Claims-Test auditing for 05-07 |
| `scripts/05_export_artifact_pack.ps1` | Regenerate the artifact-pack CSVs |
| `scripts/06_provision_agents.ps1` | Provision the agents from committed workspaces, as each owner |
| `scripts/lib/consent_browser.py` | Headless connection-consent helper (browser step in Phase 6) |
| `scripts/lib/enable_teams_channel.py` | Adds the Teams channel to an agent as its owner (browser step in Phase 6) |
| `scripts/03c_provision_purview.ps1` | Phase 4c: the encrypting label and the labelled comp copy |
| `scripts/07_provision_lab_users.ps1` | Phase 8b: attendee accounts and the access model (`_access_model.ps1`) |
| `scripts/07b_provision_facilitator.ps1` | The facilitator's Exercise 05 demonstration account |
| `scripts/07c_provision_purview_roles.ps1` | Phase 8b: attendees into Purview's Data Security AI Content Viewers (05-07 KT04); one admin device-code approval |
| `scripts/08_provision_student_slices.ps1` | Phase 8c: an environment per attendee, with the Claims Dataverse seed |
| `scripts/09b_ex05_scoped_claims_role.ps1` | Exercise 05-03 demonstration: svc-claims' scoped role and fixed subset |
| `scripts/09_ex05_demo_state.ps1` | Exercise 05 demonstrations: snapshot / diff / restore the shared estate |
| `scripts/99_teardown.ps1` | Remove the estate |
| `agents/manifest.json` | Phase 6 control data: agents, connections and flows (estate-agnostic) |
| `agents/<slug>/` | Committed `pac copilot` agent workspaces the engine replays |
| `agent-authoring-guide.md` | Manual Copilot Studio authoring, per agent (portal / `pac`) |
| `data/` | Seed data: poisoned-doc source, clean decoy FAQ, Dev's meeting notes, Expense Helper flow |

{: .warning }
> Several script steps depend on 2026 product surfaces still settling (Conditional Access for agents, `pac`
> agent commands). Lines marked `# [verify]` need confirmation against the delivery-date tenant; treat
> them as the intended operation, not a guaranteed cmdlet.

## More detail

| File | Holds |
|---|---|
| [`../reference/adr/`](../reference/adr/README.md) | Decision records: why it is built this way, the tradeoffs, the alternatives |
| [`../reference/runbook-errata.md`](../reference/runbook-errata.md) | Errata, known issues, troubleshooting, open `[verify]` risks |
| [`../reference/copilot-studio-billing.md`](../reference/copilot-studio-billing.md) | Copilot Studio billing/licensing models and their workshop implications |
