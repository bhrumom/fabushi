#!/usr/bin/env node
import { spawnSync } from 'node:child_process';

const PACKAGE = process.env.CHATGPT_ANDROID_PACKAGE || 'com.openai.chatgpt';
const SERIAL = process.env.ANDROID_SERIAL || '';
const sleep = ms => new Promise(resolvePromise => setTimeout(resolvePromise, ms));

function run(binary, args, timeout = 30_000) {
  const result = spawnSync(binary, args, { encoding: 'utf8', timeout, maxBuffer: 32 * 1024 * 1024 });
  return { ok: !result.error && result.status === 0, stdout: String(result.stdout || ''), stderr: String(result.stderr || '') };
}
function adb(args, timeout = 30_000) {
  const prefix = SERIAL ? ['-s', SERIAL] : [];
  return run(process.env.CHATGPT_ANDROID_ADB || 'adb', [...prefix, ...args], timeout);
}
function shell(args, timeout = 30_000) { return adb(['shell', ...args], timeout); }
function trace(stage, detail = {}) { process.stdout.write(`[apk-auth-surface] ${stage} ${JSON.stringify(detail)}\n`); }

function decode(value) {
  return String(value || '').replaceAll('&quot;', '"').replaceAll('&apos;', "'").replaceAll('&lt;', '<').replaceAll('&gt;', '>').replaceAll('&amp;', '&');
}
function nodes() {
  const remote = `/sdcard/apk-auth-surface-${process.pid}.xml`;
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
  if (!text || text.length > 100) return null;
  if (/@|https?:\/\//i.test(text)) return null;
  if (/\b[A-Fa-f0-9]{16,}\b/.test(text)) return null;
  if (/\b\d{6,}\b/.test(text)) return null;
  return text;
}
function surface(tag) {
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
    editableCount: all.filter(node => node.editable).length,
    packages: [...new Set(all.map(node => node.packageName).filter(Boolean))].slice(0, 8),
    labels: labels.slice(0, 40),
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
function chooseLoginNode(all) {
  const exact = ['log in or sign up', 'log in', 'sign in', '登录或注册', '登入或註冊', '登录', '登入'];
  const candidates = all.filter(node => node.enabled && node.bounds).map(node => ({ node, values: [normalize(node.text), normalize(node.description)].filter(Boolean) }));
  for (const label of exact) {
    const hit = candidates.find(item => item.values.some(value => value === label));
    if (hit) return { ...hit, matched: label };
  }
  for (const label of exact) {
    const hit = candidates.find(item => item.values.some(value => value.includes(label)));
    if (hit) return { ...hit, matched: label };
  }
  return null;
}
function authEventSummary() {
  const result = adb(['logcat', '-d', '-v', 'brief', 'ActivityTaskManager:I', 'ActivityManager:I', '*:S'], 20_000);
  const text = result.ok ? result.stdout : '';
  const lines = [];
  for (const raw of text.split(/\r?\n/)) {
    if (!/com\.openai\.chatgpt|com\.auth0\.android|com\.android\.chrome|auth\.openai\.com|auth0\.openai\.com/i.test(raw)) continue;
    let line = raw;
    line = line.replace(/https?:\/\/[^\s}\]]+/gi, value => {
      try {
        const url = new URL(value.replace(/[),;]+$/, ''));
        return `${url.protocol}//${url.host}${url.pathname}?keys=${[...url.searchParams.keys()].sort().join(',')}`;
      } catch { return '[URL_REDACTED]'; }
    });
    if (line.length > 600) line = line.slice(0, 600);
    lines.push(line);
  }
  trace('activity-events', { lines: lines.slice(-80) });
}

const launch = shell(['monkey', '-p', PACKAGE, '-c', 'android.intent.category.LAUNCHER', '1']);
if (!launch.ok) throw new Error('ChatGPT launch failed');
await sleep(2500);
void adb(['logcat', '-c']);

for (let step = 0; step < 5; step += 1) {
  const current = surface(`step-${step}`);
  const component = current.result.component || '';
  if (/com\.auth0\.android\.provider\.(Authentication|Redirect)Activity/.test(component)
      || component.startsWith('com.android.chrome/')) {
    trace('oauth-transport-reached', { step, component });
    break;
  }
  const choice = chooseLoginNode(current.all);
  if (!choice) {
    trace('no-login-control', { step, component });
    break;
  }
  trace('tap-login-control', {
    step,
    matched: choice.matched,
    text: safeLabel(choice.node.text),
    description: safeLabel(choice.node.description),
    className: choice.node.className,
  });
  if (!tap(choice.node)) throw new Error('Unable to tap login control');
  await sleep(1800);
}

surface('final');
authEventSummary();
