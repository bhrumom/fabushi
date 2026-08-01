import readline from 'node:readline';
import { existsSync } from 'node:fs';
import { spawnSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import worker from '../worker/src/index.ts';

const defaultNativeRuntime = fileURLToPath(new URL(
  '../runtime/macos/chatgpt-auto-confirm', import.meta.url));
const nativeRuntime = process.env.CHATGPT_AUTO_CONFIRM_NATIVE || defaultNativeRuntime;
const windowsCredentialScript = fileURLToPath(new URL(
  '../scripts/sync-actions-credentials.ps1', import.meta.url));
const windowsCredentialTools = new Set([
  'sync_actions_credentials',
  'login_and_sync_actions',
  'web_login_and_sync_actions',
]);
const nativeCommands = new Map([
  ['start', 'start'], ['stop', 'stop'], ['status', 'status'],
  ['scan_once', 'scan'], ['relaunch_and_confirm', 'relaunch_and_confirm'],
  ['audit_log', 'audit'], ['diagnose', 'diagnose'],
  ['send_and_watch', 'send_and_watch'], ['add_connector', 'add_connector'],
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

function runWindowsCredentialTool(rpc) {
  const tool = String(rpc.params?.name ?? '');
  if (process.platform !== 'win32' || !windowsCredentialTools.has(tool)
      || !existsSync(windowsCredentialScript)) return null;
  const powershell = process.env.CHATGPT_AUTO_CONFIRM_POWERSHELL || 'powershell.exe';
  const args = [
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', windowsCredentialScript,
  ];
  if (tool === 'login_and_sync_actions') {
    args.push('-OpenLogin', '-WaitSeconds', String(
      Math.min(1800, Math.max(30, Number(rpc.params?.arguments?.waitSeconds ?? 600))),
    ));
  }
  if (tool === 'web_login_and_sync_actions') {
    args.push('-OpenLogin', '-WaitSeconds', String(
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
  const args = [command];
  if (tool === 'start') args.push(JSON.stringify(rpc.params?.arguments ?? {}));
  if (tool === 'scan_once' || tool === 'relaunch_and_confirm') args.push(JSON.stringify(rpc.params?.arguments ?? {}));
  if (tool === 'audit_log') args.push(String(rpc.params?.arguments?.limit ?? 20));
  if (tool === 'send_and_watch' || tool === 'add_connector' || [
    'enqueue_tasks', 'start_queue', 'update_task', 'wait_for_review', 'review_task', 'retry_task',
    'cancel_task', 'sync_actions_credentials', 'login_and_sync_actions',
  ].includes(tool)) args.push(JSON.stringify(rpc.params?.arguments ?? {}));
  const timeoutMs = tool === 'send_and_watch'
    ? 7_300_000
    : ['start_queue', 'wait_for_review'].includes(tool)
      ? 7_300_000
    : ['start', 'scan_once', 'relaunch_and_confirm'].includes(tool) ? 620_000
    : ['start_actions_runner', 'sync_actions_credentials', 'login_and_sync_actions', 'web_login_and_sync_actions'].includes(tool) ? 1_200_000 : 15_000;
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
  const nativeResponse = rpc.method === 'tools/call'
    ? (runWindowsCredentialTool(rpc) || runNativeTool(rpc))
    : null;
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
