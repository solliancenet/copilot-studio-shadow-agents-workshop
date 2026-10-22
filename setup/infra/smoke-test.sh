#!/usr/bin/env bash
# Run after `azd up`:  eval "$(azd env get-values | grep -E "^(POLICY_API_FQDN|UNDERWRITING_MCP_FQDN|POLICY_API_KEY|MCP_BEARER)=")"
#   (no azd env? from the shared values file: eval "$(jq -r 'to_entries[]|"\(.key)=\(.value|@sh)"' setup/lab-endpoints.local.json)")
#   bash setup/infra/smoke-test.sh "$POLICY_API_FQDN" "$POLICY_API_KEY" "$UNDERWRITING_MCP_FQDN" "$MCP_BEARER"
# Functional smoke test of the two Phase 1 endpoints: each must REJECT a bad credential and SERVE the scenario
# behaviour with the right one. Usage: azd_smoke.sh <policy fqdn> <policy key> <mcp fqdn> <mcp bearer>
P=$1; K=$2; M=$3; B=$4; fail=0
chk(){ if [ "$2" = "$3" ]; then printf "  ok    %-52s %s\n" "$1" "$2"; else printf "  FAIL  %-52s got %s want %s\n" "$1" "$2" "$3"; fail=1; fi; }
chk "policy: no key -> 401"            "$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 "$P/policy/all")" 401
chk "policy: right key /health -> 200" "$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 -H "x-api-key: $K" "$P/health")" 200
n=$(curl -s --max-time 30 -H "x-api-key: $K" "$P/policy/all" | python3 -c "import sys,json;print(len(json.load(sys.stdin)))" 2>/dev/null)
chk "policy: /policy/all returns every row (Scenario E)" "$([ "${n:-0}" -gt 1 ] && echo many || echo "${n:-none}")" many
MP=${MCP_PATH:-/underwriting}
body='{"jsonrpc":"2.0","id":1,"method":"tools/list"}'
chk "mcp: no bearer -> 401"            "$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 -H 'content-type: application/json' -H 'accept: application/json, text/event-stream' -d "$body" "$M$MP")" 401
tools=$(curl -s --max-time 30 -H "authorization: Bearer $B" -H 'content-type: application/json' -H 'accept: application/json, text/event-stream' -d "$body" "$M$MP" | sed 's/^data: //' | python3 -c "import sys,json;print(','.join(sorted(t['name'] for t in json.loads(sys.stdin.read().strip().splitlines()[-1])['result']['tools'])))" 2>/dev/null)
chk "mcp: tools/list advertises run_query (Scenario C)" "$(echo "$tools" | grep -q run_query && echo yes || echo "no [$tools]")" yes
exit $fail
