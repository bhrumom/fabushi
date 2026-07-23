import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import test from 'node:test';
import worker from '../worker/src/index.ts';
import { HOME, RESOURCES } from '../worker/src/content.generated.ts';

const plugin = JSON.parse(readFileSync(new URL('../.codex-plugin/plugin.json', import.meta.url), 'utf8'));

test('home contract', () => {
  assert.equal(HOME.schema, 'mahayana.miniapp.home.v1');
  assert.equal(HOME.app.id, 'chatgpt-auto-confirm');
  assert.equal(HOME.app.version, plugin.version);
  assert.ok(Buffer.byteLength(JSON.stringify(HOME)) <= 32768);
  assert.ok(HOME.feed.items.length <= 10);
  assert.deepEqual(HOME.quickReplies.map(item => item.action.name), [
    'queue_status', 'prompt_templates', 'wait_for_review',
  ]);
});
test('article bodies stay lazy', () => assert.ok(Object.keys(RESOURCES).length >= 1));
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
