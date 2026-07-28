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
    'queue_status', 'start_actions_runner', 'prompt_templates', 'wait_for_review',
  ]);
});
test('article bodies stay lazy', () => assert.ok(Object.keys(RESOURCES).length >= 1));
test('continuous Actions runner preserves secrets and chains incomplete sessions', () => {
  assert.match(actionsWorkflow, /runs-on: macos-15/);
  assert.match(actionsWorkflow, /timeout-minutes: 355/);
  assert.match(actionsWorkflow, /CHATGPT_CODEX_AUTH_B64/);
  assert.match(actionsWorkflow, /CHATGPT_SESSION_COOKIES_B64/);
  assert.match(actionsWorkflow, /restore-session-cookies\.mjs/);
  assert.match(actionsWorkflow, /CHATGPT_SESSION_MODE=restore-and-verify/);
  assert.match(actionsWorkflow, /for attempt in 1 2/);
  assert.match(actionsWorkflow, /retrying the proven bootstrap in the same app instance/);
  assert.match(restoreSessionScript, /setTimeout\(\(\) => location\.reload\(\), 0\)/);
  assert.match(restoreSessionScript, /process\.exit\(0\)/);
  assert.doesNotMatch(actionsWorkflow, /pkill -x ChatGPT/);
  assert.match(actionsWorkflow, /Launch authenticated desktop shell/);
  assert.match(actionsWorkflow, /Launch authenticated desktop shell\n\s+timeout-minutes: 6/);
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
test('continuous Actions inbox contains independent work for real parallel dispatch', () => {
  assert.ok(actionsInbox.maxConcurrent >= 2);
  assert.ok(actionsInbox.tasks.length >= 2);
  const firstLocks = new Set(actionsInbox.tasks[0].resourceLocks || []);
  const secondLocks = new Set(actionsInbox.tasks[1].resourceLocks || []);
  assert.equal([...firstLocks].some(lock => secondLocks.has(lock)), false);
});
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
    'summary', 'completed', 'remaining', 'blockers', 'verification',
    'wait_seconds', 'wait_reason', 'next_connector', 'next_task',
  ]);
});
