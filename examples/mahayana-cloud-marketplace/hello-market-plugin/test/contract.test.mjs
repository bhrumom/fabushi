import assert from 'node:assert/strict';
import test from 'node:test';
import worker from '../worker/src/index.ts';

test('cloud market hello exposes readonly MCP contract', async () => {
  const response = await worker.fetch(new Request('https://example.test/mcp', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', id: 1, method: 'tools/list' }),
  }));

  const body = await response.json();
  const tool = body.result.tools.find(item => item.name === 'hello');
  assert.ok(tool);
  assert.equal(tool.annotations.readOnlyHint, true);
});

test('cloud market hello returns stable mini app result', async () => {
  const response = await worker.fetch(new Request('https://example.test/mcp', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      jsonrpc: '2.0',
      id: 2,
      method: 'tools/call',
      params: { name: 'hello', arguments: { name: 'Contract' } },
    }),
  }));

  const body = await response.json();
  assert.equal(body.result.structuredContent.pluginId, 'cloud-market-hello');
  assert.equal(body.result.structuredContent.message, 'Hello, Contract!');
  assert.equal(body.result.content[0].text, 'Hello, Contract! [cloud-market-hello]');
});
