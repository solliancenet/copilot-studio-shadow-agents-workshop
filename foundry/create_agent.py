#!/usr/bin/env python3
"""
Create (and smoke-test) the "Claims Triage" agent in the Meridian Mutual Azure AI
Foundry project.

The agent is wired to two tools:
  * File Search  -> grounding docs (policy declarations + claims-handling guide)
  * OpenAPI      -> the live Meridian Mutual Member API (anonymous / demo)

Auth is DefaultAzureCredential (run `az login` first). The signed-in identity needs
a data-plane role on the Foundry account -- "Foundry User" (the role formerly named
"Azure AI User", role id 53ca6127-db72-4b80-b1b0-d745d6d5456d). See README notes.

Usage:
    python create_agent.py            # create the agent, then run the smoke test
    python create_agent.py --no-test  # create only
    CLAIM_NUMBER=CLM-2026-00841 python create_agent.py
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys
import urllib.request

from azure.identity import DefaultAzureCredential
from azure.ai.agents import AgentsClient
from azure.ai.agents.models import (
    FileSearchTool,
    FilePurpose,
    OpenApiTool,
    OpenApiAnonymousAuthDetails,
    ListSortOrder,
    MessageRole,
)

HERE = pathlib.Path(__file__).resolve().parent

# --------------------------------------------------------------------------------------
# Configuration -- resolved from azd env values (or the deployed facts as fallback).
# --------------------------------------------------------------------------------------

# The AGENTS SDK needs the *project* endpoint, which is NOT the account's
# cognitiveservices endpoint. Documented format:
#   https://<account>.services.ai.azure.com/api/projects/<project-name>
# Verified against the account's "AI Foundry API" endpoint via
#   az cognitiveservices account show ... --query properties.endpoints
FOUNDRY_ACCOUNT_HOST = "aif-ieveiacpjsr6g.services.ai.azure.com"  # [verify]
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

# Only CLM-2026-00841 exists in the seeded demo data (a Coverage B collision claim on
# policy MM-AUTO-004417). Override with the CLAIM_NUMBER env var if the seed changes.
CLAIM_NUMBER = os.environ.get("CLAIM_NUMBER", "CLM-2026-00841")

AGENT_NAME = "Claims Triage"

GROUNDING_DOCS = [
    HERE / "policy-declarations.md",
    HERE / "claims-handling-guide.md",
]

INSTRUCTIONS = (
    "You are a Claims Triage assistant for Meridian Mutual. Given a claim number, "
    "produce a structured triage briefing for a human adjuster. Use the Meridian "
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
# OpenAPI spec handling
# --------------------------------------------------------------------------------------

def load_openapi_spec() -> dict:
    """Fetch the app's swagger and make it usable as a Foundry OpenAPI tool.

    Two fixups:
      1. Force servers[0].url to the absolute live app base URL. The app ships a spec
         with no `servers` block (relative), which would make the tool call nowhere.
      2. Inject an operationId on every operation. The Foundry OpenAPI tool derives one
         tool function per operationId; the shipped spec has none.
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
# Agent creation
# --------------------------------------------------------------------------------------

def create_agent(agents: AgentsClient) -> str:
    # 1) Upload grounding docs and build a File Search vector store.
    file_ids = []
    for doc in GROUNDING_DOCS:
        uploaded = agents.files.upload_and_poll(
            file_path=str(doc), purpose=FilePurpose.AGENTS
        )
        print(f"  uploaded {doc.name} -> {uploaded.id}")
        file_ids.append(uploaded.id)

    vector_store = agents.vector_stores.create_and_poll(
        file_ids=file_ids, name="meridian-claims-grounding"
    )
    print(f"  vector store -> {vector_store.id} (status={vector_store.status})")

    file_search = FileSearchTool(vector_store_ids=[vector_store.id])

    # 2) Build the OpenAPI tool from the live app swagger (anonymous auth).
    spec = load_openapi_spec()
    openapi = OpenApiTool(
        name="meridian_member_api",
        description=(
            "Meridian Mutual Member API: look up claims (by number or by policy), "
            "policies and coverage summaries, premium payment history, and "
            "policyholders."
        ),
        spec=spec,
        auth=OpenApiAnonymousAuthDetails(),
    )
    print(f"  openapi server -> {spec['servers'][0]['url']}")

    # 3) Create the agent with both tools.
    tools = file_search.definitions + openapi.definitions
    tool_resources = file_search.resources

    agent = agents.create_agent(
        model=MODEL_DEPLOYMENT,
        name=AGENT_NAME,
        instructions=INSTRUCTIONS,
        tools=tools,
        tool_resources=tool_resources,
    )
    return agent.id


# --------------------------------------------------------------------------------------
# Smoke test
# --------------------------------------------------------------------------------------

def run_test(agents: AgentsClient, agent_id: str) -> None:
    thread = agents.threads.create()
    prompt = f"Prepare a triage briefing for claim {CLAIM_NUMBER}"
    agents.messages.create(thread_id=thread.id, role=MessageRole.USER, content=prompt)
    print(f"\n>>> USER: {prompt}\n")

    run = agents.runs.create_and_process(thread_id=thread.id, agent_id=agent_id)
    print(f"Run {run.id} finished with status: {run.status}")
    if run.last_error:
        print(f"Run error: {run.last_error}")

    # Run steps -- show OpenAPI tool calls + file-search invocations.
    print("\n=== RUN STEPS (tool calls) ===")
    steps = agents.run_steps.list(
        thread_id=thread.id, run_id=run.id, order=ListSortOrder.ASCENDING
    )
    for step in steps:
        print(f"- {step.type} [{step.status}]")
        details = getattr(step, "step_details", None)
        tool_calls = getattr(details, "tool_calls", None) or []
        for tc in tool_calls:
            # Tool-call entries are dict-like models; use .get for robustness.
            get = tc.get if hasattr(tc, "get") else (lambda k, d=None: getattr(tc, k, d))
            kind = get("type", "?")
            if kind == "openapi":
                fn = get("function") or {}
                name = fn.get("name")
                args = fn.get("arguments")
                print(f"    * openapi call: {name}({args})")
            elif kind == "file_search":
                fs = get("file_search") or {}
                results = fs.get("results") if hasattr(fs, "get") else None
                n = len(results) if results else "?"
                print(f"    * file_search call ({n} results)")
            else:
                print(f"    * {kind} call")

    # Final assistant message.
    print("\n=== FINAL BRIEFING ===")
    last = agents.messages.get_last_message_text_by_role(
        thread_id=thread.id, role=MessageRole.AGENT
    )
    text = last.text.value if last else "(no message)"
    print(text)

    # Surface file-search citations, if any were annotated on the message.
    msgs = agents.messages.list(thread_id=thread.id, order=ListSortOrder.ASCENDING)
    print("\n=== CITATIONS / ANNOTATIONS ===")
    found = False
    for msg in msgs:
        if msg.role != MessageRole.AGENT:
            continue
        for ann in getattr(msg, "url_citation_annotations", []) or []:
            found = True
            print(f"    url: {ann.text}")
        for ann in getattr(msg, "file_citation_annotations", []) or []:
            found = True
            fc = getattr(ann, "file_citation", None)
            print(f"    file citation: {ann.text} (file_id={getattr(fc,'file_id',None)})")
    if not found:
        print("    (no structured citation annotations returned)")


# --------------------------------------------------------------------------------------

def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-test", action="store_true", help="create the agent only")
    args = parser.parse_args()

    print(f"Project endpoint: {PROJECT_ENDPOINT}")
    print(f"Model deployment: {MODEL_DEPLOYMENT}")
    print(f"App base URL:     {APP_BASE_URL}")

    credential = DefaultAzureCredential()
    # The classic Agents (Assistants-style: files, vector stores, threads, runs) surface
    # lives in azure-ai-agents' AgentsClient. In azure-ai-projects 2.x the project
    # client's `.agents` is the newer hosted-agent-version API, not this one. [verify]
    with AgentsClient(endpoint=PROJECT_ENDPOINT, credential=credential) as agents:
        print("\nCreating agent...")
        agent_id = create_agent(agents)
        print(f"\nCreated agent id: {agent_id}")

        if not args.no_test:
            run_test(agents, agent_id)

    return 0


if __name__ == "__main__":
    sys.exit(main())
