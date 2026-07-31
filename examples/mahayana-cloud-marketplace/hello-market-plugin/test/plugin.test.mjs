import assert from 'node:assert/strict';
import test from 'node:test';
import { handleRequest, helloResult } from '../scripts/cloud-market-hello.mjs';
import worker from '../worker/src/index.ts';

test('local runtime returns deterministic marketplace identity', () => {
  assert.deepEqual(helloResult('CLI'), {
    message: 'Hello, CLI!',
    pluginId: 'cloud-market-hello',
    version: '1.0.0',
    deployment: 'independent-cloudflare-worker',
  });
});

test('stdio MCP exposes and runs hello', () => {
  const listed = handleRequest({ jsonrpc: '2.0', id: 1, method: 'tools/list' });
  assert.equal(listed.result.tools[0].name, 'hello');
  assert.equal(listed.result.tools[0].annotations.readOnlyHint, true);
  const called = handleRequest({
    jsonrpc: '2.0', id: 2, method: 'tools/call',
    params: { name: 'hello', arguments: { name: 'Market' } },
  });
  assert.equal(called.result.structuredContent.message, 'Hello, Market!');
  assert.equal(called.result.content[0].text, 'Hello, Market! [cloud-market-hello]');
});

test('Cloudflare Worker serves the same MCP tool', async () => {
  const response = await worker.fetch(new Request('https://example.test/mcp', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      jsonrpc: '2.0', id: 3, method: 'tools/call',
      params: { name: 'hello', arguments: { name: 'Cloudflare' } },
    }),
  }));
  assert.equal(response.status, 200);
  assert.equal((await response.json()).result.structuredContent.message, 'Hello, Cloudflare!');

  const listed = await worker.fetch(new Request('https://example.test/mcp', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ jsonrpc: '2.0', id: 4, method: 'tools/list' }),
  }));
  assert.equal((await listed.json()).result.tools[0].annotations.readOnlyHint, true);
});
