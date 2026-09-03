const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const test = require('node:test');

const source = fs.readFileSync(path.join(__dirname, 'main.cjs'), 'utf8');

test('desktop background presence remains production-only while E2E can shut down', () => {
  assert.match(source, /const backgroundPersistenceEnabled = process\.env\.FABUSHI_E2E !== '1';/);
  assert.match(source, /if \(quitting \|\| !backgroundPersistenceEnabled\) return;/);
  assert.match(source, /if \(!backgroundPersistenceEnabled \|\| backgroundTray\) return;/);
  assert.match(source, /if \(!backgroundPersistenceEnabled\) app\.quit\(\);/);
});

test('runtime event pump uses bounded blocking receive and yields to renderer IPC', () => {
  const pump = source.slice(source.indexOf('function startHostEventPump()'), source.indexOf('function installIpcHandlers()'));
  assert.match(source, /const HOST_EVENT_LONG_POLL_MS = 500;/);
  assert.match(pump, /feature\.receive', \{ timeoutMs: HOST_EVENT_LONG_POLL_MS \}/);
  assert.match(pump, /await new Promise\(\(resolve\) => setImmediate\(resolve\)\);/);
  assert.doesNotMatch(pump, /sleep\(10\)/);
});
