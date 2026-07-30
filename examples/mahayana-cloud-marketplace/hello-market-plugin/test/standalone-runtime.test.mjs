import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import readline from 'node:readline';
import test from 'node:test';

test('standalone runtime initializes without a host', async t => {
  const child = spawn(process.execPath, ['--experimental-strip-types', 'server/index.mjs'], {
    stdio: ['pipe', 'pipe', 'inherit'],
  });
  t.after(() => child.kill());

  const output = readline.createInterface({ input: child.stdout, crlfDelay: Infinity });
  child.stdin.write(`${JSON.stringify({
    jsonrpc: '2.0',
    id: 1,
    method: 'initialize',
    params: { protocolVersion: '2025-06-18' },
  })}\n`);

  const line = await output[Symbol.asyncIterator]().next();
  const response = JSON.parse(line.value);
  assert.equal(response.id, 1);
  assert.equal(response.result.serverInfo.name, 'cloud-market-hello');
});
