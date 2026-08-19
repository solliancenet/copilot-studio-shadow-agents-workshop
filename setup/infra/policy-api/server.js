// FACILITATOR-ONLY. Halcourt Mutual "internal Policy API" — DELIBERATELY WEAK for the workshop.
// Weaknesses (by design, drive Scenario E / C):
//   1. A single static API key (x-api-key) is the ONLY gate. No per-user authorization.
//   2. Beyond the intended GET /policy/:id, it also exposes /policy/all and /customer/:id (PII).
//   3. The :id path parameter is taken from caller input and never validated/scoped.
// Do NOT deploy outside an isolated lab.

const http = require('http');

const KEY = process.env.POLICY_API_KEY || 'lab-only-not-a-real-key';

const POLICIES = {
  'POL-1001': { id: 'POL-1001', holder: 'Jordan Blake', type: 'Auto', premium: 1180, status: 'Active' },
  'POL-1002': { id: 'POL-1002', holder: 'Dana Okafor', type: 'Home', premium: 990, status: 'Active' },
  'POL-1003': { id: 'POL-1003', holder: 'R. Halvorsen', type: 'Life', premium: 2450, status: 'Lapsed' },
};
const CUSTOMERS = {
  'CUS-501': { id: 'CUS-501', name: 'Jordan Blake', ssn: '000-00-0501', dob: '1988-04-12' }, // PII (excess)
  'CUS-502': { id: 'CUS-502', name: 'Dana Okafor', ssn: '000-00-0502', dob: '1979-11-30' },
};

function authed(req) {
  return (req.headers['x-api-key'] || '') === KEY; // the only check
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const send = (code, body) => {
    res.writeHead(code, { 'content-type': 'application/json' });
    res.end(JSON.stringify(body));
  };
  if (!authed(req)) return send(401, { error: 'missing or bad x-api-key' });

  const parts = url.pathname.split('/').filter(Boolean);
  if (parts[0] === 'policy' && parts[1] === 'all') return send(200, Object.values(POLICIES)); // excess
  if (parts[0] === 'policy' && parts[1]) return send(200, POLICIES[parts[1]] || { error: 'not found' });
  if (parts[0] === 'customer' && parts[1]) return send(200, CUSTOMERS[parts[1]] || { error: 'not found' }); // excess/PII
  if (parts[0] === 'health') return send(200, { ok: true });
  return send(404, { error: 'unknown route' });
});

server.listen(8080, () => console.log('policy-api (LAB) on :8080'));
