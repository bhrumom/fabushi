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
  assert.match(actionsWorkflow, /CHATGPT_SESSION_COOKIES_B64/);
  assert.match(actionsWorkflow, /CHATGPT_AUTO_CONFIRM_STATE_KEY/);
  assert.match(actionsWorkflow, /queue-state\.enc/);
  assert.match(actionsWorkflow, /previous_run_id="\$GITHUB_RUN_ID"/);
  assert.doesNotMatch(actionsWorkflow, /pull_request:/);
  assert.doesNotMatch(actionsWorkflow, /push:/);
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
