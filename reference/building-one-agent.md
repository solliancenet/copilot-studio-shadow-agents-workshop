# Building one agent from the command line

The manual counterpart to `06_provision_agents.ps1` ([ADR-0020](adr/0020-agents-provisioned-clone-first.md)), and how a planted agent is first captured ([ADR-0021](adr/0021-planted-mechanisms-in-topics.md)).

The manual counterpart to the engine, and how a planted agent is first captured. Full per-agent detail is
in [`agent-authoring-guide.md`](../setup/agent-authoring-guide.md).

`pac` 2.12 builds and publishes an agent from a local workspace. Sign it in as the owner, with a profile
store of its own so your admin profile is untouched. Password sign-in works for the personas because the
CA baseline only requires MFA of admin roles. Call the real `pac`, not the repo's shim — the shim pins the
profile store to `.pac/`:

```bash
export XDG_DATA_HOME=$HOME/.halcourt-pac/marcus.webb     # one store per persona
~/.dotnet/tools/pac auth create --username marcus.webb.$E@$D --password '<lab password>' --environment <Prod org URL>
~/.dotnet/tools/pac copilot init --name "Benefits Buddy" --publisher-prefix <prefix> --project-dir agents/benefits-buddy
#   edit agents/benefits-buddy/agent.mcs.yml (instructions) and add knowledge/*.mcs.yml, actions/*.mcs.yml
~/.dotnet/tools/pac copilot push --project-dir agents/benefits-buddy
~/.dotnet/tools/pac copilot publish --bot <prefix>_BenefitsBuddy
```

- `<prefix>` is the environment's **CDS Default Publisher** prefix — the one the portal uses (`cr3f5` for
  Prod and Claims-Test on the verified tenant). `init` imports the agent straight away, owned by the
  persona.
- **`push` doesn't send `settings.mcs.yml`.** Set the chat audience on the agent record instead — PATCH
  `bots(<botid>)` with `authorizedsecuritygroupids` = the group's object id — then publish again.
- **`push` creates a connection reference but doesn't bind it.** PATCH `connectionreferences(<id>)` with
  `connectionid` = the owner's connection name, as the owner.
- A failed publish reports its errors in the agent record's `synchronizationstatus` →
  `lastFinishedPublishOperation`, not in `pac`'s output.

Built this way on the verified tenant (2026-09-19): **Team Wiki** (`Maker-Sandbox-mgray`, as Dev) and
**Benefits Buddy** (`Halcourt-Prod-mgray`, as Marcus).

## What to expect from the connections

- **OAuth connections can't be shared.** Sharing `DV-Claims-Shared` or `DV-CRM-Shared` with a group fails
  with *ConnectionSharingNotAllowed*, so the pack's `shared_with` values for them can't appear in a live
  export. The agent is what "shares" them: its tools run on the connection with the maker's credentials.
- **In the default environment the consent page asks the owner to confirm** ("Confirmation required", a
  checkbox, then **Allow access**). That is expected for a connection the owner just created.
- **Dev's OneDrive connection fails until his OneDrive exists** (Phase 4b).
