# Deploying the shared Azure apps (owner, once per lab)

One deployment of the Policy API and Underwriting MCP serves every estate
([ADR-0005](adr/0005-shared-azure-deployment.md)). RUNBOOK → Phase 1 covers building an estate against it;
this page is for the one facilitator who owns it.

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
[ADR-0012](adr/0012-azd-environment-per-estate.md) and
[azure-endpoints.md](azure-endpoints.md). `azd up` failures and Foundry
soft-delete: [errata → Phase 1](runbook-errata.md).
