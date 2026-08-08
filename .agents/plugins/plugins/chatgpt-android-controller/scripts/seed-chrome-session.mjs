#!/usr/bin/env node
import { spawnSync } from 'node:child_process';

const CHROME_PACKAGE = process.env.CHATGPT_ANDROID_CHROME_PACKAGE || 'com.android.chrome';
const SERIAL = process.env.ANDROID_SERIAL || '';
const CDP_PORT = Number(process.env.CHATGPT_ANDROID_CHROME_CDP_PORT || 9222);
const SESSION_B64 = process.env.CHATGPT_SESSION_COOKIES_B64 || '';
const sleep = ms => new Promise(resolvePromise => setTimeout(resolvePromise, ms));

function trace(stage, detail = {}) {
  process.stdout.write(`[android-browser-seed] ${stage} ${JSON.stringify(detail)}\n`);
}

function run(binary, args, timeout = 30_000) {
  const result = spawnSync(binary, args, {
    encoding: 'utf8',
    timeout,
    maxBuffer: 32 * 1024 * 1024,
  });
  return {
    ok: !result.error && result.status === 0,
    stdout: String(result.stdout || ''),
    stderr: String(result.stderr || ''),
  };
}

function adb(args, timeout = 30_000) {
  const prefix = SERIAL ? ['-s', SERIAL] : [];
  return run(process.env.CHATGPT_ANDROID_ADB || 'adb', [...prefix, ...args], timeout);
}

function adbShell(args, timeout = 30_000) {
  return adb(['shell', ...args], timeout);
}

function foregroundPackage() {
  const activity = adbShell(['dumpsys', 'activity', 'activities']);
  const text = activity.ok ? activity.stdout : '';
  return text.match(/mResumedActivity:.*?\s([A-Za-z0-9._]+)\//)?.[1]
    || text.match(/topResumedActivity=.*?\s([A-Za-z0-9._]+)\//)?.[1]
    || null;
}

function decodeXml(value) {
  return String(value || '')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .replaceAll('&amp;', '&');
}

function dumpNodes() {
  const remote = `/sdcard/chrome-seed-${process.pid}.xml`;
  const dump = adbShell(['uiautomator', 'dump', remote], 20_000);
  if (!dump.ok) return [];
  const read = adb(['exec-out', 'cat', remote], 20_000);
  void adbShell(['rm', '-f', remote]);
  if (!read.ok) return [];
  const nodes = [];
  for (const match of read.stdout.matchAll(/<node\b([^>]*)\/?>(?:<\/node>)?/g)) {
    const attrs = new Map();
    for (const attr of match[1].matchAll(/([\w:-]+)="([^"]*)"/g)) attrs.set(attr[1], decodeXml(attr[2]));
    const bounds = String(attrs.get('bounds') || '').match(/^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/);
    nodes.push({
      text: attrs.get('text') || '',
      description: attrs.get('content-desc') || '',
      packageName: attrs.get('package') || '',
      enabled: attrs.get('enabled') !== 'false',
      bounds: bounds ? [Number(bounds[1]), Number(bounds[2]), Number(bounds[3]), Number(bounds[4])] : null,
    });
  }
  return nodes;
}

function normalize(value) {
  return String(value || '').replace(/\s+/g, ' ').trim().toLocaleLowerCase();
}

function tapNode(node) {
  if (!node?.bounds) return false;
  const [x1, y1, x2, y2] = node.bounds;
  return adbShell(['input', 'tap', String(Math.round((x1 + x2) / 2)), String(Math.round((y1 + y2) / 2))]).ok;
}

async function clickKnown(labels) {
  const normalized = labels.map(normalize);
  const node = dumpNodes().find(item => {
    if (!item.enabled || !item.bounds) return false;
    const values = [normalize(item.text), normalize(item.description)].filter(Boolean);
    return normalized.some(label => values.some(value => value.includes(label)));
  });
  if (!node || !tapNode(node)) return false;
  await sleep(700);
  return true;
}

async function dismissChromeFirstRun() {
  const accept = ['Accept & continue', 'Accept and continue', 'Agree & continue', '接受并继续', '接受並繼續', '同意并继续', '同意並繼續'];
  const skip = ['Use without an account', 'Continue without an account', 'No thanks', 'Not now', 'Skip', '不使用账号', '不使用帳號', '不用账号', '不用帳號', '暂不', '暫不', '跳过', '跳過'];
  let clicks = 0;
  for (let round = 0; round < 8; round += 1) {
    if (foregroundPackage() !== CHROME_PACKAGE) break;
    const accepted = await clickKnown(accept);
    const skipped = await clickKnown(skip);
    if (accepted) clicks += 1;
    if (skipped) clicks += 1;
    if (!accepted && !skipped) break;
    await sleep(500);
  }
  trace('chrome-first-run', { clicks });
}

function decodeCookies() {
  if (!SESSION_B64.trim()) throw new Error('CHATGPT_SESSION_COOKIES_B64 is empty');
  const parsed = JSON.parse(Buffer.from(SESSION_B64.trim(), 'base64').toString('utf8'));
  const cookies = Array.isArray(parsed?.cookies) ? parsed.cookies : [];
  const normalized = cookies.flatMap(cookie => {
    const domain = String(cookie?.domain || '');
    const lower = domain.toLowerCase().replace(/^\./, '');
    const allowed = lower === 'chatgpt.com' || lower.endsWith('.chatgpt.com')
      || lower === 'openai.com' || lower.endsWith('.openai.com');
    if (!allowed || !cookie?.name || !cookie?.value) return [];
    const item = {
      name: String(cookie.name),
      value: String(cookie.value),
      domain,
      path: String(cookie.path || '/'),
      secure: cookie.secure !== false,
      httpOnly: cookie.httpOnly === true,
    };
    if (['Strict', 'Lax', 'None'].includes(cookie.sameSite)) item.sameSite = cookie.sameSite;
    if (Number(cookie.expires) > 0) item.expires = Number(cookie.expires);
    return [item];
  });
  if (!normalized.length) throw new Error('No ChatGPT/OpenAI cookies were decoded');
  trace('credential-decoded', { cookieCount: normalized.length, domainCount: new Set(normalized.map(item => item.domain)).size });
  return normalized;
}

function devtoolsSockets() {
  const result = adbShell(['cat', '/proc/net/unix'], 10_000);
  if (!result.ok) return [];
  const sockets = [];
  for (const line of result.stdout.split(/\r?\n/)) {
    const match = line.match(/@([^\s]*devtools_remote[^\s]*)\s*$/i);
    if (match?.[1]) sockets.push(match[1]);
  }
  return [...new Set(sockets)].sort((a, b) => (a === 'chrome_devtools_remote' ? -1 : 0) - (b === 'chrome_devtools_remote' ? -1 : 0));
}

async function fetchTargets() {
  try {
    const response = await fetch(`http://127.0.0.1:${CDP_PORT}/json/list`, { signal: AbortSignal.timeout(2500) });
    if (!response.ok) return [];
    const value = await response.json();
    return Array.isArray(value) ? value : [];
  } catch {
    return [];
  }
}

async function discoverChromeTarget(timeoutMs = 30_000) {
  const deadline = Date.now() + timeoutMs;
  let lastSockets = [];
  while (Date.now() < deadline) {
    lastSockets = devtoolsSockets();
    for (const socketName of lastSockets) {
      void adb(['forward', '--remove', `tcp:${CDP_PORT}`], 5000);
      const forward = adb(['forward', `tcp:${CDP_PORT}`, `localabstract:${socketName}`], 10_000);
      if (!forward.ok) continue;
      const targets = await fetchTargets();
      const target = targets.find(item => item?.webSocketDebuggerUrl && /chatgpt|openai/i.test(String(item.url || '')))
        || targets.find(item => item?.webSocketDebuggerUrl && item.type === 'page')
        || targets.find(item => item?.webSocketDebuggerUrl);
      if (target) return { socketName, target };
    }
    await sleep(500);
  }
  throw new Error(`Chrome did not expose a CDP page; sockets=${lastSockets.join(',') || 'none'}`);
}

async function connectCdp(wsUrl) {
  const socket = new WebSocket(wsUrl);
  await new Promise((resolvePromise, reject) => {
    const timer = setTimeout(() => reject(new Error('Chrome CDP connect timeout')), 10_000);
    socket.addEventListener('open', () => { clearTimeout(timer); resolvePromise(); }, { once: true });
    socket.addEventListener('error', () => { clearTimeout(timer); reject(new Error('Chrome CDP connect failed')); }, { once: true });
  });
  let sequence = 0;
  const call = (method, params = {}, timeout = 20_000) => new Promise((resolvePromise, reject) => {
    const id = ++sequence;
    const timer = setTimeout(() => {
      socket.removeEventListener('message', onMessage);
      reject(new Error(`${method} timeout`));
    }, timeout);
    const onMessage = event => {
      let message;
      try { message = JSON.parse(String(event.data)); } catch { return; }
      if (message.id !== id) return;
      clearTimeout(timer);
      socket.removeEventListener('message', onMessage);
      if (message.error) reject(new Error(`${method} failed`));
      else resolvePromise(message.result || {});
    };
    socket.addEventListener('message', onMessage);
    socket.send(JSON.stringify({ id, method, params }));
  });
  return { socket, call };
}

async function seedChromeSession() {
  const cookies = decodeCookies();
  const launch = adbShell(['am', 'start', '-W', '-a', 'android.intent.action.VIEW', '-d', 'https://chatgpt.com/', '-p', CHROME_PACKAGE], 30_000);
  if (!launch.ok) throw new Error('Unable to launch Chrome for session seeding');
  await sleep(1500);
  await dismissChromeFirstRun();

  // Re-open after first-run UI is cleared so Chrome definitely owns a normal tab.
  adbShell(['am', 'start', '-W', '-a', 'android.intent.action.VIEW', '-d', 'https://chatgpt.com/', '-p', CHROME_PACKAGE], 30_000);
  await sleep(1500);
  const { socketName, target } = await discoverChromeTarget();
  const connection = await connectCdp(target.webSocketDebuggerUrl);
  try {
    await connection.call('Network.enable');
    const set = await connection.call('Network.setCookies', { cookies });
    if (set?.success === false) throw new Error('Chrome rejected restored cookies');
    const stored = await connection.call('Network.getAllCookies');
    const matching = Array.isArray(stored.cookies)
      ? stored.cookies.filter(cookie => /(^|\.)chatgpt\.com$|(^|\.)openai\.com$/i.test(String(cookie.domain || ''))).length
      : 0;
    await connection.call('Page.navigate', { url: 'https://chatgpt.com/' }, 20_000);
    await sleep(5000);
    trace('session-seeded', {
      socketName,
      restoredCookieCount: matching,
      foregroundPackage: foregroundPackage(),
    });
  } finally {
    connection.socket.close();
  }
  adbShell(['input', 'keyevent', '3']);
  return { ok: true };
}

try {
  const result = await seedChromeSession();
  process.stdout.write(`${JSON.stringify(result)}\n`);
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  trace('fatal', { message });
  process.stdout.write(`${JSON.stringify({ ok: false, errorCode: 'chrome_session_seed_failed', message })}\n`);
  process.exitCode = 1;
}
