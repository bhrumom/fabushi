#!/usr/bin/env node
import { spawn } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import readline from 'node:readline';

const codex = process.env.CODEX_BIN || 'codex';
const codexHome = resolve(process.env.CODEX_HOME || `${process.env.HOME || '.'}/.codex`);
const authPath = resolve(codexHome, 'auth.json');
const timeoutMs = Number(process.env.CODEX_AUTH_PROBE_TIMEOUT_MS || 90_000);

function readAuthMeta() {
  try {
    const parsed = JSON.parse(readFileSync(authPath, 'utf8'));
    const tokens = parsed?.tokens && typeof parsed.tokens === 'object' ? parsed.tokens : {};
    return {
      authMode: String(parsed?.auth_mode || ''),
      hasAccessToken: Boolean(tokens.access_token),
      hasRefreshToken: Boolean(tokens.refresh_token),
      hasIdToken: Boolean(tokens.id_token),
      lastRefresh: String(parsed?.last_refresh || ''),
    };
  } catch {
    return {
      authMode: '',
      hasAccessToken: false,
      hasRefreshToken: false,
      hasIdToken: false,
      lastRefresh: '',
    };
  }
}

function safeAccount(result) {
  const account = result?.account;
  return {
    accountPresent: Boolean(account),
    accountType: account && typeof account.type === 'string' ? account.type : null,
    planType: account && typeof account.planType === 'string' ? account.planType : null,
    requiresOpenaiAuth: result?.requiresOpenaiAuth === true,
  };
}

function print(stage, detail = {}) {
  process.stdout.write(`[codex-auth-probe] ${stage} ${JSON.stringify(detail)}\n`);
}

const before = readAuthMeta();
print('before', {
  authMode: before.authMode || null,
  hasAccessToken: before.hasAccessToken,
  hasRefreshToken: before.hasRefreshToken,
  hasIdToken: before.hasIdToken,
  hasLastRefresh: Boolean(before.lastRefresh),
});

if (before.authMode !== 'chatgpt' || !before.hasRefreshToken) {
  print('complete', { ok: false, reason: 'chatgpt_refresh_credential_missing' });
  process.exit(1);
}

const child = spawn(codex, ['app-server', '--stdio'], {
  env: { ...process.env, CODEX_HOME: codexHome, RUST_LOG: 'warn' },
  stdio: ['pipe', 'pipe', 'pipe'],
});

const pending = new Map();
const notifications = [];
let sequence = 0;
let stderrTail = '';

child.stderr.setEncoding('utf8');
child.stderr.on('data', chunk => {
  stderrTail = `${stderrTail}${chunk}`.slice(-24_000);
});

const rl = readline.createInterface({ input: child.stdout });
rl.on('line', line => {
  let message;
  try { message = JSON.parse(line); } catch { return; }
  if (message && Object.hasOwn(message, 'id')) {
    const entry = pending.get(String(message.id));
    if (!entry) return;
    pending.delete(String(message.id));
    clearTimeout(entry.timer);
    if (message.error) entry.reject(new Error('app_server_rpc_error'));
    else entry.resolve(message.result ?? {});
    return;
  }
  if (message?.method) notifications.push(String(message.method));
});

function rpc(method, params = {}, timeout = timeoutMs) {
  const id = ++sequence;
  return new Promise((resolvePromise, reject) => {
    const timer = setTimeout(() => {
      pending.delete(String(id));
      reject(new Error('app_server_rpc_timeout'));
    }, timeout);
    pending.set(String(id), { resolve: resolvePromise, reject, timer });
    child.stdin.write(`${JSON.stringify({ method, id, params })}\n`);
  });
}

function notify(method, params = {}) {
  child.stdin.write(`${JSON.stringify({ method, params })}\n`);
}

const childExit = new Promise(resolvePromise => {
  child.once('exit', (code, signal) => resolvePromise({ code, signal }));
});

let ok = false;
try {
  await rpc('initialize', {
    clientInfo: {
      name: 'fabushi_android_auth_probe',
      title: 'Fabushi Android Auth Probe',
      version: '0.1.0',
    },
    capabilities: { experimentalApi: true },
  }, 30_000);
  notify('initialized');

  const accountRead = await rpc('account/read', { refreshToken: true }, timeoutMs);
  const account = safeAccount(accountRead);
  const after = readAuthMeta();
  const refreshMetadataChanged = Boolean(after.lastRefresh && after.lastRefresh !== before.lastRefresh);

  print('account-read', {
    ...account,
    authMode: after.authMode || null,
    hasAccessToken: after.hasAccessToken,
    hasRefreshToken: after.hasRefreshToken,
    refreshMetadataChanged,
  });

  if (!account.accountPresent || account.accountType !== 'chatgpt') {
    throw new Error('chatgpt_account_not_available_after_refresh');
  }
  if (!after.hasAccessToken || !after.hasRefreshToken) {
    throw new Error('refreshed_auth_file_incomplete');
  }

  // A backend-backed rate-limit read provides a second proof that the refreshed
  // ChatGPT OAuth credential is accepted upstream. Keep only the success shape;
  // do not emit credit balances, reset times, identifiers, or user metadata.
  const rateResult = await rpc('account/rateLimits/read', {}, 45_000);
  const rateLimitsReachable = Boolean(rateResult && typeof rateResult === 'object');
  print('backend-check', { rateLimitsReachable });
  if (!rateLimitsReachable) throw new Error('chatgpt_backend_check_failed');

  ok = true;
  print('complete', {
    ok: true,
    accountType: account.accountType,
    planType: account.planType,
    refreshMetadataChanged,
    accountUpdatedNotificationSeen: notifications.includes('account/updated'),
  });
} catch (error) {
  const stderrLower = stderrTail.toLowerCase();
  const reason = stderrLower.includes('refresh token')
    ? 'oauth_refresh_rejected'
    : stderrLower.includes('unauthorized') || stderrLower.includes('401')
      ? 'oauth_unauthorized'
      : error instanceof Error ? error.message : 'unknown_error';
  print('complete', { ok: false, reason });
  process.exitCode = 1;
} finally {
  for (const entry of pending.values()) clearTimeout(entry.timer);
  pending.clear();
  try { child.stdin.end(); } catch {}
  const exited = await Promise.race([
    childExit,
    new Promise(resolvePromise => setTimeout(() => resolvePromise(null), 1500)),
  ]);
  if (!exited) {
    try { child.kill('SIGTERM'); } catch {}
  }
  rl.close();
}

if (!ok) process.exitCode = 1;
