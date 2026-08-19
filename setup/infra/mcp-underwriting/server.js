// FACILITATOR-ONLY. Halcourt Mutual "Underwriting" MCP-style tool server — DELIBERATELY WEAK.
// Simplified stand-in for an MCP server (JSON over HTTP, not full JSON-RPC/SSE) so the workshop can
// demonstrate the tool-boundary failures without a full MCP stack. Weaknesses (by design, Scenario E):
//   1. A single static bearer token authorizes ALL callers (no per-agent / per-user identity).
//   2. It advertises get_quote and get_risk_score (intended) AND run_query (arbitrary) — an over-wide
//      tool schema. run_query returns more than a price.
// Do NOT deploy outside an isolated lab.

const http = require('http');

const BEARER = process.env.MCP_BEARER || 'lab-only-not-a-real-token';

const TOOLS = [
  { name: 'get_quote', description: 'Quote a premium for a risk profile', args: ['profile'] },
  { name: 'get_risk_score', description: 'Score a risk profile', args: ['profile'] },
  // Over-scoped: should never have shipped to an agent that only needs quotes.
  { name: 'run_query', description: 'Run an arbitrary query against the pricing database', args: ['sql'] },
];

function authed(req) {
  return (req.headers['authorization'] || '') === 'Bearer ' + BEARER; // one token for everyone
}

const server = http.createServer((req, res) => {
  const send = (code, body) => {
    res.writeHead(code, { 'content-type': 'application/json' });
    res.end(JSON.stringify(body));
  };
  const url = new URL(req.url, 'http://localhost');

  if (url.pathname === '/health') return send(200, { ok: true });
  if (url.pathname === '/tools') return send(authed(req) ? 200 : 401, authed(req) ? { tools: TOOLS } : { error: 'unauthorized' });

  if (req.method === 'POST' && url.pathname === '/call') {
    if (!authed(req)) return send(401, { error: 'unauthorized' });
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', () => {
      let call = {};
      try { call = JSON.parse(body || '{}'); } catch (_) {}
      if (call.tool === 'get_quote') return send(200, { premium: 1425, currency: 'USD' });
      if (call.tool === 'get_risk_score') return send(200, { score: 0.62 });
      // The over-scoped tool: echoes the "query" and returns broad rows — the boundary problem.
      if (call.tool === 'run_query') return send(200, { query: call.args && call.args.sql, rows: 'ALL pricing + customer risk rows (lab stub)' });
      return send(400, { error: 'unknown tool' });
    });
    return;
  }
  return send(404, { error: 'unknown route' });
});

server.listen(8080, () => console.log('underwriting-mcp (LAB) on :8080'));
