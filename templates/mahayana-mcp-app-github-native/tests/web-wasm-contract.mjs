import assert from 'node:assert/strict';
import fs from 'node:fs';
import vm from 'node:vm';

vm.runInThisContext(fs.readFileSync('.test-runtime/web/wasm_exec.js', 'utf8'), { filename: 'wasm_exec.js' });
const go = new Go();
const bytes = fs.readFileSync('.test-runtime/web/mahayana-app.wasm');
const instance = await WebAssembly.instantiate(bytes, go.importObject);
go.run(instance.instance);
for (let attempt = 0; attempt < 100 && typeof globalThis.mahayanaMcpCall !== 'function'; attempt += 1) {
  await new Promise((resolve) => setTimeout(resolve, 10));
}
assert.equal(typeof globalThis.mahayanaMcpCall, 'function');
let id = 0;
const call = (method, params = {}) => JSON.parse(globalThis.mahayanaMcpCall(JSON.stringify({ jsonrpc: '2.0', id: ++id, method, params })));
const sent = call('tools/call', { name: 'send', arguments: { text: 'wasm contract' } });
assert.equal(sent.error, undefined);
assert.ok(sent.result.content);
assert.equal(sent.result.structuredContent.task.status, 'queued');
const taskId = sent.result.structuredContent.task.id;
assert.equal(call('tools/call', { name: 'status', arguments: { taskId } }).result.structuredContent.task.id, taskId);
assert.equal(call('tools/call', { name: 'cancel', arguments: { taskId } }).result.structuredContent.task.status, 'cancelled');
assert.ok(Array.isArray(call('tools/call', { name: 'logs', arguments: {} }).result.structuredContent.logs));

process.exit(0);
