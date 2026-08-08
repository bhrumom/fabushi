#!/usr/bin/env node
import { spawnSync } from 'node:child_process';
import { resolve, dirname } from 'node:path';

const PACKAGE = process.env.CHATGPT_ANDROID_PACKAGE || 'com.openai.chatgpt';
const CHROME = process.env.CHATGPT_ANDROID_CHROME_PACKAGE || 'com.android.chrome';
const SERIAL = process.env.ANDROID_SERIAL || '';
const AUTH_B64 = process.env.CHATGPT_CODEX_AUTH_B64 || '';
const sleep = ms => new Promise(resolvePromise => setTimeout(resolvePromise, ms));

function run(binary, args, timeout = 30_000) {
  const result = spawnSync(binary, args, {
    encoding: 'utf8',
    timeout,
    maxBuffer: 32 * 1024 * 1024,
    env: process.env,
  });
  return {
    ok: !result.error && result.status === 0,
    status: result.status,
    stdout: String(result.stdout || ''),
    stderr: String(result.stderr || ''),
  };
}
function adb(args, timeout = 30_000) {
  const prefix = SERIAL ? ['-s', SERIAL] : [];
  return run(process.env.CHATGPT_ANDROID_ADB || 'adb', [...prefix, ...args], timeout);
}
function shell(args, timeout = 30_000) { return adb(['shell', ...args], timeout); }
function trace(stage, detail = {}) { process.stdout.write(`[apk-identity-login] ${stage} ${JSON.stringify(detail)}\n`); }

function decodeJwtPayload(value) {
  if (typeof value !== 'string') return null;
  const parts = value.split('.');
  if (parts.length !== 3) return null;
  try {
    const text = Buffer.from(parts[1].replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8');
    return JSON.parse(text);
  } catch {
    return null;
  }
}
function collectEmails(value, out = []) {
  if (value == null) return out;
  if (typeof value === 'string') {
    const trimmed = value.trim();
    if (/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(trimmed) && trimmed.length <= 254) out.push(trimmed);
    const jwt = decodeJwtPayload(trimmed);
    if (jwt) collectEmails(jwt, out);
    return out;
  }
  if (Array.isArray(value)) {
    for (const item of value) collectEmails(item, out);
    return out;
  }
  if (typeof value === 'object') {
    // Prefer explicit email/profile fields, then inspect the remaining tree.
    for (const key of ['email', 'preferred_username', 'upn']) {
      if (Object.hasOwn(value, key)) collectEmails(value[key], out);
    }
    for (const [key, item] of Object.entries(value)) {
      if (!['email', 'preferred_username', 'upn'].includes(key)) collectEmails(item, out);
    }
  }
  return out;
}
function loginEmail() {
  if (!AUTH_B64.trim()) throw new Error('CHATGPT_CODEX_AUTH_B64 is empty');
  let auth;
  try { auth = JSON.parse(Buffer.from(AUTH_B64.trim(), 'base64').toString('utf8')); }
  catch { throw new Error('CHATGPT_CODEX_AUTH_B64 is not valid auth JSON'); }
  const emails = [...new Set(collectEmails(auth))];
  if (!emails.length) throw new Error('No login email was found in existing auth metadata');
  return emails[0];
}

function decode(value) {
  return String(value || '').replaceAll('&quot;', '"').replaceAll('&apos;', "'").replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&amp;', '&');
}
function nodes() {
  const remote = `/sdcard/apk-identity-${process.pid}.xml`;
  const dumped = shell(['uiautomator', 'dump', remote], 20_000);
  if (!dumped.ok) return [];
  const read = adb(['exec-out', 'cat', remote], 20_000);
  void shell(['rm', '-f', remote]);
  if (!read.ok) return [];
  const out = [];
  for (const match of read.stdout.matchAll(/<node\b([^>]*)\/?>(?:<\/node>)?/g)) {
    const attrs = new Map();
    for (const attr of match[1].matchAll(/([\w:-]+)="([^"]*)"/g)) attrs.set(attr[1], decode(attr[2]));
    const bounds = String(attrs.get('bounds') || '').match(/^\[(\d+),(\d+)\]\[(\d+),(\d+)\]$/);
    out.push({
      text: attrs.get('text') || '',
      description: attrs.get('content-desc') || '',
      resourceId: attrs.get('resource-id') || '',
      className: attrs.get('class') || '',
      packageName: attrs.get('package') || '',
      clickable: attrs.get('clickable') === 'true',
      enabled: attrs.get('enabled') !== 'false',
      editable: attrs.get('editable') === 'true' || String(attrs.get('class') || '').includes('EditText'),
      bounds: bounds ? [Number(bounds[1]), Number(bounds[2]), Number(bounds[3]), Number(bounds[4])] : null,
    });
  }
  return out;
}
function resumedComponent() {
  const result = shell(['dumpsys', 'activity', 'activities']);
  const text = result.ok ? result.stdout : '';
  return text.match(/mResumedActivity:.*?\s([A-Za-z0-9._]+\/[A-Za-z0-9._$]+)/)?.[1]
    || text.match(/topResumedActivity=.*?\s([A-Za-z0-9._]+\/[A-Za-z0-9._$]+)/)?.[1]
    || null;
}
function safeLabel(value) {
  const text = String(value || '').replace(/\s+/g, ' ').trim();
  if (!text || text.length > 120) return null;
  if (/@|https?:\/\//i.test(text)) return null;
  if (/\b[A-Fa-f0-9]{16,}\b/.test(text)) return null;
  if (/\b\d{6,}\b/.test(text)) return null;
  return text;
}
function summary(tag) {
  const all = nodes();
  const labels = [];
  for (const node of all) {
    for (const value of [node.text, node.description]) {
      const safe = safeLabel(value);
      if (safe && !labels.includes(safe)) labels.push(safe);
    }
  }
  const result = {
    tag,
    component: resumedComponent(),
    nodeCount: all.length,
    editableCount: all.filter(item => item.editable).length,
    packages: [...new Set(all.map(item => item.packageName).filter(Boolean))].slice(0, 8),
    labels: labels.slice(0, 45),
  };
  trace('surface', result);
  return { all, result };
}
function normalize(value) { return String(value || '').replace(/\s+/g, ' ').trim().toLowerCase(); }
function tap(node) {
  if (!node?.bounds) return false;
  const [x1, y1, x2, y2] = node.bounds;
  return shell(['input', 'tap', String(Math.round((x1 + x2) / 2)), String(Math.round((y1 + y2) / 2))]).ok;
}
function findLabel(all, labels) {
  const wanted = labels.map(normalize);
  for (const exact of [true, false]) {
    const hit = all.find(node => {
      if (!node.enabled || !node.bounds) return false;
      const values = [normalize(node.text), normalize(node.description)].filter(Boolean);
      return wanted.some(label => values.some(value => exact ? value === label : value.includes(label)));
    });
    if (hit) return hit;
  }
  return null;
}
async function tapLabel(labels, tag) {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    const all = nodes();
    const node = findLabel(all, labels);
    if (node && tap(node)) {
      trace('tap', { tag, className: node.className, packageName: node.packageName });
      await sleep(1200);
      return true;
    }
    await sleep(350);
  }
  return false;
}

function setChromeDefault() {
  void shell(['pm', 'enable', CHROME], 10_000);
  const role = shell(['cmd', 'role', 'add-role-holder', '--user', '0', 'android.app.role.BROWSER', CHROME], 30_000);
  const holders = shell(['cmd', 'role', 'get-role-holders', '--user', '0', 'android.app.role.BROWSER'], 10_000);
  const holderNames = holders.ok ? holders.stdout.split(/\r?\n/).map(v => v.trim()).filter(Boolean) : [];
  trace('browser-role', { commandOk: role.ok, chromeIsHolder: holderNames.includes(CHROME), holderCount: holderNames.length });
  if (!role.ok || !holderNames.includes(CHROME)) throw new Error('Unable to make Chrome the Android browser role holder');
}

function seedChrome() {
  const script = resolve(dirname(process.argv[1]), 'seed-chrome-session.mjs');
  const result = run(process.execPath, [script], 120_000);
  if (result.stdout) process.stdout.write(result.stdout);
  if (result.stderr) process.stderr.write(result.stderr);
  if (!result.ok) throw new Error(`Chrome session seed failed with status ${result.status ?? 'unknown'}`);
}

function typeIdentity(email) {
  const all = nodes();
  const editable = all.find(node => node.enabled && node.bounds && node.editable);
  if (!editable) throw new Error('Identity email field was not found');
  if (!tap(editable)) throw new Error('Unable to focus identity email field');
  shell(['input', 'keyevent', 'KEYCODE_MOVE_END']);
  shell(['input', 'text', email], 20_000);
  trace('identity-entered', { emailPresent: true, emailLength: email.length });
}

function detectOutcome(tag) {
  const current = summary(tag);
  const labels = current.result.labels.map(normalize);
  const joined = labels.join('\n');
  let kind = 'unknown';
  if (/check your email|verification code|enter code|one-time|otp|验证码|驗證碼/.test(joined)) kind = 'email-verification';
  else if (/password|forgot password/.test(joined)) kind = 'password';
  else if (/passkey|security key/.test(joined)) kind = 'passkey';
  else if (/continue with google/.test(joined)) kind = 'provider-choice';
  else if (current.result.component?.startsWith(`${CHROME}/`)) kind = 'chrome';
  else if (/com\.auth0\.android\.provider\.(Authentication|Redirect)Activity/.test(current.result.component || '')) kind = 'auth0-activity';
  else if (/message chatgpt|ask chatgpt|new chat/.test(joined) && !/log in|sign up/.test(joined)) kind = 'authenticated-app';
  trace('outcome', { kind, component: current.result.component });
  return kind;
}

const email = loginEmail();
trace('identity-ready', { emailPresent: true, emailLength: email.length });
setChromeDefault();
seedChrome();

const launch = shell(['monkey', '-p', PACKAGE, '-c', 'android.intent.category.LAUNCHER', '1']);
if (!launch.ok) throw new Error('Unable to launch ChatGPT');
await sleep(2200);

if (!await tapLabel(['Log in', '登录', '登入'], 'intro-login')) throw new Error('Initial Log in control not found');
if (!await tapLabel(['Log in or sign up', '登录或注册', '登入或註冊'], 'open-web-login')) throw new Error('Log in or sign up control not found');
await sleep(1200);
summary('identity-form');
typeIdentity(email);
if (!await tapLabel(['Continue', '继续', '繼續'], 'identity-continue')) throw new Error('Identity Continue control not found');

for (let attempt = 1; attempt <= 18; attempt += 1) {
  await sleep(1500);
  const kind = detectOutcome(`post-identity-${attempt}`);
  if (kind !== 'unknown' && kind !== 'provider-choice') break;
}
