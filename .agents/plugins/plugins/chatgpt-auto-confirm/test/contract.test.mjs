import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import worker from '../worker/src/index.ts';
import { HOME, RESOURCES } from '../worker/src/content.generated.ts';

const plugin = JSON.parse(readFileSync(new URL('../.codex-plugin/plugin.json', import.meta.url), 'utf8'));
const actionsWorkflow = readFileSync(
  new URL('../../../../../.github/workflows/chatgpt-auto-confirm-runner.yml', import.meta.url),
  'utf8',
);
const restoreSessionScript = readFileSync(
  new URL('../scripts/restore-session-cookies.mjs', import.meta.url),
  'utf8',
);
const dispatchActionsScript = readFileSync(
  new URL('../scripts/dispatch-actions-runner.sh', import.meta.url),
  'utf8',
);
const windowsSyncScript = readFileSync(
  new URL('../scripts/sync-actions-credentials.ps1', import.meta.url),
  'utf8',
);
const windowsCookieExtractor = readFileSync(
  new URL('../scripts/extract-windows-chatgpt-cookies.py', import.meta.url),
  'utf8',
);
const browserCookieCapture = readFileSync(
  new URL('../scripts/capture-browser-chatgpt-cookies.mjs', import.meta.url),
  'utf8',
);
const dynamicController = readFileSync(
  new URL('../scripts/run-dynamic-actions-controller.mjs', import.meta.url),
  'utf8',
);
const nativeServer = readFileSync(
  new URL('../server/index.mjs', import.meta.url),
  'utf8',
);
const workerSource = readFileSync(
  new URL('../worker/src/index.ts', import.meta.url),
  'utf8',
);
const actionsInbox = JSON.parse(readFileSync(
  new URL('../tasks/actions-inbox.json', import.meta.url),
  'utf8',
));

test('home contract', () => {
  assert.equal(HOME.schema, 'mahayana.miniapp.home.v1');
  assert.equal(HOME.app.id, 'chatgpt-auto-confirm');
  assert.equal(HOME.app.version, plugin.version);
  assert.ok(Buffer.byteLength(JSON.stringify(HOME)) <= 32768);
  assert.ok(HOME.feed.items.length <= 10);
  assert.deepEqual(HOME.quickReplies.map(item => item.action.name), [
    'web_login_and_sync_actions', 'sync_actions_credentials', 'login_and_sync_actions', 'queue_status', 'start_actions_runner',
    'prompt_templates', 'wait_for_review',
  ]);
  const webLoginReply = HOME.quickReplies.find(item => item.action.name === 'web_login_and_sync_actions');
  assert.equal(webLoginReply.label, '浏览器登录并同步 Action 凭证');
  assert.deepEqual(webLoginReply.aliases, ['浏览器登录', '同步网页凭证']);
});
test('article bodies stay lazy', () => assert.ok(Object.keys(RESOURCES).length >= 1));
test('continuous Actions runner preserves secrets and chains incomplete sessions', () => {
  assert.match(actionsWorkflow, /runs-on: macos-15/);
  assert.match(actionsWorkflow, /timeout-minutes: 355/);
  assert.match(actionsWorkflow, /CHATGPT_CODEX_AUTH_B64/);
  assert.match(actionsWorkflow, /CHATGPT_SESSION_COOKIES_B64/);
  assert.match(actionsWorkflow, /restore-session-cookies\.mjs/);
  assert.match(actionsWorkflow, /CHATGPT_SESSION_MODE=restore/);
  assert.match(actionsWorkflow, /Verify authenticated ChatGPT session/);
  assert.match(actionsWorkflow, /verify_chatgpt_login/);
  assert.match(actionsWorkflow, /AUTHENTICATION_VERIFIED/);
  assert.match(actionsWorkflow, /no continuation was dispatched/);
  assert.match(actionsWorkflow, /Bootstrap only: persist cookies and request one bounded renderer reload/);
  assert.match(actionsWorkflow, /native queue owns authenticated Chat creation and verification/);
  assert.doesNotMatch(actionsWorkflow, /CHATGPT_SESSION_MODE=restore-and-verify/);
  assert.doesNotMatch(actionsWorkflow, /Authenticated Chat shell attempt/);
  assert.match(restoreSessionScript, /mode === 'restore'/);
  assert.match(restoreSessionScript, /process\.exit\(0\)/);
  assert.match(restoreSessionScript, /Page\.reload/);
  assert.match(restoreSessionScript, /Optional CDP command/);
  assert.doesNotMatch(restoreSessionScript, /call\([^\n]*['"]Page\.setWebLifecycleState['"]/);
  assert.doesNotMatch(actionsWorkflow, /pkill -x ChatGPT/);
  assert.match(actionsWorkflow, /Launch authenticated desktop shell/);
  assert.match(actionsWorkflow, /Launch authenticated desktop shell\r?\n\s+timeout-minutes: 4/);
  assert.doesNotMatch(actionsWorkflow, /login_status=\$\(/);
  assert.match(actionsWorkflow, /Build native queue runtime/);
  assert.match(actionsWorkflow, /CHATGPT_AUTO_CONFIRM_STATE_KEY/);
  assert.match(actionsWorkflow, /queue-state\.enc/);
  assert.match(actionsWorkflow, /previous_run_id="\$GITHUB_RUN_ID"/);
  assert.match(actionsWorkflow, /parallel_queue_smoke/);
  assert.match(actionsWorkflow, /chatgpt-auto-confirm-parallel-smoke/);
  assert.match(actionsWorkflow, /verify-parallel-actions-queue\.mjs/);
  assert.match(actionsWorkflow, /parallel-queue-evidence\.json/);
  assert.match(actionsWorkflow, /task-queue\/watcher-trace\.log/);
  assert.doesNotMatch(actionsWorkflow, /CHATGPT_AUTO_CONFIRM_TASK_INBOX_B64/);
  assert.match(actionsWorkflow, /CHATGPT_AUTO_CONFIRM_TASK_INBOX_FILE/);
  assert.match(actionsWorkflow, /tasks\/actions-inbox\.json/);
  assert.match(actionsWorkflow, /import-actions-task-inbox\.mjs/);
  assert.match(actionsWorkflow, /status" != "incomplete"/);
  assert.match(actionsWorkflow, /VERIFICATION_ONLY/);
  assert.match(actionsWorkflow, /no continuation was dispatched/);
  assert.match(actionsWorkflow, /--ref "\$GITHUB_REF_NAME"/);
  assert.match(actionsWorkflow, /jq '\{status, reason, counts, tasks\}'/);
  assert.doesNotMatch(actionsWorkflow, /pull_request:/);
  assert.doesNotMatch(actionsWorkflow, /push:/);
});
test('login sync uploads both credential forms without printing values', () => {
  assert.match(dispatchActionsScript, /CHATGPT_SESSION_COOKIES_PATH/);
  assert.match(dispatchActionsScript, /CHATGPT_CODEX_AUTH_B64/);
  assert.match(dispatchActionsScript, /CHATGPT_SESSION_COOKIES_B64/);
  assert.match(dispatchActionsScript, /CHATGPT_AUTO_CONFIRM_DISPATCH/);
  assert.doesNotMatch(dispatchActionsScript, /echo .*CHATGPT_(CODEX_AUTH|SESSION_COOKIES)_B64/);
  assert.match(dynamicController, /status === 'failed'/);
});
test('Windows credential sync keeps secrets out of logs and supports optional dispatch', () => {
  assert.match(nativeServer, /sync-actions-credentials\.ps1/);
  assert.match(nativeServer, /process\.platform !== 'win32'/);
  assert.match(windowsSyncScript, /CHATGPT_CODEX_AUTH_B64/);
  assert.match(windowsSyncScript, /CHATGPT_SESSION_COOKIES_B64/);
  assert.match(windowsSyncScript, /\$Start/);
  assert.match(windowsSyncScript, /ConvertTo-Json -Compress/);
  assert.doesNotMatch(windowsSyncScript, /Write-Host .*encoded/);
  assert.doesNotMatch(windowsSyncScript, /Write-Output .*encoded/);
  assert.match(windowsSyncScript, /remote-debugging-port/);
  assert.match(windowsSyncScript, /app_EMoamEEZ73f0CkXaXp7hrann/);
  assert.match(windowsSyncScript, /'http:\/\/localhost:' \+ \$callback\.Port \+ '\/auth\/callback'/);
  assert.match(windowsSyncScript, /chatgpt\.com\/codex\/desktop-auth\?authorize_url/);
  assert.doesNotMatch(windowsSyncScript, /Get-AppxPackage/);
  assert.doesNotMatch(windowsSyncScript, /Start-Process ['"]https?:/);
  assert.doesNotMatch(windowsSyncScript, /codex.*--login/);
  assert.match(windowsSyncScript, /WaitSeconds/);
  assert.match(windowsCookieExtractor, /validate_auth_bundle/);
  assert.match(windowsCookieExtractor, /credentialSource/);
  assert.match(windowsCookieExtractor, /win32crypt/);
  assert.match(windowsCookieExtractor, /Cryptodome\.Cipher/);
  assert.match(windowsCookieExtractor, /OpenAI\.Codex_/);
  assert.doesNotMatch(windowsCookieExtractor, /B64_START/);
  assert.match(browserCookieCapture, /Network\.getAllCookies/);
  assert.match(browserCookieCapture, /api\/auth\/session/);
  assert.doesNotMatch(browserCookieCapture, /process\.stdout\.write\([^\n]*(?:cookie|token|value)/i);
});
test('worker exposes the interactive login sync command', async () => {
  const response = await worker.fetch(new Request('https://example.test/mcp', {
    method: 'POST', body: JSON.stringify({ jsonrpc: '2.0', id: 9, method: 'tools/list' }),
  }));
  const tools = (await response.json()).result.tools;
  const tool = tools.find(item => item.name === 'login_and_sync_actions');
  assert.ok(tool);
  assert.equal(tool.inputSchema.properties.start.default, true);
  assert.equal(tool.inputSchema.properties.waitSeconds.default, 600);
  assert.match(nativeServer, /\['login_and_sync_actions', 'login_and_sync_actions'\]/);
  assert.match(nativeServer, /'cancel_task', 'login_and_sync_actions'/);
  const credentialTool = tools.find(item => item.name === 'sync_actions_credentials');
  assert.ok(credentialTool);
  assert.equal(credentialTool.inputSchema.properties.start.default, false);
  assert.match(workerSource, /actions-runner-credential-sync/);
  assert.match(nativeServer, /-OpenLogin/);
  assert.match(nativeServer, /-WaitSeconds/);
  const webTool = tools.find(item => item.name === 'web_login_and_sync_actions');
  assert.ok(webTool);
  assert.equal(webTool.inputSchema.properties.start.default, false);
  assert.equal(webTool.inputSchema.properties.waitSeconds.default, 600);
  assert.match(workerSource, /actions-runner-web-login-sync/);
  assert.match(nativeServer, /-WebLogin/);
  assert.match(windowsSyncScript, /desktop-auth\?authorize_url/);
  assert.match(windowsSyncScript, /credentialSource/);
});
// test('continuous Actions inbox contains independent work for real parallel dispatch', () => {
//   assert.ok(actionsInbox.maxConcurrent >= 2);
//   assert.ok(actionsInbox.tasks.length >= 2);
//   const firstLocks = new Set(actionsInbox.tasks[0].resourceLocks || []);
//   const secondLocks = new Set(actionsInbox.tasks[1].resourceLocks || []);
//   assert.equal([...firstLocks].some(lock => secondLocks.has(lock)), false);
// });
test('JSON-RPC errors use the top-level error member', async () => {
  const response = await worker.fetch(new Request('https://example.test/mcp', {
    method: 'POST', body: JSON.stringify({ jsonrpc: '2.0', id: 7, method: 'unknown' }),
  }));
  assert.deepEqual((await response.json()).error, { code: -32601, message: 'Method not found' });
});

test('task prompt templates expose the strict report protocol', async () => {
  const response = await worker.fetch(new Request('https://example.test/mcp', {
    method: 'POST', body: JSON.stringify({
      jsonrpc: '2.0', id: 8, method: 'tools/call',
      params: { name: 'prompt_templates', arguments: {} },
    }),
  }));
  const payload = await response.json();
  assert.equal(payload.result.structuredContent.templates.length, 4);
  assert.equal(payload.result.structuredContent.reportProtocol.protocol, 'mahayana.task-report.v1');
  assert.deepEqual(payload.result.structuredContent.reportProtocol.fields, [
    'task_id', 'applied_task_revision', 'applied_spec_digest',
    'summary', 'completed', 'remaining', 'blockers', 'verification',
    'wait_seconds', 'wait_reason', 'next_connector', 'next_task',
  ]);
});
