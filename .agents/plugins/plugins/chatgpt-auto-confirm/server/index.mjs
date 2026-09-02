import readline from 'node:readline';
import { existsSync } from 'node:fs';
import { chmod, mkdir, readFile, writeFile } from 'node:fs/promises';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';
import { dirname, resolve } from 'node:path';
import worker from '../worker/src/index.ts';

const defaultNativeRuntime = fileURLToPath(new URL(
  '../runtime/macos/chatgpt-auto-confirm', import.meta.url));
const browserCapabilityHostModule = fileURLToPath(new URL(
  '../scripts/in-app-browser-capability-host.mjs', import.meta.url));
const nativeRuntime = process.env.CHATGPT_AUTO_CONFIRM_NATIVE || defaultNativeRuntime;
const windowsCredentialScript = fileURLToPath(new URL(
  '../scripts/sync-actions-credentials.ps1', import.meta.url));
const windowsCredentialTools = new Set([
  'sync_actions_credentials',
  'login_and_sync_actions',
]);
const browserCapabilityFile = process.env.CHATGPT_AUTO_CONFIRM_BROWSER_CAPABILITY_FILE
  || resolve(homedir(), '.codex', 'browser', 'chatgpt-auto-confirm-capability.json');
const browserJobStateFile = process.env.CHATGPT_AUTO_CONFIRM_BROWSER_JOB_FILE
  || resolve(homedir(), '.codex', 'browser', 'chatgpt-auto-confirm-job.json');
const browserSupervisors = new Map();
const sleep = milliseconds => new Promise(resolvePromise => setTimeout(resolvePromise, milliseconds));
const browserTerminalStatuses = new Set(['completed', 'stopped', 'failed']);
const configuredBrowserHostRetryDelayMs = Number(process.env.CHATGPT_AUTO_CONFIRM_BROWSER_RETRY_MS);
const browserHostRetryDelayMs = Number.isFinite(configuredBrowserHostRetryDelayMs)
  ? Math.min(60_000, Math.max(500, configuredBrowserHostRetryDelayMs))
  : 5_000;
const pluginDispatchParams = (goal) => ({
  message: goal,
  browser: 'iab',
  capability: 'browser.in-app.dispatch-and-watch',
  connector: null,
  model: 'GPT-5.6 Sol',
  reasoning: 'Extra High',
  surface: 'chat',
  newChat: true,
  resumeExisting: false,
  goalOnlyDispatch: true,
  approveAll: true,
  timeout: 21_600,
  stagnationTimeout: 10_800,
  maxRecoveryAttempts: 5,
  autoContinueIncomplete: true,
  maxTaskContinuations: 0,
  continuationMessage: null,
  pollIntervalMs: 500,
});

function browserReattachMetadata(job) {
  return {
    required: true,
    modulePath: browserCapabilityHostModule,
    factory: 'attachPersistentInAppBrowserCapabilityHost',
    runMethod: 'runUntilTerminal',
    browser: 'iab',
    startUrl: String(job?.currentUrl || '').startsWith('https://chatgpt.com/')
      ? job.currentUrl : 'https://chatgpt.com/',
    jobId: job?.id || null,
    preservesExistingJob: true,
  };
}
const nativeCommands = new Map([
  ['account_list', 'account_list'], ['account_add', 'account_add'],
  ['account_login_link', 'account_login_link'], ['account_switch', 'account_switch'],
  ['account_rename', 'account_rename'], ['account_status', 'account_status'],
  ['account_sync', 'account_sync'], ['account_remove', 'account_remove'],
  ['start', 'start'], ['stop', 'stop'], ['status', 'status'],
  ['scan_once', 'scan'], ['relaunch_and_confirm', 'relaunch_and_confirm'],
  ['audit_log', 'audit'], ['diagnose', 'diagnose'],
  ['send_and_watch', 'send_and_watch'],
  ['add_connector', 'add_connector'],
  ['get_reply', 'get_reply'], ['chat_status', 'chat_status'],
  ['enqueue_tasks', 'queue_enqueue'], ['start_queue', 'queue_start'],
  ['queue_status', 'queue_status'], ['update_task', 'queue_update'],
  ['wait_for_review', 'queue_wait_review'],
  ['start_actions_runner', 'start_actions_runner'],
  ['sync_actions_credentials', 'sync_actions_credentials'],
  ['login_and_sync_actions', 'login_and_sync_actions'],
  ['review_task', 'queue_review'], ['pause_queue', 'queue_pause'],
  ['resume_queue', 'queue_resume'], ['retry_task', 'queue_retry'],
  ['cancel_task', 'queue_cancel'],
]);

function nativeToolResponse(rpc, tool, structuredContent) {
  return {
    jsonrpc: '2.0', id: rpc.id,
    result: {
      content: [{ type: 'text', text: structuredContent.ok === false
        ? `Native command failed: ${structuredContent.message || structuredContent.errorCode}`
        : `Native command completed: ${tool}` }],
      structuredContent,
      isError: structuredContent.ok === false,
    },
  };
}

function browserToolResponse(rpc, tool, structuredContent) {
  const failed = structuredContent?.ok === false;
  return {
    jsonrpc: '2.0', id: rpc.id,
    result: {
      content: [{ type: 'text', text: failed
        ? `内置 Browser capability 执行失败：${structuredContent.message || structuredContent.errorCode}`
        : `内置 Browser capability 已处理 ${tool}。` }],
      structuredContent,
      isError: failed,
    },
  };
}

async function readBrowserCapability() {
  let descriptor;
  try {
    descriptor = JSON.parse(await readFile(browserCapabilityFile, 'utf8'));
  } catch {
    return {
      ok: false,
      errorCode: 'browser_capability_unavailable',
      message: '当前没有已授权的内置 Browser capability；请先在受信任的内置 Browser 宿主中启用它。',
    };
  }
  const baseUrl = String(descriptor?.baseUrl || '');
  const validBaseUrl = /^http:\/\/127\.0\.0\.1:\d{1,5}$/u.test(baseUrl);
  if (descriptor?.schema !== 'chatgpt-auto-confirm.browser-capability.v1'
      || descriptor?.capability !== 'browser.in-app.dispatch-and-watch'
      || !validBaseUrl || typeof descriptor?.token !== 'string' || descriptor.token.length < 32
      || !Number.isFinite(Number(descriptor?.expiresAt)) || Date.now() >= Number(descriptor.expiresAt)) {
    return {
      ok: false,
      errorCode: 'browser_capability_invalid',
      message: '内置 Browser capability 文件无效、已过期或授权范围不匹配。',
    };
  }
  return { ok: true, ...descriptor, baseUrl };
}

async function callBrowserCapability(
  descriptor, pathname, method = 'GET', body = undefined, timeoutMs = 30_000,
) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const response = await fetch(`${descriptor.baseUrl}${pathname}`, {
      method,
      signal: controller.signal,
      headers: {
        authorization: `Bearer ${descriptor.token}`,
        ...(body === undefined ? {} : { 'content-type': 'application/json' }),
      },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    let payload;
    try {
      payload = await response.json();
    } catch {
      payload = { ok: false, errorCode: 'browser_capability_invalid_response', message: `HTTP ${response.status}` };
    }
    if (!response.ok && payload.ok !== false) {
      return { ok: false, errorCode: 'browser_capability_http_error', message: `HTTP ${response.status}`, response: payload };
    }
    return payload;
  } catch (error) {
    return {
      ok: false,
      errorCode: error?.name === 'AbortError' ? 'browser_capability_timeout' : 'browser_capability_connection_failed',
      message: String(error?.message || error),
    };
  } finally {
    clearTimeout(timer);
  }
}

async function readPersistedBrowserJob() {
  try {
    const saved = JSON.parse(await readFile(browserJobStateFile, 'utf8'));
    const outcome = String(saved?.lastOutcome?.kind || '');
    const recoverableFailure = saved?.status === 'failed'
      && saved?.stopRequested !== true
      && saved?.phase !== 'terminal'
      && outcome !== 'complete'
      && outcome !== 'stopped';
    if (!saved || typeof saved !== 'object' || !saved.id || !saved.goal
        || (browserTerminalStatuses.has(saved.status) && !recoverableFailure)) return null;
    return recoverableFailure
      ? {
        ...saved,
        status: 'waiting_for_browser_host',
        error: '内置 Browser/CDP 暂时不可用，插件将自动恢复同一任务。',
      }
      : saved;
  } catch {
    return null;
  }
}

async function stopPersistedBrowserJob(jobId) {
  let saved;
  try {
    saved = JSON.parse(await readFile(browserJobStateFile, 'utf8'));
  } catch {
    return null;
  }
  if (!saved || typeof saved !== 'object' || saved.id !== jobId) return null;
  if (!browserTerminalStatuses.has(saved.status)) {
    saved.status = 'stopped';
    saved.responseRunning = false;
    saved.error = saved.error || '已由用户停止内置 Browser 任务';
    saved.lastOutcome = { kind: 'stopped', reason: 'operator' };
    saved.updatedAt = new Date().toISOString();
    await mkdir(dirname(browserJobStateFile), { recursive: true });
    await writeFile(browserJobStateFile, `${JSON.stringify(saved)}\n`, {
      encoding: 'utf8', mode: 0o600,
    });
    await chmod(browserJobStateFile, 0o600);
  }
  browserSupervisors.delete(jobId);
  return saved;
}

function startBrowserSupervisor(jobId) {
  if (!jobId || browserSupervisors.has(jobId)) return;
  const supervisor = (async () => {
    while (true) {
      const persisted = await readPersistedBrowserJob();
      if (!persisted || persisted.id !== jobId) break;
      // Reload the capability descriptor on every pass. A new authorized
      // Browser host can therefore replace a dead tab/context without
      // requiring the caller to dispatch the goal again.
      const descriptor = await readBrowserCapability();
      if (!descriptor.ok) {
        await sleep(browserHostRetryDelayMs);
        continue;
      }
      const health = await callBrowserCapability(
        descriptor, '/v1/capability', 'GET', undefined, 5_000,
      );
      if (!health?.ok) {
        await sleep(browserHostRetryDelayMs);
        continue;
      }
      if (browserTerminalStatuses.has(health.activeJob?.status)) break;
      // The trusted Browser host already runs the single-flight pump. Avoid
      // issuing a second HTTP step every 500 ms while that pump is active;
      // the server supervisor only needs to keep polling for a host rotation.
      if (health.pumpActive === true) {
        await sleep(Math.max(1_000, browserHostRetryDelayMs));
        continue;
      }
      const result = await callBrowserCapability(
        descriptor, '/v1/chat/step', 'POST', { jobId }, 90_000,
      );
      if (!result?.ok) {
        // The host may be restarting, its token may have rotated, or the
        // Browser context may have ended. Keep the persisted goal and retry
        // against the next descriptor instead of abandoning the queue.
        await sleep(browserHostRetryDelayMs);
        continue;
      }
      const status = result.job?.status;
      if (browserTerminalStatuses.has(status)) break;
      // waiting_for_browser_host is deliberately non-terminal. The next
      // pass can observe a freshly attached capability and resume the same
      // persisted job without resending the previous round's progress.
      await sleep(status === 'waiting_for_browser_host' ? browserHostRetryDelayMs : 500);
    }
  })().catch(() => {}).finally(() => {
    browserSupervisors.delete(jobId);
  });
  browserSupervisors.set(jobId, supervisor);
}

function maybeStartBrowserSupervisor(result) {
  const job = result?.job || result?.activeJob;
  if (result?.ok && job?.id && !browserTerminalStatuses.has(job.status)) {
    startBrowserSupervisor(job.id);
  }
}

async function resumePersistedBrowserSupervisor() {
  const job = await readPersistedBrowserJob();
  if (job?.id) startBrowserSupervisor(job.id);
}

async function runInAppBrowserTool(rpc) {
  const tool = String(rpc.params?.name ?? '');
  if (!new Set(['dispatch_goal', 'browser_capability_status', 'browser_job_status', 'browser_stop', 'browser_watch']).has(tool)) return null;
  if (tool === 'browser_watch') {
    const persisted = await readPersistedBrowserJob();
    if (!persisted) return browserToolResponse(rpc, tool, {
      ok: false, errorCode: 'browser_job_not_found', message: '当前没有可恢复的内置 Browser 任务。',
    });
    startBrowserSupervisor(persisted.id);
    const descriptor = await readBrowserCapability();
    const health = descriptor.ok
      ? await callBrowserCapability(descriptor, '/v1/capability', 'GET', undefined, 5_000)
      : descriptor;
    const observedJob = health?.activeJob || persisted;
    const reattachRequired = !descriptor.ok || !health?.ok
      || health?.reattachRequired === true
      || observedJob?.status === 'waiting_for_browser_host';
    maybeStartBrowserSupervisor(health);
    return browserToolResponse(rpc, tool, {
      ok: true,
      supervisor: browserSupervisors.has(persisted.id) ? 'active' : 'starting',
      capability: reattachRequired ? 'reattach_required' : 'available',
      hostHealth: reattachRequired ? 'reattach_required' : (health?.hostHealth || 'attached'),
      reattachRequired,
      reattach: reattachRequired ? browserReattachMetadata(observedJob) : null,
      job: observedJob,
    });
  }
  const descriptor = await readBrowserCapability();
  const args = rpc.params?.arguments ?? {};
  const requestedJobId = String(args.jobId || '').trim();
  if (!descriptor.ok && tool === 'browser_stop') {
    if (!/^iab_[A-Za-z0-9-]{20,100}$/u.test(requestedJobId)) {
      return browserToolResponse(rpc, tool, {
        ok: false, errorCode: 'invalid_job_id', message: 'jobId 必须是内置 Browser 返回的任务标识',
      });
    }
    const stopped = await stopPersistedBrowserJob(requestedJobId);
    if (stopped) return browserToolResponse(rpc, tool, {
      ok: true,
      hostHealth: 'detached',
      reattachRequired: false,
      reattach: null,
      job: stopped,
    });
  }
  if (!descriptor.ok && tool === 'browser_capability_status') {
    const persisted = await readPersistedBrowserJob();
    return browserToolResponse(rpc, tool, {
      ok: true,
      available: false,
      hostHealth: 'reattach_required',
      reattachRequired: !!persisted,
      reattach: persisted ? browserReattachMetadata(persisted) : null,
      activeJob: persisted,
      descriptorError: descriptor,
    });
  }
  if (!descriptor.ok && tool === 'browser_job_status') {
    const persisted = await readPersistedBrowserJob();
    if (persisted?.id === requestedJobId) return browserToolResponse(rpc, tool, {
      ok: true,
      hostHealth: 'reattach_required',
      reattachRequired: true,
      reattach: browserReattachMetadata(persisted),
      job: persisted,
    });
  }
  if (!descriptor.ok) return browserToolResponse(rpc, tool, descriptor);
  if (tool === 'dispatch_goal') {
    const goal = String(args.goal ?? '').trim();
    if (!goal || goal.length > 10_000) {
      return browserToolResponse(rpc, tool, {
        ok: false, errorCode: 'invalid_goal', message: 'goal 必须是 1-10000 字符的非空目标文本',
      });
    }
    const result = await callBrowserCapability(descriptor, '/v1/chat/dispatch', 'POST', {
      goal,
      policy: pluginDispatchParams(goal),
    });
    maybeStartBrowserSupervisor(result);
    return browserToolResponse(rpc, tool, result);
  }
  if (tool === 'browser_capability_status') {
    const result = await callBrowserCapability(descriptor, '/v1/capability');
    maybeStartBrowserSupervisor(result);
    const reattachRequired = !result?.ok || result?.reattachRequired === true
      || result?.activeJob?.status === 'waiting_for_browser_host';
    return browserToolResponse(rpc, tool, result?.ok ? {
      ...result,
      hostHealth: reattachRequired ? 'reattach_required' : (result.hostHealth || 'attached'),
      reattachRequired,
      reattach: reattachRequired ? browserReattachMetadata(result.activeJob) : null,
    } : result);
  }
  const jobId = requestedJobId;
  if (!/^iab_[A-Za-z0-9-]{20,100}$/u.test(jobId)) {
    return browserToolResponse(rpc, tool, {
      ok: false, errorCode: 'invalid_job_id', message: 'jobId 必须是内置 Browser 返回的任务标识',
    });
  }
  const suffix = tool === 'browser_stop' ? '/stop' : '';
  const result = await callBrowserCapability(
    descriptor,
    `/v1/chat/jobs/${encodeURIComponent(jobId)}${suffix}`,
    tool === 'browser_stop' ? 'POST' : 'GET',
  );
  if (!result?.ok && tool === 'browser_stop') {
    const stopped = await stopPersistedBrowserJob(jobId);
    if (stopped) return browserToolResponse(rpc, tool, {
      ok: true,
      hostHealth: 'detached',
      reattachRequired: false,
      reattach: null,
      job: stopped,
    });
  }
  maybeStartBrowserSupervisor(result);
  const reattachRequired = result?.job?.status === 'waiting_for_browser_host';
  return browserToolResponse(rpc, tool, result?.ok ? {
    ...result,
    hostHealth: reattachRequired ? 'reattach_required' : 'attached',
    reattachRequired,
    reattach: reattachRequired ? browserReattachMetadata(result.job) : null,
  } : result);
}

function runWindowsCredentialTool(rpc) {
  const tool = String(rpc.params?.name ?? '');
  if (process.platform !== 'win32' || !windowsCredentialTools.has(tool)
      || !existsSync(windowsCredentialScript)) return null;
  const powershell = process.env.CHATGPT_AUTO_CONFIRM_POWERSHELL || 'powershell.exe';
  const args = [
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', windowsCredentialScript,
  ];
  if (tool === 'login_and_sync_actions') {
    args.push('-DesktopLogin', '-WaitSeconds', String(
      Math.min(1800, Math.max(30, Number(rpc.params?.arguments?.waitSeconds ?? 600))),
    ));
  }
  if (rpc.params?.arguments?.start === true) args.push('-Start');
  const invocation = spawnSync(powershell, args, {
    encoding: 'utf8', timeout: 1_200_000, maxBuffer: 10 * 1024 * 1024,
    env: process.env,
  });
  const stdout = String(invocation.stdout || '').trim();
  const line = stdout.split(/\r?\n/).at(-1);
  let structuredContent;
  try {
    if (invocation.error || !line) {
      throw invocation.error || new Error(String(invocation.stderr || 'Windows credential sync returned no response').trim());
    }
    structuredContent = JSON.parse(line);
    if (invocation.status !== 0 && structuredContent.ok !== false) {
      structuredContent = {
        ok: false,
        errorCode: 'windows_sync_nonzero_exit',
        message: `Windows credential sync exited with code ${invocation.status}`,
        nativeResponse: structuredContent,
      };
    }
  } catch (error) {
    structuredContent = {
      ok: false,
      errorCode: 'windows_sync_response_invalid',
      message: String(invocation.stderr || error).trim() || 'Windows credential sync returned invalid JSON',
    };
  }
  return nativeToolResponse(rpc, tool, structuredContent);
}

function runNativeTool(rpc) {
  const tool = String(rpc.params?.name ?? '');
  const command = nativeCommands.get(tool);
  if (process.platform !== 'darwin' || !command || !existsSync(nativeRuntime)) return null;
  let commandArguments = rpc.params?.arguments ?? {};
  const args = [command];
  if (tool === 'start') args.push(JSON.stringify(rpc.params?.arguments ?? {}));
  if (tool === 'scan_once' || tool === 'relaunch_and_confirm') args.push(JSON.stringify(rpc.params?.arguments ?? {}));
  if (tool === 'audit_log') args.push(String(rpc.params?.arguments?.limit ?? 20));
  if (tool === 'send_and_watch' || tool === 'add_connector' || [
    'account_add', 'account_login_link', 'account_switch', 'account_rename',
    'account_status', 'account_sync', 'account_remove',
    'enqueue_tasks', 'start_queue', 'update_task', 'wait_for_review', 'review_task', 'retry_task',
    'cancel_task', 'sync_actions_credentials', 'login_and_sync_actions', 'start_actions_runner',
  ].includes(tool)) args.push(JSON.stringify(commandArguments));
  const timeoutMs = tool === 'send_and_watch'
    ? 86_500_000
    : ['start_queue', 'wait_for_review'].includes(tool)
      ? 7_300_000
    : ['start', 'scan_once', 'relaunch_and_confirm'].includes(tool) ? 620_000
    : ['account_add', 'account_sync', 'login_and_sync_actions', 'start_actions_runner', 'sync_actions_credentials'].includes(tool) ? 2_000_000 : 15_000;
  const invocation = spawnSync(nativeRuntime, args, {
    encoding: 'utf8', timeout: timeoutMs, maxBuffer: 10 * 1024 * 1024,
    env: process.env,
  });
  const line = invocation.stdout.trim().split(/\r?\n/).at(-1);
  let structuredContent;
  try {
    if (invocation.error || !line) {
      throw invocation.error || new Error(
        invocation.signal
          ? `原生进程被信号 ${invocation.signal} 终止`
          : `原生进程退出码 ${invocation.status ?? 'unknown'}`);
    }
    structuredContent = JSON.parse(line || '{}');
    if (invocation.status !== 0 && structuredContent.ok !== false) {
      structuredContent = {
        ok: false,
        errorCode: 'native_nonzero_exit',
        message: `原生进程退出码 ${invocation.status}`,
        nativeResponse: structuredContent,
      };
    }
  } catch (error) {
    structuredContent = {
      ok: false, errorCode: 'native_response_invalid',
      message: invocation.stderr.trim() || String(error) || '原生插件没有返回有效 JSON',
    };
  }
  return {
    jsonrpc: '2.0', id: rpc.id,
    result: {
      content: [{ type: 'text', text: structuredContent.ok === false
        ? `原生插件执行失败：${structuredContent.message || structuredContent.errorCode}`
        : `原生插件已直接执行 ${tool}。` }],
      structuredContent,
      isError: structuredContent.ok === false,
    },
  };
}

// Recover an unfinished Browser job whenever the local plugin server is
// started. The supervisor waits for a newly authorized Browser host if the
// previous host/context was closed, so a later timer tick can resume it.
void resumePersistedBrowserSupervisor();

const lines = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });
for await (const line of lines) {
  let rpc;
  try {
    rpc = JSON.parse(line);
  } catch (error) {
    process.stdout.write(`${JSON.stringify({
      jsonrpc: '2.0',
      id: null,
      error: { code: -32700, message: String(error) },
    })}\n`);
    continue;
  }
  const browserResponse = rpc.method === 'tools/call'
    ? await runInAppBrowserTool(rpc)
    : null;
  const nativeResponse = browserResponse || (rpc.method === 'tools/call'
    ? (runWindowsCredentialTool(rpc) || runNativeTool(rpc))
    : null);
  if (nativeResponse) {
    process.stdout.write(`${JSON.stringify(nativeResponse)}\n`);
    continue;
  }
  const response = await worker.fetch(new Request('https://standalone.invalid/mcp', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify(rpc),
  }));
  if (rpc.id === undefined || response.status === 202 || response.status === 204) continue;
  const body = await response.text();
  if (body.trim()) process.stdout.write(`${body}\n`);
}
