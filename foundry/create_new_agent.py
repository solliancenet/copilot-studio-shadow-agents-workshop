#!/usr/bin/env python3
"""
Create (and smoke-test) the "Claims Triage" agent on Azure AI Foundry's NEW agent
API -- the server-side "prompt agent" surface -- so it appears in the new-Foundry
Agents list + playground (NOT under "Classic agents").

Why this exists
---------------
The sibling create_agent.py uses the CLASSIC Assistants-style surface
(azure.ai.agents.AgentsClient -> `asst_` id). That agent only shows under
"Classic agents" and won't open in the new playground.

The NEW agent API is the `azure-ai-projects` (>= 2.0) "prompt agent" surface:
    project.agents.create_version(agent_name=..., definition=PromptAgentDefinition(...))
Agents created this way are versioned Foundry Agent resources (name + version),
runnable through the Responses API by `agent_reference`, and they render as
first-class (new) agents in the portal -- not classic.

The agent is wired to the same two tools as the classic build:
  * File Search  -> grounding docs (policy declarations + claims-handling guide),
                    indexed in a vector store on the project's OpenAI-compatible
                    endpoint.
  * OpenAPI      -> the live Halcourt Mutual Member API (anonymous / demo),
                    spec patched so servers[0].url points at the live app and every
                    operation has an operationId.

Auth is DefaultAzureCredential (run `az login` first). The signed-in identity needs
the data-plane "Foundry User" role on the Foundry account.

Usage:
    python create_new_agent.py            # create the agent, then run the smoke test
    python create_new_agent.py --no-test  # create only
    python create_new_agent.py --delete-classic asst_XXXX  # delete a classic asst after
    CLAIM_NUMBER=CLM-2026-00841 python create_new_agent.py
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys
import urllib.request
from typing import Any, cast

from azure.identity import DefaultAzureCredential
from azure.ai.projects import AIProjectClient
from azure.ai.projects.models import (
    PromptAgentDefinition,
    FileSearchTool,
    OpenApiTool,
    OpenApiFunctionDefinition,
    OpenApiManagedAuthDetails,
    OpenApiManagedSecurityScheme,
)

HERE = pathlib.Path(__file__).resolve().parent

# --------------------------------------------------------------------------------------
# Configuration -- resolved from azd env values (or the deployed facts as fallback).
# --------------------------------------------------------------------------------------

FOUNDRY_ACCOUNT_HOST = "aif-ieveiacpjsr6g.services.ai.azure.com"
PROJECT_NAME = os.environ.get("AZURE_AI_FOUNDRY_PROJECT", "proj-ieveiacpjsr6g")
PROJECT_ENDPOINT = os.environ.get(
    "AZURE_AI_FOUNDRY_PROJECT_ENDPOINT",
    f"https://{FOUNDRY_ACCOUNT_HOST}/api/projects/{PROJECT_NAME}",
)

MODEL_DEPLOYMENT = os.environ.get("AZURE_OPENAI_MODEL", "gpt-4.1")

APP_BASE_URL = os.environ.get(
    "WEB_URI",
    "https://ca-web-ieveiacpjsr6g.thankfulglacier-039daedb.westus3.azurecontainerapps.io",
).rstrip("/")
SWAGGER_URL = f"{APP_BASE_URL}/swagger/v1/swagger.json"

CLAIM_NUMBER = os.environ.get("CLAIM_NUMBER", "CLM-2026-00841")

AGENT_NAME = os.environ.get("AGENT_NAME", "Claims-Triage")

# Entra audience the OpenAPI tool authenticates for. The Foundry PROJECT managed identity acquires
# a token for this audience (the API app registration's App ID URI, api://<appId>) and presents it
# to the member API. The project MI is granted ONLY the Claims.Read app role, so read operations
# succeed and the write operation (PUT /api/claims/{n}/status) is refused with 401 at the RBAC
# layer — the demo's provable least-privilege hard stop. Set API_APP_URI (or API_APP_ID) from the
# azd env; falls back to the known deployed app registration.
# Use the agent-scoped App ID URI (api://<appId>/agent) as the token audience. It is a distinct
# resource from the base api://<appId>, so the Foundry managed identity acquires a separate token
# for it — which is what makes a freshly-assigned app role take effect immediately instead of
# waiting out the managed-identity token cache on the base audience. The API accepts both URIs.
API_APP_URI = os.environ.get("API_APP_URI") or (
    f"api://{os.environ['API_APP_ID']}/agent" if os.environ.get("API_APP_ID")
    else "api://3016ef29-db5c-49c6-bce3-5c5197c9546d/agent"
)

GROUNDING_DOCS = [
    HERE / "policy-declarations.md",
    HERE / "claims-handling-guide.md",
]

# Same instructions as create_agent.py.
INSTRUCTIONS = (
    "You are a Claims Triage assistant for Halcourt Mutual. Given a claim number, "
    "produce a structured triage briefing for a human adjuster. Use the Halcourt "
    "Mutual API tools to look up the claim, its policy and coverage, premium standing, "
    "prior claims on the policy, and the policyholder. Use file search to check "
    "coverage against the policy declarations and claims-handling guide, and cite the "
    "sources. Output these sections: Summary; Policy & coverage context; Standing; "
    "Claims history / anomaly note; Coverage assessment (grounded + cited); Recommended "
    "next steps. Always end with exactly: 'Human review required - no decision made by "
    "the agent.' Never make or state a claim decision - you only brief. If data is "
    "missing, say so plainly."
)


# --------------------------------------------------------------------------------------
# OpenAPI spec handling (identical fixups to the classic build)
# --------------------------------------------------------------------------------------

def load_openapi_spec() -> dict:
    """Fetch the app's swagger and make it usable as a Foundry OpenAPI tool.

    Two fixups:
      1. Force servers[0].url to the absolute live app base URL. The app ships a spec
         with no `servers` block (relative), which would make the tool call nowhere.
      2. Inject an operationId on every operation -- required by the OpenAPI tool.
    """
    with urllib.request.urlopen(SWAGGER_URL, timeout=30) as resp:  # nosec B310 (trusted demo host)
        spec = json.loads(resp.read().decode("utf-8"))

    spec["servers"] = [{"url": APP_BASE_URL}]

    for path, path_item in spec.get("paths", {}).items():
        for method, op in path_item.items():
            if method.lower() not in {"get", "post", "put", "patch", "delete"}:
                continue
            if not op.get("operationId"):
                slug = path.strip("/").replace("/", "_").replace("{", "").replace("}", "")
                op["operationId"] = f"{method.lower()}_{slug}"

    return spec


# --------------------------------------------------------------------------------------
# Agent creation (NEW prompt-agent surface)
# --------------------------------------------------------------------------------------

def create_agent(project: AIProjectClient, openai) -> Any:
    # 1) Upload grounding docs into a vector store on the project's OpenAI endpoint.
    vector_store = openai.vector_stores.create(name="halcourt-claims-grounding")
    print(f"  vector store -> {vector_store.id}")
    for doc in GROUNDING_DOCS:
        with open(doc, "rb") as fh:
            vs_file = openai.vector_stores.files.upload_and_poll(
                vector_store_id=vector_store.id, file=fh
            )
        print(f"  uploaded {doc.name} -> {vs_file.id} (status={vs_file.status})")

    file_search = FileSearchTool(vector_store_ids=[vector_store.id])

    # 2) Build the OpenAPI tool from the live app swagger. Managed-identity auth: the Foundry
    #    project MI presents an Entra token for the API's App ID URI on every tool call. The MI
    #    holds only Claims.Read, so the write operation returns 401 by RBAC — not by prompt.
    spec = load_openapi_spec()
    openapi = OpenApiTool(
        openapi=OpenApiFunctionDefinition(
            name="halcourt_member_api",
            description=(
                "Halcourt Mutual Member API: look up claims (by number or by policy), "
                "policies and coverage summaries, premium payment history, and "
                "policyholders."
            ),
            spec=spec,
            auth=OpenApiManagedAuthDetails(
                security_scheme=OpenApiManagedSecurityScheme(audience=API_APP_URI),
            ),
        )
    )
    print(f"  openapi server -> {spec['servers'][0]['url']}")
    print(f"  openapi auth   -> managed_identity (audience={API_APP_URI})")

    # 3) Create (version) the prompt agent with both tools.
    agent = project.agents.create_version(
        agent_name=AGENT_NAME,
        definition=PromptAgentDefinition(
            model=MODEL_DEPLOYMENT,
            instructions=INSTRUCTIONS,
            tools=[file_search, openapi],
        ),
    )
    return agent


# --------------------------------------------------------------------------------------
# Smoke test -- run via the Responses API, referencing the agent by name.
# --------------------------------------------------------------------------------------

def run_test(openai, agent) -> None:
    prompt = f"Prepare a triage briefing for claim {CLAIM_NUMBER}"
    print(f"\n>>> USER: {prompt}\n")

    response = openai.responses.create(
        input=prompt,
        extra_body={
            "agent_reference": {"name": agent.name, "type": "agent_reference"}
        },
    )

    print(f"Response {response.id} status: {getattr(response, 'status', '?')}")

    # Tool / knowledge calls surface as items in response.output.
    print("\n=== OUTPUT ITEMS (tool + knowledge calls) ===")
    for item in getattr(response, "output", []) or []:
        itype = getattr(item, "type", "?")
        if itype in ("function_call", "openapi_call", "custom_tool_call"):
            name = getattr(item, "name", None)
            args = getattr(item, "arguments", None)
            print(f"- {itype}: {name}({args})")
        elif itype == "file_search_call":
            queries = getattr(item, "queries", None)
            results = getattr(item, "results", None)
            n = len(results) if results else "?"
            print(f"- file_search_call: queries={queries} ({n} results)")
        elif itype == "message":
            print(f"- message [{getattr(item, 'role', '?')}]")
        else:
            print(f"- {itype}")

    print("\n=== FINAL BRIEFING ===")
    print(getattr(response, "output_text", "(no output_text)"))


# --------------------------------------------------------------------------------------

def delete_classic(endpoint: str, credential, asst_id: str) -> None:
    """Delete a leftover classic Assistants-style agent (asst_...)."""
    try:
        from azure.ai.agents import AgentsClient

        with AgentsClient(endpoint=endpoint, credential=credential) as agents:
            agents.delete_agent(asst_id)
        print(f"Deleted classic assistant {asst_id}")
    except Exception as exc:  # noqa: BLE001
        print(f"Could not delete classic assistant {asst_id}: {exc}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-test", action="store_true", help="create the agent only")
    parser.add_argument(
        "--delete-classic",
        metavar="ASST_ID",
        help="delete this classic assistant AFTER the new agent tests green",
    )
    args = parser.parse_args()

    print(f"Project endpoint: {PROJECT_ENDPOINT}")
    print(f"Model deployment: {MODEL_DEPLOYMENT}")
    print(f"App base URL:     {APP_BASE_URL}")

    credential = DefaultAzureCredential()
    with AIProjectClient(endpoint=PROJECT_ENDPOINT, credential=credential) as project:
        openai = project.get_openai_client()

        print("\nCreating NEW prompt agent...")
        agent = create_agent(project, openai)
        print(
            f"\nCreated NEW agent: name={agent.name} version={agent.version} "
            f"id={getattr(agent, 'id', None)}"
        )

        if not args.no_test:
            run_test(openai, agent)

        if args.delete_classic:
            delete_classic(PROJECT_ENDPOINT, credential, args.delete_classic)

    return 0


if __name__ == "__main__":
    sys.exit(main())
