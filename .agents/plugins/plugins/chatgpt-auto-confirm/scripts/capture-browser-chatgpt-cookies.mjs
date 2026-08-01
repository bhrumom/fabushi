import { readFile, writeFile } from 'node:fs/promises';

function parseArguments(argv) {
  const values = {};
  for (let index = 0; index < argv.length; index += 1) {
    const item = argv[index];
    if (!item.startsWith('--')) continue;
    values[item.slice(2)] = argv[index + 1] && !argv[index + 1].startsWith('--')
      ? argv[++index]
      : true;
  }
  return values;
}

const args = parseArguments(process.argv.slice(2));
const port = Number(args.port);
const outputPath = String(args.output || '');
const authPath = String(args.auth || '');
const timeoutMs = Math.min(120_000, Math.max(10_000, Number(args.timeoutMs || 60_000)));

const sleep = milliseconds => new Promise(resolve => setTimeout(resolve, milliseconds));

function decodeJwtPayload(token) {
  const segment = String(token || '').split('.')[1];
  if (!segment) throw new Error('Codex OAuth id token is incomplete');
  const normalized = segment.replace(/-/g, '+').replace(/_/g, '/').padEnd(
    Math.ceil(segment.length / 4) * 4,
    '=',
  );
  return JSON.parse(Buffer.from(normalized, 'base64').toString('utf8'));
}

function identityFromAuth(auth) {
  const tokens = auth?.tokens || {};
  const claims = decodeJwtPayload(tokens.id_token);
  const openAiClaims = claims['https://api.openai.com/auth'] || {};
  const accountId = String(tokens.account_id || openAiClaims.chatgpt_account_id || '');
  const userId = String(openAiClaims.chatgpt_user_id || '');
  const email = String(claims.email || openAiClaims.email || '').toLowerCase();
  if (!accountId || !userId) throw new Error('Codex OAuth identity is incomplete');
  return {
    ids: new Set([accountId, userId]),
    emails: email ? new Set([email]) : new Set(),
  };
}

async function listTargets() {
  const response = await fetch(`http://127.0.0.1:${port}/json/list`, {
    signal: AbortSignal.timeout(5_000),
  });
  if (!response.ok) throw new Error('browser debugging endpoint returned an error');
  return response.json();
}

async function waitForTargets() {
  const deadline = Date.now() + timeoutMs;
  let lastTargets = [];
  while (Date.now() < deadline) {
    try {
      lastTargets = await listTargets();
      const pages = lastTargets.filter(item => item.type === 'page' && item.webSocketDebuggerUrl);
      if (pages.length > 0) return pages;
    } catch {}
    await sleep(500);
  }
  throw new Error(`isolated browser debugging endpoint was not ready (targets=${lastTargets.length})`);
}

async function connect(target) {
  const socket = new WebSocket(target.webSocketDebuggerUrl);
  await new Promise((resolve, reject) => {
    const timer = setTimeout(() => {
      socket.close();
      reject(new Error('browser debugging connection timed out'));
    }, 15_000);
    socket.addEventListener('open', () => {
      clearTimeout(timer);
      resolve();
    }, { once: true });
    socket.addEventListener('error', () => {
      clearTimeout(timer);
      reject(new Error('browser debugging connection failed'));
    }, { once: true });
  });
  let sequence = 0;
  const call = (method, params = {}) => new Promise((resolve, reject) => {
    const id = ++sequence;
    const timer = setTimeout(() => {
      socket.removeEventListener('message', onMessage);
      reject(new Error(`${method} timed out`));
    }, 20_000);
    const onMessage = event => {
      let message;
      try {
        message = JSON.parse(String(event.data));
      } catch {
        return;
      }
      if (message.id !== id) return;
      clearTimeout(timer);
      socket.removeEventListener('message', onMessage);
      if (message.error) {
        reject(new Error(`${method} failed`));
      } else {
        resolve(message.result || {});
      }
    };
    socket.addEventListener('message', onMessage);
    try {
      socket.send(JSON.stringify({ id, method, params }));
    } catch {
      clearTimeout(timer);
      socket.removeEventListener('message', onMessage);
      reject(new Error(`${method} could not be sent`));
    }
  });
  return { socket, call };
}

function normalizeCookie(cookie) {
  const domain = String(cookie.domain || '').toLowerCase().replace(/^\./, '');
  if (!/(^|\.)((chatgpt|openai)\.com)$/.test(domain)) return null;
  if (!cookie.name || !cookie.value) return null;
  const normalized = {
    name: String(cookie.name),
    value: String(cookie.value),
    domain: String(cookie.domain),
    path: String(cookie.path || '/'),
    secure: Boolean(cookie.secure),
    httpOnly: Boolean(cookie.httpOnly),
    sameSite: ['Strict', 'Lax', 'None'].includes(cookie.sameSite)
      ? cookie.sameSite
      : 'Lax',
  };
  if (!cookie.session && Number.isFinite(Number(cookie.expires)) && Number(cookie.expires) > 0) {
    normalized.expires = Number(cookie.expires);
  }
  return normalized;
}

async function collectCookies(targets) {
  const cookies = new Map();
  for (const target of targets) {
    let connection;
    try {
      connection = await connect(target);
      const result = await connection.call('Network.getAllCookies');
      for (const cookie of result.cookies || []) {
        const normalized = normalizeCookie(cookie);
        if (!normalized) continue;
        cookies.set(`${normalized.domain}|${normalized.path}|${normalized.name}`, normalized);
      }
    } catch {
      // A tab can disappear during the OAuth redirect; the other tabs are enough.
    } finally {
      try { connection?.socket.close(); } catch {}
    }
  }
  if (cookies.size === 0) throw new Error('the isolated browser has no ChatGPT session cookies');
  return [...cookies.values()];
}

function observedIdentity(session) {
  const ids = new Set();
  const emails = new Set();
  const visit = value => {
    if (!value || typeof value !== 'object') return;
    if (Array.isArray(value)) {
      value.forEach(visit);
      return;
    }
    for (const [key, item] of Object.entries(value)) {
      if (item && typeof item === 'object') visit(item);
      if (item == null) continue;
      if (['id', 'user_id', 'account_id', 'chatgpt_user_id', 'chatgpt_account_id'].includes(key)) {
        ids.add(String(item));
      }
      if (key === 'email') emails.add(String(item).toLowerCase());
    }
  };
  visit(session);
  return { ids, emails };
}

async function verifyAccount(cookies, identity) {
  const cookieHeader = cookies.map(cookie => `${cookie.name}=${cookie.value}`).join('; ');
  const response = await fetch('https://chatgpt.com/api/auth/session', {
    headers: {
      Accept: 'application/json',
      Cookie: cookieHeader,
      'User-Agent': 'Mozilla/5.0 Fabushi credential sync',
    },
    signal: AbortSignal.timeout(20_000),
  });
  if (!response.ok) throw new Error('ChatGPT web session verification failed');
  const session = await response.json();
  const observed = observedIdentity(session);
  const idMatch = [...observed.ids].some(value => identity.ids.has(value));
  const emailMatch = identity.emails.size > 0
    && [...observed.emails].some(value => identity.emails.has(value));
  if (!idMatch && !emailMatch) {
    throw new Error('ChatGPT web session belongs to a different account or is not signed in');
  }
}

async function main() {
  if (!Number.isInteger(port) || port < 1 || !outputPath || !authPath) {
    throw new Error('browser cookie capture arguments are incomplete');
  }
  const auth = JSON.parse(await readFile(authPath, 'utf8'));
  const identity = identityFromAuth(auth);
  const targets = await waitForTargets();
  const cookies = await collectCookies(targets);
  await verifyAccount(cookies, identity);
  await writeFile(outputPath, JSON.stringify({ cookies }), 'utf8');
  process.stdout.write(JSON.stringify({
    ok: true,
    cookieCount: cookies.length,
    credentialSource: 'isolated-browser',
    browserSources: ['isolated-browser'],
    accountVerified: true,
  }));
}

try {
  await main();
} catch (error) {
  process.stdout.write(JSON.stringify({
    ok: false,
    errorCode: 'chatgpt_browser_cookie_capture_failed',
    message: error instanceof Error ? error.message : 'browser cookie capture failed',
  }));
  process.exitCode = 1;
}
