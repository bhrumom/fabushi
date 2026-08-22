import { createServer, request as httpRequest } from 'node:http';
import { randomBytes } from 'node:crypto';
import { mkdir, readFile, rename, writeFile } from 'node:fs/promises';
import { homedir } from 'node:os';
import { dirname, resolve } from 'node:path';

const PUBLIC_PORT = Number(process.env.PORT ?? 8787);
const INNER_PORT = Number(process.env.VPS_CONTROL_INNER_PORT ?? PUBLIC_PORT + 1);
const MCP_PREFIX = process.env.MCP_PATH_PREFIX ?? '/mcp';
const CLIENT_STORE = process.env.OAUTH_CLIENT_STORE_PATH
  ?? resolve(homedir(), '.chatgpt-vps-control', 'oauth-clients.json');
const clients = new Map();

if (!Number.isInteger(PUBLIC_PORT) || PUBLIC_PORT <= 0 || PUBLIC_PORT > 65535) {
  throw new Error('PORT must be a valid TCP port');
}
if (!Number.isInteger(INNER_PORT) || INNER_PORT <= 0 || INNER_PORT > 65535 || INNER_PORT === PUBLIC_PORT) {
  throw new Error('VPS_CONTROL_INNER_PORT must be a different valid TCP port');
}

function randomClientId() {
  return `client_${randomBytes(24).toString('base64url')}`;
}

function writeJson(res, status, body) {
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'cache-control': 'no-store',
    'x-content-type-options': 'nosniff',
  });
  res.end(JSON.stringify(body));
}

async function readBody(req, maxBytes = 64 * 1024) {
  const chunks = [];
  let total = 0;
  for await (const chunk of req) {
    total += chunk.length;
    if (total > maxBytes) throw new Error('request body too large');
    chunks.push(chunk);
  }
  return Buffer.concat(chunks);
}

function validRedirectUri(value) {
  try {
    const url = new URL(String(value || ''));
    if (url.username || url.password || url.hash) return false;
    if (url.protocol === 'https:') return Boolean(url.hostname);
    if (url.protocol === 'http:') {
      const host = url.hostname.toLowerCase();
      return host === '127.0.0.1' || host === 'localhost' || host === '[::1]' || host === '::1';
    }
    // Native custom schemes are allowed only when they are explicit and do not
    // carry an authority credential. They remain exact-match registered URIs.
    return /^[a-z][a-z0-9+.-]*:$/.test(url.protocol) && url.protocol !== 'javascript:' && url.protocol !== 'data:';
  } catch {
    return false;
  }
}

async function loadClients() {
  try {
    const payload = JSON.parse(await readFile(CLIENT_STORE, 'utf8'));
    for (const item of payload.clients ?? []) {
      if (!item?.clientId || !Array.isArray(item.redirectUris)) continue;
      const redirects = item.redirectUris.filter(validRedirectUri);
      if (redirects.length === 0) continue;
      clients.set(String(item.clientId), { redirectUris: redirects });
    }
  } catch {
    // First launch or unreadable legacy file: start with an empty registry.
  }
}

async function saveClients() {
  await mkdir(dirname(CLIENT_STORE), { recursive: true });
  const temp = `${CLIENT_STORE}.${process.pid}.${Date.now()}.tmp`;
  const payload = {
    clients: [...clients].map(([clientId, value]) => ({ clientId, redirectUris: value.redirectUris })),
  };
  await writeFile(temp, JSON.stringify(payload, null, 2), { mode: 0o600 });
  await rename(temp, CLIENT_STORE);
}

function publicHost(req) {
  return String(req.headers.host || `127.0.0.1:${PUBLIC_PORT}`).split(',')[0].trim();
}

function proxyHeaders(req, bodyLength = null) {
  const headers = { ...req.headers };
  const host = publicHost(req);
  headers.host = host;
  headers['x-forwarded-host'] = host;
  if (!headers['x-forwarded-proto']) {
    headers['x-forwarded-proto'] = process.env.PUBLIC_SCHEME === 'http' ? 'http' : 'https';
  }
  delete headers.connection;
  delete headers['proxy-connection'];
  if (bodyLength !== null) headers['content-length'] = String(bodyLength);
  return headers;
}

function proxy(req, res, body = null) {
  return new Promise((resolve) => {
    const upstream = httpRequest({
      hostname: '127.0.0.1',
      port: INNER_PORT,
      method: req.method,
      path: req.url,
      headers: proxyHeaders(req, body ? body.length : null),
    }, (upstreamResponse) => {
      const headers = { ...upstreamResponse.headers };
      headers['x-content-type-options'] = 'nosniff';
      res.writeHead(upstreamResponse.statusCode ?? 502, headers);
      upstreamResponse.pipe(res);
      upstreamResponse.on('end', resolve);
    });
    upstream.on('error', (error) => {
      if (!res.headersSent) writeJson(res, 502, { error: 'upstream_unavailable' });
      else res.destroy(error);
      resolve();
    });
    if (body) upstream.end(body);
    else req.pipe(upstream);
  });
}

function rejectUrlCredentials(url) {
  if (url.searchParams.has('token') || url.searchParams.has('access_token')) return true;
  const normalizedPrefix = MCP_PREFIX.replace(/\/+$/, '');
  return url.pathname.startsWith(`${normalizedPrefix}/`) && url.pathname !== normalizedPrefix;
}

async function registerClient(req, res) {
  let body;
  try {
    body = JSON.parse((await readBody(req)).toString('utf8') || '{}');
  } catch {
    return writeJson(res, 400, { error: 'invalid_client_metadata' });
  }
  const redirects = Array.isArray(body.redirect_uris) ? [...new Set(body.redirect_uris.map(String))] : [];
  if (redirects.length === 0 || redirects.length > 16 || redirects.some((value) => !validRedirectUri(value))) {
    return writeJson(res, 400, { error: 'invalid_redirect_uri' });
  }
  const clientId = randomClientId();
  clients.set(clientId, { redirectUris: redirects });
  await saveClients();
  return writeJson(res, 201, {
    client_id: clientId,
    client_id_issued_at: Math.floor(Date.now() / 1000),
    redirect_uris: redirects,
    token_endpoint_auth_method: 'none',
    grant_types: ['authorization_code', 'refresh_token'],
    response_types: ['code'],
  });
}

function validateAuthorize(url) {
  if (url.searchParams.get('response_type') !== 'code') return 'unsupported_response_type';
  const clientId = url.searchParams.get('client_id') || '';
  const registered = clients.get(clientId);
  if (!registered) return 'invalid_client';
  const redirectUri = url.searchParams.get('redirect_uri') || '';
  if (!registered.redirectUris.includes(redirectUri)) return 'invalid_redirect_uri';
  const challenge = url.searchParams.get('code_challenge') || '';
  if (!/^[A-Za-z0-9_-]{43,128}$/.test(challenge)) return 'invalid_code_challenge';
  if (url.searchParams.get('code_challenge_method') !== 'S256') return 'invalid_code_challenge_method';
  return '';
}

async function validateTokenRequest(req, res) {
  const body = await readBody(req);
  const contentType = String(req.headers['content-type'] || '').toLowerCase();
  if (!contentType.includes('application/x-www-form-urlencoded')) {
    writeJson(res, 415, { error: 'invalid_request' });
    return null;
  }
  const params = new URLSearchParams(body.toString('utf8'));
  const grant = params.get('grant_type');
  if (grant === 'authorization_code') {
    const verifier = params.get('code_verifier') || '';
    if (!/^[A-Za-z0-9._~-]{43,128}$/.test(verifier)) {
      writeJson(res, 400, { error: 'invalid_grant', error_description: 'PKCE verifier is required' });
      return null;
    }
    const clientId = params.get('client_id') || '';
    if (!clients.has(clientId)) {
      writeJson(res, 400, { error: 'invalid_client' });
      return null;
    }
  } else if (grant !== 'refresh_token') {
    writeJson(res, 400, { error: 'unsupported_grant_type' });
    return null;
  }
  return body;
}

await loadClients();

// Run the existing MCP implementation on loopback only, behind this security
// boundary. server.js already binds 127.0.0.1; we only change its private port.
process.env.PORT = String(INNER_PORT);
await import('./server.js');

const gateway = createServer(async (req, res) => {
  try {
    const url = new URL(req.url || '/', `http://${publicHost(req)}`);
    if (rejectUrlCredentials(url)) {
      return writeJson(res, 400, { error: 'credentials_must_use_authorization_header' });
    }
    if (url.pathname === '/oauth/register') {
      if (req.method !== 'POST') return writeJson(res, 405, { error: 'method_not_allowed' });
      return await registerClient(req, res);
    }
    if (url.pathname === '/oauth/authorize') {
      if (req.method !== 'GET') return writeJson(res, 405, { error: 'method_not_allowed' });
      const error = validateAuthorize(url);
      if (error) return writeJson(res, 400, { error });
      return await proxy(req, res);
    }
    if (url.pathname === '/oauth/token') {
      if (req.method !== 'POST') return writeJson(res, 405, { error: 'method_not_allowed' });
      const body = await validateTokenRequest(req, res);
      if (!body) return;
      return await proxy(req, res, body);
    }
    return await proxy(req, res);
  } catch (error) {
    console.error('secure gateway request failed:', error?.message || error);
    if (!res.headersSent) writeJson(res, 500, { error: 'internal_error' });
  }
});

gateway.listen(PUBLIC_PORT, '127.0.0.1', () => {
  console.log(`chatgpt-vps-control secure gateway listening on 127.0.0.1:${PUBLIC_PORT}`);
});
