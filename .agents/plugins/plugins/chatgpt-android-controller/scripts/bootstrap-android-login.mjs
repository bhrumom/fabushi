#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import { mkdirSync, appendFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const CHATGPT_PACKAGE = process.env.CHATGPT_ANDROID_PACKAGE || 'com.openai.chatgpt';
const CHROME_PACKAGE = process.env.CHATGPT_ANDROID_CHROME_PACKAGE || 'com.android.chrome';
const SERIAL = process.env.ANDROID_SERIAL || '';
const CDP_PORT = Number(process.env.CHATGPT_ANDROID_CHROME_CDP_PORT || 9222);
const DIAGNOSTICS_DIR = resolve(process.env.CHATGPT_ANDROID_DIAGNOSTICS_DIR || './android-login-diagnostics');
const TRACE_PATH = resolve(process.env.CHATGPT_ANDROID_TRACE_PATH || `${DIAGNOSTICS_DIR}/trace.jsonl`);
const SESSION_B64 = process.env.CHATGPT_SESSION_COOKIES_B64 || '';
const MODE = process.env.CHATGPT_ANDROID_LOGIN_MODE || 'web-session';

mkdirSync(DIAGNOSTICS_DIR, { recursive: true, mode: 0o700 });
mkdirSync(dirname(TRACE_PATH), { recursive: true, mode: 0o700 });

const now = () => new Date().toISOString();
const sleep = ms => new Promise(resolvePromise => setTimeout(resolvePromise, ms));

function trace(stage, detail = {}) {
  const row = { at: now(), stage, ...detail };
  appendFileSync(TRACE_PATH, `${JSON.stringify(row)}\n`, { mode: 0o600 });
  process.stdout.write(`[android-login] ${stage} ${JSON.stringify(detail)}\n`);
}

function run(binary, args, timeout = 30_000) {
  const result = spawnSync(binary, args, {
    encoding: 'utf8', timeout, maxBuffer: 32 * 1024 * 1024,
  });
  return {
    ok: !result.error && result.status === 0,
    status: result.status,
    stdout: String(result.stdout || ''),
    stderr: String(result.stderr || result.error || ''),
  };
}

function adb(args, timeout = 30_000) {
  const prefix = SERIAL ? ['-s', SERIAL] : [];
  return run(process.env.CHATGPT_ANDROID_ADB || 'adb', [...prefix, ...args], timeout);
}

function adbShell(args, timeout = 30_000) {
  return adb(['shell', ...args], timeout);
}

function safePackageState() {
  const result = adbShell(['dumpsys', 'window', 'windows']);
  const text = result.ok ? result.stdout : '';
  const match = text.match(/mCurrentFocus=Window\{[^}]*\s([A-Za-z0-9._]+)\//)
    || text.match(/mFocusedApp=.*\s([A-Za-z0-9._]+)\//);
  return match?.[1] || '';
}

function screenshot(label) {
  const result = adb(['exec-out', 'screencap', '-p'], 20_000);
  if (!result.ok || !result.stdout) return null;
  // spawnSync with utf8 is not binary-safe, so use shell redirection only in the
  // workflow for full screenshots. Keep this helper as a marker for local runs.
  trace('screenshot-marker', { label, foregroundPackage: safePackageState() || null });
  return null;
}

function captureScreenshotBinary(label) {
  const filename = `${DIAGNOSTICS_DIR}/${label}.png`;
  const args = SERIAL
    ? ['-s', SERIAL, 'exec-out', 'screencap', '-p']
    : ['exec-out', 'screencap', '-p'];
  const result = spawnSync(process.env.CHATGPT_ANDROID_ADB || 'adb', args, {
    encoding: null, timeout: 20_000, maxBuffer: 32 * 1024 * 1024,
  });
  if (result.error || result.status !== 0 || !result.stdout?.length) return null;
  writeFileSync(filename, result.stdout, { mode: 0o600 });
  trace('screenshot', { label, filename: label + '.png', bytes: result.stdout.length });
  return filename;
}

function decodeXml(value) {
  return String(value || '')
    .replaceAll('&quot;', '"').replaceAll('&apos;', "'")
    .replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&amp;', '&');
}

export function parseUiNodes(xml) {
  const nodes = [];
  for (const match of String(xml || '').matchAll(/<node\b([^>]*)\/?>(?:<\/node>)?/g)) {
    const attrs = new Map();
    for (const attr of match[1].matchAll(/([\w:-]+)="([^"]*)"/g)) {
      attrs.set(attr[1], decodeXml(attr[2]));
    }
    const bounds = String(attrs.get('bounds') || '').match(/^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/);
    nodes.push({
      text: attrs.get('text') || '',
      description: attrs.get('content-desc') || '',
      packageName: attrs.get('package') || '',
      className: attrs.get('class') || '',
      enabled: attrs.get('enabled') !== 'false',
      clickable: attrs.get('clickable') === 'true',
      editable: attrs.get('editable') === 'true' || String(attrs.get('class') || '').includes('EditText'),
      bounds: bounds ? [Number(bounds[1]), Number(bounds[2]), Number(bounds[3]), Number(bounds[4])] : null,
    });
  }
  return nodes;
}

function dumpUi() {
  const remote = `/sdcard/chatgpt-login-${process.pid}.xml`;
  const dumped = adbShell(['uiautomator', 'dump', remote], 15_000);
  if (!dumped.ok) return [];
  const content = adb(['exec-out', 'cat', remote], 15_000);
  void adbShell(['rm', '-f', remote]);
  return content.ok ? parseUiNodes(content.stdout) : [];
}

function normalize(value) {
  return String(value || '').replace(/\s+/g, ' ').trim().toLocaleLowerCase();
}

function nodeMatches(node, labels, contains = false) {
  const values = [normalize(node.text), normalize(node.description)].filter(Boolean);
  return labels.some(label => values.some(value => contains
    ? value.includes(normalize(label))
    : value === normalize(label)));
}

function tapNode(node) {
  if (!node?.bounds) return false;
  const [x1, y1, x2, y2] = node.bounds;
  const x = Math.round((x1 + x2) / 2);
  const y = Math.round((y1 + y2) / 2);
  const result = adbShell(['input', 'tap', String(x), String(y)]);
  return result.ok;
}

async function clickLabels(labels, { contains = false, attempts = 3 } = {}) {
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    const nodes = dumpUi();
    const node = nodes.find(item => item.enabled && item.bounds && nodeMatches(item, labels, contains));
    if (node && tapNode(node)) {
      trace('ui-click', {
        labels,
        packageName: node.packageName || null,
        className: node.className || null,
        attempt,
      });
      await sleep(700);
      return true;
    }
    await sleep(500);
  }
  return false;
}

function packageInstalled(packageName) {
  const result = adbShell(['pm', 'path', packageName]);
  return result.ok && result.stdout.includes('package:');
}

function launchUrlInChrome(url) {
  const result = adbShell([
    'am', 'start', '-W', '-a', 'android.intent.action.VIEW', '-d', url, CHROME_PACKAGE,
  ], 30_000);
  if (!result.ok) throw new Error(result.stderr.trim() || 'Unable to launch Chrome');
}

async function dismissChromeFirstRun() {
  const primary = [
    'Accept & continue', 'Accept and continue', '接受并继续', '接受並繼續',
    '同意并继续', '同意並繼續', 'Agree & continue',
  ];
  const secondary = [
    'No thanks', 'Not now', 'Skip', '不用了', '暂不', '暫不', '跳过', '跳過',
  ];
  for (let round = 0; round < 5; round += 1) {
    const clickedPrimary = await clickLabels(primary, { contains: true, attempts: 1 });
    const clickedSecondary = await clickLabels(secondary, { contains: true, attempts: 1 });
    if (!clickedPrimary && !clickedSecondary) break;
  }
}

export function normalizeSessionCookies(raw) {
  const parsed = typeof raw === 'string' ? JSON.parse(raw) : raw;
  const cookies = Array.isArray(parsed?.cookies) ? parsed.cookies : [];
  return cookies.flatMap(cookie => {
    const domain = String(cookie?.domain || '');
    const lower = domain.toLowerCase().replace(/^\./, '');
    const allowed = lower === 'chatgpt.com' || lower.endsWith('.chatgpt.com')
      || lower === 'openai.com' || lower.endsWith('.openai.com');
    if (!allowed || !cookie?.name || !cookie?.value) return [];
    const normalizedCookie = {
      name: String(cookie.name),
      value: String(cookie.value),
      domain,
      path: String(cookie.path || '/'),
      secure: cookie.secure !== false,
      httpOnly: cookie.httpOnly === true,
    };
    if (['Strict', 'Lax', 'None'].includes(cookie.sameSite)) normalizedCookie.sameSite = cookie.sameSite;
    if (Number(cookie.expires) > 0) normalizedCookie.expires = Number(cookie.expires);
    return [normalizedCookie];
  });
}

function sessionCookiesFromEnvironment() {
  if (!SESSION_B64.trim()) throw new Error('CHATGPT_SESSION_COOKIES_B64 is empty');
  const decoded = Buffer.from(SESSION_B64.trim(), 'base64').toString('utf8');
  const cookies = normalizeSessionCookies(decoded);
  if (!cookies.length) throw new Error('No allowed ChatGPT/OpenAI session cookies were decoded');
  const domainClasses = [...new Set(cookies.map(cookie => {
    const domain = cookie.domain.toLowerCase();
    return domain.includes('chatgpt.com') ? 'chatgpt.com' : 'openai.com';
  }))];
  trace('credential-decoded', { cookieCount: cookies.length, domainClasses });
  return cookies;
}

async function connectCdp(wsUrl) {
  const socket = new WebSocket(wsUrl);
  await new Promise((resolvePromise, reject) => {
    const timer = setTimeout(() => reject(new Error('CDP connection timed out')), 10_000);
    socket.addEventListener('open', () => { clearTimeout(timer); resolvePromise(); }, { once: true });
    socket.addEventListener('error', () => { clearTimeout(timer); reject(new Error('CDP connection failed')); }, { once: true });
  });
  let sequence = 0;
  const call = (method, params = {}, timeout = 20_000) => new Promise((resolvePromise, reject) => {
    const id = ++sequence;
    const timer = setTimeout(() => {
      socket.removeEventListener('message', onMessage);
      reject(new Error(`${method} timed out`));
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

async function waitForChromeTarget(timeoutMs = 30_000) {
  const deadline = Date.now() + timeoutMs;
  let last = [];
  while (Date.now() < deadline) {
    try {
      const response = await fetch(`http://127.0.0.1:${CDP_PORT}/json/list`, {
        signal: AbortSignal.timeout(3_000),
      });
      if (response.ok) {
        last = await response.json();
        const target = last.find(item => item.type === 'page' && item.webSocketDebuggerUrl);
        if (target) return target;
      }
    } catch {}
    await sleep(500);
  }
  throw new Error(`Chrome CDP target not available; targets=${last.length}`);
}

async function establishChromeCdp() {
  const forwarded = adb(['forward', `tcp:${CDP_PORT}`, 'localabstract:chrome_devtools_remote']);
  if (!forwarded.ok) throw new Error(forwarded.stderr.trim() || 'Unable to forward Chrome CDP socket');
  trace('chrome-cdp-forwarded', { port: CDP_PORT });
}

async function injectAndVerifyWebSession(cookies) {
  await establishChromeCdp();
  let target = await waitForChromeTarget();
  let connection = await connectCdp(target.webSocketDebuggerUrl);
  try {
    await connection.call('Network.enable');
    const setResult = await connection.call('Network.setCookies', { cookies });
    if (setResult.success === false) throw new Error('Chrome rejected the session cookie batch');
    trace('chrome-cookies-injected', { cookieCount: cookies.length });
    await connection.call('Page.navigate', { url: 'https://chatgpt.com/' }, 20_000);
  } finally {
    connection.socket.close();
  }

  await sleep(6_000);
  target = await waitForChromeTarget();
  connection = await connectCdp(target.webSocketDebuggerUrl);
  try {
    const evaluation = await connection.call('Runtime.evaluate', {
      expression: `(async () => {
        const normalize = value => (value || '').replace(/\\s+/g, ' ').trim();
        const text = normalize(document.body?.innerText).slice(0, 12000);
        const asksForLogin = /(^|\\n| )(log in|sign up|登录|登入|註冊|注册)( |\\n|$)/i.test(text);
        const hasComposer = !!document.querySelector('textarea,[contenteditable="true"]');
        let session = { reachable: false, status: 0, authenticated: false };
        try {
          const response = await fetch('/api/auth/session', { credentials: 'include', cache: 'no-store' });
          let authenticated = false;
          try {
            const data = await response.json();
            authenticated = !!(data?.user || data?.accessToken || data?.expires);
          } catch {}
          session = { reachable: true, status: response.status, authenticated };
        } catch {}
        return {
          protocol: location.protocol,
          host: location.host,
          path: location.pathname.slice(0, 160),
          readyState: document.readyState,
          bodyLength: text.length,
          asksForLogin,
          hasComposer,
          session,
          authenticated: !asksForLogin && (hasComposer || session.authenticated)
        };
      })()`,
      awaitPromise: true,
      returnByValue: true,
    }, 20_000);
    const state = evaluation?.result?.value || {};
    trace('web-session-verified', state);
    captureScreenshotBinary(state.authenticated ? 'web-session-authenticated' : 'web-session-not-authenticated');
    return state;
  } finally {
    connection.socket.close();
  }
}

async function verifyChatGptAppSurface() {
  const nodes = dumpUi();
  const asksForLogin = nodes.some(node => nodeMatches(node, [
    'Log in', 'Sign up', 'Log in or sign up', '登录', '登入', '注册', '註冊',
  ], true));
  const hasComposer = nodes.some(node => node.editable)
    || nodes.some(node => /message|prompt|composer/i.test(`${node.text} ${node.description}`));
  const result = {
    foregroundPackage: safePackageState() || null,
    asksForLogin,
    hasComposer,
    nodeCount: nodes.length,
    authenticated: !asksForLogin && hasComposer && safePackageState() === CHATGPT_PACKAGE,
  };
  trace('app-surface-verified', result);
  captureScreenshotBinary(result.authenticated ? 'app-authenticated' : 'app-not-authenticated');
  return result;
}

async function attemptAppOAuth() {
  if (!packageInstalled(CHATGPT_PACKAGE)) {
    return { ok: false, errorCode: 'chatgpt_app_missing', message: 'Official ChatGPT Android app is not installed' };
  }
  const launch = adbShell(['monkey', '-p', CHATGPT_PACKAGE, '-c', 'android.intent.category.LAUNCHER', '1']);
  if (!launch.ok) throw new Error(launch.stderr.trim() || 'Unable to launch ChatGPT app');
  await sleep(2_000);
  const before = await verifyChatGptAppSurface();
  if (before.authenticated) return { ok: true, reusedExistingAppSession: true, surface: before };

  const clicked = await clickLabels([
    'Log in or sign up', 'Log in', 'Sign in', '登录或注册', '登入或註冊', '登录', '登入',
  ], { contains: true, attempts: 5 });
  if (!clicked) {
    return { ok: false, errorCode: 'app_login_control_missing', surface: before };
  }
  trace('app-login-triggered', { foregroundPackage: safePackageState() || null });

  const deadline = Date.now() + 90_000;
  while (Date.now() < deadline) {
    const foreground = safePackageState();
    if (foreground === CHATGPT_PACKAGE) {
      const state = await verifyChatGptAppSurface();
      if (state.authenticated) return { ok: true, reusedExistingAppSession: false, surface: state };
    }
    await sleep(1_500);
  }
  const finalState = await verifyChatGptAppSurface();
  return {
    ok: false,
    errorCode: 'app_oauth_not_completed',
    foregroundPackage: safePackageState() || null,
    surface: finalState,
  };
}

export async function runBootstrap() {
  trace('start', {
    mode: MODE,
    serialConfigured: Boolean(SERIAL),
    chromePackage: CHROME_PACKAGE,
    chatgptPackage: CHATGPT_PACKAGE,
  });
  if (!packageInstalled(CHROME_PACKAGE)) throw new Error(`Chrome package missing: ${CHROME_PACKAGE}`);

  launchUrlInChrome('https://chatgpt.com/');
  await sleep(2_000);
  await dismissChromeFirstRun();
  launchUrlInChrome('https://chatgpt.com/');
  await sleep(2_000);
  captureScreenshotBinary('chrome-before-session');

  const cookies = sessionCookiesFromEnvironment();
  const web = await injectAndVerifyWebSession(cookies);
  if (web.authenticated !== true) {
    return { ok: false, errorCode: 'web_session_not_authenticated', web };
  }
  if (MODE === 'web-session') return { ok: true, web };

  const app = await attemptAppOAuth();
  return { ok: app.ok === true, web, app };
}

if (import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    const result = await runBootstrap();
    trace('complete', {
      ok: result.ok === true,
      errorCode: result.errorCode || result.app?.errorCode || null,
    });
    process.stdout.write(`${JSON.stringify(result)}\n`);
    if (result.ok !== true) process.exitCode = 1;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    trace('fatal', { message });
    process.stdout.write(`${JSON.stringify({ ok: false, errorCode: 'android_login_bootstrap_failed', message })}\n`);
    process.exitCode = 1;
  }
}
