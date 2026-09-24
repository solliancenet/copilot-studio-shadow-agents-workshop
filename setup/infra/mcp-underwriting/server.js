// FACILITATOR-ONLY. Halcourt Mutual "Underwriting" MCP server — DELIBERATELY WEAK.
// A real Model Context Protocol server (JSON-RPC 2.0 over the Streamable HTTP transport) so Copilot Studio
// can import it as an MCP tool. Weaknesses are intentional (Scenario E):
//   1. A single static bearer token authorizes ALL callers (no per-agent / per-user identity).
//   2. It advertises get_quote and get_risk_score (intended) AND run_query (arbitrary) — an over-wide tool
//      surface. run_query returns more than a price.
// Do NOT deploy outside an isolated lab.

const http = require('http');

const BEARER = process.env.MCP_BEARER || 'lab-only-not-a-real-token';
const BASE = '/underwriting'; // the agent points at https://<mcp-fqdn>/underwriting

const TOOLS = [
  {
    name: 'get_quote',
    description: 'Quote a premium for a risk profile.',
    inputSchema: { type: 'object', properties: { profile: { type: 'string', description: 'Risk profile' } }, required: ['profile'] },
  },
  {
    name: 'get_risk_score',
    description: 'Score a risk profile.',
    inputSchema: { type: 'object', properties: { profile: { type: 'string', description: 'Risk profile' } }, required: ['profile'] },
  },
  {
    // Over-scoped: should never have shipped to an agent that only needs quotes.
    name: 'run_query',
    description: 'Run an arbitrary query against the pricing database.',
    inputSchema: { type: 'object', properties: { sql: { type: 'string', description: 'SQL query' } }, required: ['sql'] },
  },
];

function callTool(name, args) {
  if (name === 'get_quote') return { premium: 1425, currency: 'USD' };
  if (name === 'get_risk_score') return { score: 0.62 };
  // The over-scoped tool: echoes the query and returns broad rows — the boundary problem.
  if (name === 'run_query') return { query: (args && args.sql) || null, rows: 'ALL pricing + customer risk rows (lab stub)' };
  return null;
}

function authed(req) {
  return (req.headers['authorization'] || '') === 'Bearer ' + BEARER; // one token for everyone
}

// Handle one JSON-RPC message. Returns a response object, or null for notifications (no reply).
function handleRpc(msg) {
  const { id, method, params } = msg;
  const ok = (result) => ({ jsonrpc: '2.0', id, result });
  const err = (code, message) => ({ jsonrpc: '2.0', id, error: { code, message } });

  if (method === 'initialize') {
    return ok({
      protocolVersion: (params && params.protocolVersion) || '2025-06-18',
      capabilities: { tools: { listChanged: false } },
      serverInfo: { name: 'halcourt-underwriting', version: '1.0.0' },
    });
  }
  if (method === 'notifications/initialized' || method === 'notifications/cancelled') return null; // notification
  if (method === 'ping') return ok({});
  if (method === 'tools/list') return ok({ tools: TOOLS });
  if (method === 'tools/call') {
    const name = params && params.name;
    if (!TOOLS.some((t) => t.name === name)) return err(-32602, 'Unknown tool: ' + name);
    const out = callTool(name, params && params.arguments);
    return ok({ content: [{ type: 'text', text: JSON.stringify(out) }], isError: false });
  }
  if (typeof id === 'undefined') return null; // unknown notification
  return err(-32601, 'Method not found: ' + method);
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const send = (code, body, type) => {
    res.writeHead(code, { 'content-type': type || 'application/json' });
    res.end(typeof body === 'string' ? body : JSON.stringify(body));
  };

  if (url.pathname === '/health') return send(200, { ok: true });
  if (url.pathname !== BASE) return send(404, { error: 'unknown route' });

  // Streamable HTTP: the client MAY open a GET SSE stream for server-initiated messages. This stateless
  // server has none, so accept and keep it open harmlessly.
  if (req.method === 'GET') {
    if (!authed(req)) return send(401, { error: 'unauthorized' });
    res.writeHead(200, { 'content-type': 'text/event-stream', 'cache-control': 'no-cache', connection: 'keep-alive' });
    res.write(': connected\n\n');
    return; // stays open
  }

  if (req.method === 'POST') {
    if (!authed(req)) return send(401, { error: 'unauthorized' });
    let body = '';
    req.on('data', (c) => (body += c));
    req.on('end', () => {
      let msg;
      try { msg = JSON.parse(body || '{}'); } catch (_) { return send(400, { jsonrpc: '2.0', id: null, error: { code: -32700, message: 'Parse error' } }); }
      const replies = (Array.isArray(msg) ? msg : [msg]).map(handleRpc).filter(Boolean);
      if (replies.length === 0) { res.writeHead(202); return res.end(); } // only notifications
      return send(200, Array.isArray(msg) ? replies : replies[0]);
    });
    return;
  }
  return send(405, { error: 'method not allowed' });
});

server.listen(8080, () => console.log('underwriting-mcp (LAB, MCP over Streamable HTTP) on :8080' + BASE));
