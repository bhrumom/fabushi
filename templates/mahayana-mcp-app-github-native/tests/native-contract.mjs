import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import readline from 'node:readline';

const child = spawn('./.test-runtime/native/mahayana-app', [], { stdio: ['pipe', 'pipe', 'inherit'] });
const lines = readline.createInterface({ input: child.stdout });
const pending = new Map();
lines.on('line', (line) => {
  const message = JSON.parse(line);
  pending.get(message.id)?.(message);
  pending.delete(message.id);
});
let id = 0;
const call = (method, params = {}) => new Promise((resolve) => {
  const requestId = ++id;
  pending.set(requestId, resolve);
  child.stdin.write(`${JSON.stringify({ jsonrpc: '2.0', id: requestId, method, params })}
`);
});
const sent = await call('tools/call', { name: 'send', arguments: { text: 'native contract' } });
assert.equal(sent.error, undefined);
assert.ok(sent.result.content);
assert.equal(sent.result.structuredContent.task.status, 'queued');
const taskId = sent.result.structuredContent.task.id;
assert.equal((await call('tools/call', { name: 'status', arguments: { taskId } })).result.structuredContent.task.id, taskId);
assert.equal((await call('tools/call', { name: 'cancel', arguments: { taskId } })).result.structuredContent.task.status, 'cancelled');
assert.ok(Array.isArray((await call('tools/call', { name: 'logs', arguments: {} })).result.structuredContent.logs));
child.stdin.end();
await new Promise((resolve, reject) => {
  child.once('exit', (code) => code === 0 ? resolve() : reject(new Error(`native exited ${code}`)));
});
