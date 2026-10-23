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
5b. Auditing                   → Purview Audit + Claims-Test change auditing (05-07); before Exercise 04
6. Author the agents           → as each owner, from the committed workspaces
6c. Recheck the Purview label  → re-run 4c until the copy is labelled
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

The agents call two deliberately weak apps in Azure — the Policy API and the Underwriting MCP server. One
deployment serves every estate ([ADR-0005](../reference/adr/0005-shared-azure-deployment.md)), so building
an estate deploys nothing.

1. **Get the endpoints file from the deployment's owner.** It holds the two apps' addresses and secrets,
   which Phase 6 puts into the agents. Save it as `setup/lab-endpoints.local.json` (gitignored — never
   commit it).

   - No owner yet, or you are the owner: deploy it once for the lab —
     [azure-shared-deployment.md](../reference/azure-shared-deployment.md).

2. **Check both apps answer.** The smoke test calls each app with and without its secret. Every line must
   say `ok`:

   ```bash
   F=setup/lab-endpoints.local.json
   bash setup/infra/smoke-test.sh "$(jq -r .POLICY_API_FQDN $F)" "$(jq -r .POLICY_API_KEY $F)" \
     "$(jq -r .UNDERWRITING_MCP_FQDN $F)" "$(jq -r .MCP_BEARER $F)"
   ```

   - Don't run `azd up` for your estate, and don't change the secrets: every estate's agents carry them.

### Before Phase 2 — One estate or several?

- **One estate:** carry on with Phases 2 to 6.5 below, one at a time.
- **Several estates** (one per attendee): skip Phases 2 to 6.5. Run them all with one script —
  [building-many-estates.md](../reference/building-many-estates.md) — then continue at Phase 6c.

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
   - If the tenant already has a billing plan in the region, Prod and Claims-Test are created on it: a
     Dev Program tenant's Dataverse capacity holds only two estates otherwise
     ([errata → Phase 3](../reference/runbook-errata.md)).
   - The platform picks the region ([ADR-0013](../reference/adr/0013-environment-region-assigned.md)). The other
     environments get no DLP and no agent Conditional Access is created — on purpose
     ([ADR-0028](../reference/adr/0028-planted-governance-gaps.md)).

2. **Link Prod and Claims-Test to a pay-as-you-go billing plan.** Without one, agents publish but nobody
   can chat with them. The script finds the shared plan in your environments' region — creating
   `Halcourt-PAYG-<region>` in `rg-halcourt-billing` if the region has none — then links both environments
   and checks the link. Every estate in the region shares that plan
   ([ADR-0014](../reference/adr/0014-shared-billing-plan-per-region.md)). Safe to re-run.

   ```bash
   pwsh setup/scripts/02b_provision_billing.ps1
   ```

   - Never delete the plan or `rg-halcourt-billing` while any estate uses the region.
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
   - In the read-back, `Leadership/ unique permissions` must be `True` and list only the site's Owners and
     Members groups (`HR-Team-<estate>` is a Member) — no `All-Employees-<estate>`. The poisoned file must
     show `payload text present True`.
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
   label replicates ([errata → Phase 4c](../reference/runbook-errata.md#phase-4c--purview-the-label-arrives-late-and-the-token-is-app-only-2026-10-18)).

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

   - It ends with `tom.dean.<estate>@… marked departed`. Safe to re-run: it sets the same date again.
   - **Never disable Tom**: both connections go to Error within the hour and Scenario F stops reproducing.

### Phase 6c — Recheck the Purview label

1. **Re-run Phase 4c until it finishes.** Its first run usually stops short: the new label hasn't reached
   SharePoint, so the copy isn't labelled. Phases 4b–6.5 give it time. Re-running creates nothing new; it
   labels the copy once the label is there.

   ```bash
   pwsh setup/scripts/03c_provision_purview.ps1
   ```

   - No `6. Checks` section in the output means it stopped at step 5: not yet.
   - Done when the `6. Checks` lines show `copy labelled: True`, `original unlabelled: True` and `search sees
     the marker: True`.
   - Not yet? Run it again later. The label can take hours to reach SharePoint — up to a day
     ([errata → Phase 4c](../reference/runbook-errata.md#phase-4c--purview-the-label-arrives-late-and-the-token-is-app-only-2026-10-18)).
   - It must pass before the delivery: Task 05-06 retests against the labelled copy.

### Phase 7 — Export the artifact pack

1. **Give yourself a role in `Maker-Sandbox-<estate>`.** The export reads every environment's agents, and
   the admin has no Dataverse role in this one: it's a Developer environment, and Dev Kim is its only System
   Administrator — so the admin can't grant itself one, and Dev has to. These sign `pac` in as Dev, in a
   profile store of its own so your admin profile is untouched, and give your admin account System
   Administrator there. Once per estate:

   ```bash
   export XDG_DATA_HOME=/tmp/pac-devkim
   ~/.dotnet/tools/pac auth create --name devkim --username dev.kim.$HALCOURT_ESTATE@<tenant domain> --password '<lab password>' --environment <Maker-Sandbox org URL>
   ~/.dotnet/tools/pac admin assign-user --environment <Maker-Sandbox environment id> --user <your admin UPN> --role "System Administrator"
   rm -rf /tmp/pac-devkim; unset XDG_DATA_HOME
   ```

   - The environment id and org URL are in the Phase 3 summary.
   - It ends with `Successfully assigned security role 'System Administrator'`.
   - The estate builder does the same step for you (`10_build_estates.ps1`, phase `devadmin`).

2. **Export the estate over the committed pack.** The script reads this estate's environments, agents,
   connections and accounts, plus the knowledge sites' files and labels (Phase 4c's app), converts the live
   names back to the canonical ones, and writes the six CSVs in `worksheets/artifact-pack/`
   ([ADR-0022](../reference/adr/0022-artifact-export-over-rest.md)). Safe to re-run.

   ```bash
   pwsh setup/scripts/05_export_artifact_pack.ps1 -Canonicalize
   ```

3. **Review the drift, then keep or discard it.** The diff is what changed between the committed pack and
   your estate. It is never empty: descriptions, friendly connector names and some rows are hand-written
   ([ADR-0023](../reference/adr/0023-committed-pack-not-pure-export.md)).

   ```bash
   git diff worksheets/artifact-pack
   ```

   - Commit only real changes to the estate. Discard the rest with
     `git checkout -- worksheets/artifact-pack`.
   - Exporting somewhere else instead: `-OutDir <folder>`, without `-Canonicalize`, keeps the live names.

### Phase 8 — Validate

Check the estate matches `AGENTS.md`. Most of it is reading what Phases 6.5–7 already reported; the
scenarios themselves need someone to talk to the agents.

1. **Check the estate's shape against the export.** Phase 7's diff already shows whether every agent is
   present with the right owner and environment, each has one Entra identity, DLP is on Prod only, and the
   accounts are as Phase 2 left them. Look for *unexpected* drift — an agent missing, an owner changed, an
   environment that lost its DLP — not an empty diff.

2. **Check Tom is departed but still enabled.** Phase 6.5 must have run, and both of his connections must
   still work; otherwise the departed-owner scenario reads wrong:

   ```bash
   az rest --url "https://graph.microsoft.com/v1.0/users/tom.dean.$HALCOURT_ESTATE@<tenant domain>?\$select=accountEnabled,employeeLeaveDateTime"
   ```

   - It must show `accountEnabled: true` and a leave date.
   - Onboarding Guide and Sales Nudge must answer in step 3.

3. **Reproduce the planted scenarios.** Walk `AGENTS.md`'s planted problems (Scenarios A–F) and confirm
   each one fires, and that each discovery target can be found. The Teams chat probe holds a scripted
   conversation with one agent, as a persona, the way attendees do in Exercise 04:

   ```bash
   python3 setup/scripts/lib/teams_chat_probe.py --upn lena.ford.$HALCOURT_ESTATE@<tenant domain> --password '<lab password>' \
     --agent "Policy Lookup Bot" --links setup/teams-links-$HALCOURT_ESTATE.local.csv --out /tmp/probe \
     --say "look up a policy" --expect "policy id" --say "POL-1001" --expect "Policy POL-1001"
   ```

   - It ends with `RESULT=PASS`, or `RESULT=FAIL <reason>` and screenshots in `--out`.
   - Sign in as a licensed persona in the agent's chat audience, not an admin.

4. **Check the control verdicts.** Every control-efficacy verdict in `AGENTS.md` must still hold. Resolve
   any `[verify]` item you can and update `AGENTS.md`.

5. **Check the agent registry (Task 05-05).** As the facilitator, with AI Administrator activated:
   **Microsoft 365 admin center** → **Agents** must list all ten estate agents, with **Block** available on
   Onboarding Guide. If you try Block, unblock straight away.

   - Whether the tenant's Agent 365 licensing lasts until the delivery is open:
     [PLANNING item 8](../PLANNING.md).

The attendee's view — a student account's slice, Teams links and the confused-deputy path — is checked at
the end of Phase 8c, because it needs Phases 8b and 8c.

### Phase 8b — Lab (attendee) accounts

Per delivery, not per estate: attendees sign in with native lab accounts you hand out, so they review the
estate from inside the tenant. What the accounts get and why: [attendee-accounts.md](../reference/attendee-accounts.md).

1. **Count your free E5 seats.** That number is the most attendees you can run: Teams, the audit events and
   the access model all need a licence ([ADR-0004](../reference/adr/0004-one-licence-per-attendee.md)). This
   prints the free count:

   ```bash
   az rest --url https://graph.microsoft.com/v1.0/subscribedSkus --query "value[?skuPartNumber=='DEVELOPERPACK_V2_E5'] | [0].[prepaidUnits.enabled, consumedUnits]" -o tsv
   ```

   - Free = the first number minus the second. Short? Reclaim seats from built estates
     ([building-many-estates.md](../reference/building-many-estates.md)).

2. **Create the attendee accounts, the day before the delivery.** The script creates `student01.<estate>`…
   with their admin roles, Dataverse read access in each estate environment, a seat each where one is free,
   and membership of `All-Employees-<estate>` (so the Teams links work). It prints a handout and writes it,
   passwords included, to `setup/lab-users-<estate>.local.csv` (gitignored). Safe to re-run: existing
   accounts are kept, with their passwords carried forward from the handout.

   ```bash
   pwsh setup/scripts/07_provision_lab_users.ps1 -Count <N>          # add -UniquePasswords for a distinct password each
   ```

   - The day before, not the morning of: Conditional Access and Dataverse's licence state both lag by hours.
   - The end-of-run table shows who got a seat. An attendee without one takes the artifact-pack route for
     the Copilot Studio and role-editor steps.

3. **Grant the attendees Purview's transcript role.** Task 05-07 opens a chat's transcript in DSPM for AI,
   which Global Reader alone can't. It asks for one device-code approval as the admin:

   ```bash
   pwsh setup/scripts/07c_provision_purview_roles.ps1
   ```

4. **Tell attendees to bring an authenticator app.** Their accounts hold admin roles, so Entra makes each one
   register MFA at first sign-in — about two minutes, once. Don't try to avoid it with a Conditional Access
   exclusion: the admin portals and APIs enforce MFA anyway
   ([attendee-accounts.md](../reference/attendee-accounts.md)).

An attendee account is a tenant-wide Power Platform admin: delete the accounts right after the delivery
(Phase 9).

### Phase 8c — Per-student slices (needed from Exercise 03)

Each attendee gets a small environment of their own, where they are System Administrator, to open the
`svc-claims` role in Tasks 03-02 and 03-04. Why, and what a slice holds:
[student-slices.md](../reference/student-slices.md).

1. **Build a slice for each attendee account, before the delivery.** The script creates `Lab-<estate>-NN`
   for `studentNN` — a Sandbox environment with Dataverse, on the estate's billing plan, seeded like
   Claims-Test (the claims data and the over-broad `svc-claims` role) — and makes `studentNN` its System
   Administrator. Use the same number as Phase 8b: the handout's `studentNN` must match its slice. Safe to
   re-run.

   ```bash
   pwsh setup/scripts/08_provision_student_slices.ps1 -Count <N>
   ```

   - A new slice's Dataverse is usually ready in about 30 seconds. An early *"Interactive authentication is
     needed"* clears on its own; the script retries.

2. **Check the attendee's view.** This is Phase 8's last check; it needs 8b and 8c. In a browser, sign in as
   one student account (password in `setup/lab-users-<estate>.local.csv`). The first sign-in makes you
   register MFA — have an authenticator app ready. Then confirm:

   - [ ] the Power Platform admin center lists their slice, `Lab-<estate>-NN`;
   - [ ] each Teams install link from `setup/teams-links-<estate>.local.csv` opens the agent;
   - [ ] Claims Copilot gives them claim CLM-9002, although their own Claims-Test roles grant no claim
         access — the confused-deputy path, with the attendee as the requester.

### Before delivery — preflight, audit and Exercise 04 notes

Run these the day before. They check what the build phases set up, as the attendees will see it. What each
check protects: [before-delivery-checks.md](../reference/before-delivery-checks.md).

1. **Run the preflight.** It checks the tenant capabilities
   ([tenant-capabilities.md](../reference/tenant-capabilities.md)), the estate and the attendee access
   model, and names the exercise step each failed check would break. In the dev container terminal, signed
   in and with your estate id set (Phase 0b steps 2 and 4), with the number of attendees you'll run:

   ```bash
   pwsh setup/scripts/00b_preflight.ps1 -Attendees <N>
   ```

   - Fix every FAIL. A WARN names the fallback attendees will use.

2. **Chat with each Teams agent once**, as a licensed persona with no admin role, the way attendees will.
   The preflight proves the agents exist; this proves they answer. Run the probe once per row of
   `setup/teams-links-<estate>.local.csv`, with a question that agent answers. For Policy Lookup Bot:

   ```bash
   python3 setup/scripts/lib/teams_chat_probe.py --upn lena.ford.$HALCOURT_ESTATE@<tenant domain> --password '<lab password>' \
     --agent "Policy Lookup Bot" --links setup/teams-links-$HALCOURT_ESTATE.local.csv --out /tmp/probe \
     --say "look up a policy" --expect "policy id" --say "POL-1001" --expect "Policy POL-1001"
   ```

   - It ends with `RESULT=PASS`; screenshots land in `--out`.
   - Personas' seats reclaimed after the build? Lend Jordan Blake a seat and chat as Jordan.

3. **Check, as an attendee, that the Exercise 04 chats reach the audit log.** In a private browser window,
   signed in as a student account, after a rehearsal chat. These are the routes Task 05-07 sends attendees
   down:

   - [ ] **Purview Audit.** Open the **Microsoft Purview portal**, https://purview.microsoft.com →
         **Solutions** → **Audit**. There must be no "start recording" banner. Search with **Record Types**
         = `CopilotInteraction` and **Users** = the student account, over today (the date picker stops at
         today: set the end time late; times are UTC). The rehearsal chat must be listed — a search takes
         4–7 minutes, then **Refresh**; ingestion can take up to an hour to start after Phase 5b.
         *Total Result Count* can read 0 above a list of results; the list is what counts. Without the
         **Users** filter the search shows every estate's chats.
   - [ ] **DSPM for AI.** In the same portal, **Solutions** → **DSPM for AI (classic)** → **Activity
         explorer** (select **Maybe later** if a *New Unified Data Security Posture Management* window opens).
         With **User participant** = the student account, the rehearsal chat's **AI Interaction** record
         (agent, user, time, app) must show. The prompt and response text usually doesn't, and an
         "Additional permissions required" banner about AI visits is expected — tell the room the text is
         optional.
   - [ ] **The Claims-Test audit summary.** Open `<Claims-Test org URL>/tools/audit/audit_summary.aspx`
         (the org URL is in the Phase 3 summary, or **Power Platform admin center**,
         https://admin.powerplatform.microsoft.com → **Manage → Environments** → `Claims-Test-<estate>` →
         **Environment URL**). It must list audit records — at least Phase 5b's *Audit Change* entries — and
         the student can't open a claim itself, which is expected. Don't use the admin center's **Settings →
         Audit and logs → Audit summary view** link: it fails for attendees with *Error loading control*.
         The page's **Delete Change History** button shows for everyone but is refused: the lab role holds
         no delete privilege.

4. **Brief yourself on what the room can't do.** Each is expected, not a fault:

   - 04-04's write half is reasoned, not run: Claims Copilot has no update tool, so there's no test claim.
   - Claims Copilot's reads appear in no log: Dataverse never audits reads, and `Claims-Test` is a sandbox.
     05-07 KT03 teaches that gap.
   - Defender real-time protection isn't set up (no Agent 365 licence); 05-07 KT06 reasons it through.

5. **Create the facilitator account and sign in with it once.** You demonstrate Exercise 05 as this account
   (`facilitator.<estate>`, "Lab Facilitator (<estate>)"), not your own tenant admin: it holds Power
   Platform Administrator, and AI Administrator only as PIM-eligible. The script writes its password to
   `setup/lab-facilitator-<estate>.local.csv` (gitignored). Safe to re-run.

   ```bash
   pwsh setup/scripts/07b_provision_facilitator.ps1
   ```

   - Sign in with it once in a browser to enrol MFA: it is an admin, so `CA-Require-MFA-Admins` applies.

### During delivery — Exercise 05 demonstrations

Attendees share one estate, so **you** apply each Exercise 05 control, once, live; the room retests; you put
the estate back. Do it as the facilitator account (Before delivery, step 5), not your own tenant admin.

1. **Before Exercise 05 starts, snapshot the estate.** The script records the data policies, the default
   environment's makers and `svc-claims`'s roles, so each demonstration can be undone exactly:

   ```bash
   pwsh setup/scripts/09_ex05_demo_state.ps1 -Action Snapshot -Control All
   ```

2. **For each task, demonstrate the control, let the room retest, then put it back** — as soon as the
   retests are done. Sign in as the facilitator account unless a task says otherwise. The click paths come
   from each task's page; those marked *(not yet walked)* haven't been run as the facilitator.

   **05-01 — Block HTTP and custom connectors in Prod** (attendees follow KT02, retest in KT03 and KT05)

   1. **Power Platform admin center** → **Security** → **Data and privacy** → **Data policy** →
      `Halcourt-Prod-DLP-<estate>` → **Edit Policy** *(not yet walked)*.
   2. Move **HTTP** and **HTTP with Microsoft Entra ID** to **Blocked**; set **custom connectors** to
      **Blocked**; leave **Dataverse** and **SharePoint** in **Business**. Save.
   3. **Show the room** the Blocked group, then wait for KT03 (Policy Lookup Bot and Underwriting Assistant)
      and KT05. Expect the HTTP call and the MCP tool to fail, and maybe agents that won't publish (the
      page's warning).
   4. **Put it back:** `pwsh setup/scripts/09_ex05_demo_state.ps1 -Action Restore -Control Dlp`

   **05-02 — A data policy on the default environment** (KT03; retests in KT06 and KT08)

   1. **Power Platform admin center** → **Security** → **Data and privacy** → **Data policy** → **New
      policy**, named `Halcourt-Default-DLP-<estate>`, scoped to **Halcourt (default)** only, with **HTTP**,
      **HTTP with Microsoft Entra ID** and **custom connectors** **Blocked** *(not yet walked)*.
   2. **Show the room** the policy, and that you can't fence the default environment's makers: every
      licensed user is an Environment Maker there.
   3. Wait for KT06 and KT08.
   4. **Put it back:** `pwsh setup/scripts/09_ex05_demo_state.ps1 -Action Restore -Control Dlp` — it deletes the new policy (the estate id in its
      name is what allows that).

   **05-03 — Scope Benefits Buddy's reach, and svc-claims's role** (KT01, KT02; retests in KT03, KT05, KT07)

   1. **Scenario B, as Marcus Webb** (`marcus.webb.<estate>`, the agent's owner and the site's member):
      remove the knowledge source's effective reader's permission on `Leadership/` in
      `HR-Benefits-<estate>` — the route KT01 step 3 offers *(not yet walked)*. Don't narrow the Knowledge
      instead: that did not stop the leak within an hour
      ([errata](../reference/runbook-errata.md#exercise-05-03--narrowing-benefits-buddys-grounding-did-not-stop-the-leak-within-an-hour-2026-10-20)).
   2. **Scenarios C and D:** the scoped `svc-claims` role and its fixed data subset, by script:

      ```bash
      pwsh setup/scripts/09b_ex05_scoped_claims_role.ps1
      ```

   3. **Show the room** the new role in **Claims-Test**'s security roles, and the permission change. Wait for
      KT03, KT05 and KT07.
   4. **Put it back:** restore the `Leadership/` permission by hand, then
      `pwsh setup/scripts/09_ex05_demo_state.ps1 -Action Restore -Control ClaimsRoles` (the role, Basic User and record owners).

   **05-04 — Nothing to change.** The Conditional Access policy is specified, never created: one wrong
   policy locks out the tenant.

   **05-05 — Block Onboarding Guide** (KT06)

   1. Activate the facilitator's **AI Administrator** in PIM.
   2. **Microsoft 365 admin center** → **Agents** → **Onboarding Guide** → **Block** *(not yet walked)*.
      Never **Delete**: it can't be undone.
   3. Wait for KT06 (can Onboarding Guide still send mail?).
   4. **Put it back:** the same page → **Unblock**, by hand. Let AI Administrator lapse.

   **05-06 — Show the labelled copy** (KT01 step 3; nothing changes)

   1. As Marcus Webb (an HR-leadership member), open `HR-Benefits-<estate>` → **Documents** →
      `Leadership/`, select each comp file → **Details**.
   2. **Show the room:** `2026-comp-bands-labeled.xlsx` shows **Sensitivity** `Confidential-PII-<estate>`,
      `2026-comp-bands.xlsx` none. The library view has no Sensitivity column.

   **05-07 — Nothing to change.** Real-time protection is reasoned through (KT06): the tenant has no Agent
   365 licence.

3. **At the end, check everything is back.** Every line must say "same as the snapshot":

   ```bash
   pwsh setup/scripts/09_ex05_demo_state.ps1 -Action Diff -Control All
   ```

### Phase 9 — Teardown

After the delivery, remove this estate's attendee and facilitator accounts, its slices, its Purview
objects, then the estate itself. Run the steps in this order: some need things a later step deletes. Each
removes only this estate; nothing another estate uses is touched. To reseed instead, re-run Phases 2–6.

1. **Take back the attendees' Purview role.** Before step 2, while the accounts still exist: the script
   matches role-group members by display name. It needs one admin device-code approval.

   ```bash
   pwsh setup/scripts/07c_provision_purview_roles.ps1 -Remove
   ```

2. **Delete the attendee accounts and their handout.** The script deletes and purges the accounts
   ([ADR-0026](../reference/adr/0026-attendee-teardown-purges.md)).

   ```bash
   pwsh setup/scripts/07_provision_lab_users.ps1 -Destroy
   rm setup/lab-users-$HALCOURT_ESTATE.local.csv
   ```

3. **Delete the facilitator account.** It also deletes its password file.

   ```bash
   pwsh setup/scripts/07b_provision_facilitator.ps1 -Destroy
   ```

4. **Delete the per-student slices.** Before step 6: the script finds the billing plan to unlink through
   the estate's Prod environment.

   ```bash
   pwsh setup/scripts/08_provision_student_slices.ps1 -Destroy
   ```

5. **Delete the Purview label and policy.** It removes `Halcourt-Labels-<estate>`, then
   `Confidential-PII-<estate>`, retrying while the policy is withdrawn; re-run it if it times out.

   ```bash
   pwsh setup/scripts/03c_provision_purview.ps1 -Remove
   ```

6. **Tear down the estate.** In dependency order: the default environment's agents and the auto-approve
   flow (as their owners), the SharePoint sites (purged, so the URLs can be reused), the three estate
   environments with everything in them, the Prod data policy, and the billing link. It only unlinks the
   billing plan; it never deletes it. `-RemovePersonas` also deletes the Phase 2 personas and every
   `*-<estate>` group.

   ```bash
   export ENTRAID_APP_ID=$(az ad app list --display-name "Halcourt PnP" --query "[0].appId" -o tsv)
   export HALCOURT_PNP_CERT_PFX=setup/pnp.local.pfx HALCOURT_PNP_CERT_PW=<cert-pw>
   pwsh setup/scripts/99_teardown.ps1 -RemovePersonas
   ```

   - Environments delete in the background, over a few minutes.
   - It keeps Phase 0 (the tenant and the Conditional Access baseline), the default environment, the
     shared Azure deployment and the other shared pieces.

7. **Delete the estate's local files.**

   ```bash
   rm -rf setup/ex05-state/$HALCOURT_ESTATE setup/teams-links-$HALCOURT_ESTATE.local.csv
   ```

Last estate in the tenant? The shared pieces — the Azure deployment, the billing plan, the lab apps and the
tenant-wide grants — are retired separately: [retiring-shared-resources.md](../reference/retiring-shared-resources.md).

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
| `scripts/lib/teams_chat_probe.py` | Chats with a published agent in Teams as a persona; checks it answers before a delivery |
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
