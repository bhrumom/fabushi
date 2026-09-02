'use strict';

const assert = require('node:assert/strict');
const { EventEmitter } = require('node:events');
const { PassThrough } = require('node:stream');
const test = require('node:test');
const { RustDeskSidecarProcess, binaryPath, cleanEnvironment, PROTOCOL } = require('./rustdesk-sidecar-process.cjs');

function fakeChild() {
  const child = new EventEmitter();
  child.stdin = new PassThrough();
  child.stdout = new PassThrough();
  child.stderr = new PassThrough();
  child.killed = false;
  child.kill = () => { child.killed = true; child.emit('exit', null, 'SIGTERM'); };
  return child;
}

function harness(options = {}) {
  const children = [];
  const app = options.app || { isPackaged: false };
  const fs = { existsSync: () => true };
  const manager = new RustDeskSidecarProcess({
    app,
    fs,
    env: { PATH: '/bin', FABUSHI_RUSTDESK_SIDECAR_BIN: '/tmp/fabushi-sidecar', MAHAYANA_AUTH_TOKEN: 'must-not-leak', ...options.env },
    resourcesPath: '/resources',
    platform: options.platform || 'linux',
    spawn(command, args, spawnOptions) {
      const child = fakeChild();
      child.command = command;
      child.args = args;
      child.spawnOptions = spawnOptions;
      children.push(child);
      return child;
    },
  });
  return { manager, children };
}

function readWritten(stream) {
  const chunks = [];
  stream.on('data', (chunk) => chunks.push(Buffer.from(chunk)));
  return () => Buffer.concat(chunks).toString('utf8');
}

test('production binary path cannot be overridden by inherited environment', () => {
  const fs = { existsSync: () => true };
  assert.equal(binaryPath({ app: { isPackaged: true }, env: { FABUSHI_RUSTDESK_SIDECAR_BIN: '/evil' }, resourcesPath: '/signed', platform: 'win32', fsImpl: fs }), '/signed/rustdesk-sidecar/fabushi-sidecar.exe');
});

test('sidecar receives a minimal environment without Fabushi account credentials', () => {
  const env = cleanEnvironment({ PATH: '/bin', HOME: '/home/user', MAHAYANA_AUTH_TOKEN: 'secret', FABUSHI_ACCOUNT_TOKEN: 'secret2' });
  assert.deepEqual(env, { PATH: '/bin', HOME: '/home/user' });
});

test('manager freezes grants and blocks input escalation before writing to sidecar', () => {
  const { manager, children } = harness();
  manager.start();
  const output = readWritten(children[0].stdin);
  const opened = manager.open({ sessionId: 'session-1', peerId: '123456789', password: 'ephemeral', grant: { display: true, input: false, clipboard: false, fileTransfer: false, audio: false } });
  assert.equal(opened.grant.input, false);
  assert.throws(() => manager.command('session-1', { type: 'mouse', x: 1, y: 1, mask: 0 }), /not granted/);
  assert.match(output(), new RegExp(`"protocol":"${PROTOCOL.replaceAll('.', '\\.')}`));
  assert.match(output(), /"type":"open"/);
  assert.doesNotMatch(output(), /MAHAYANA_AUTH_TOKEN|FABUSHI_ACCOUNT_TOKEN/);
});

test('unknown-session events terminate the provider process instead of crossing session boundaries', () => {
  const { manager, children } = harness();
  manager.start();
  children[0].stdout.write(`${JSON.stringify({ protocol: PROTOCOL, type: 'frameBegin', sessionId: 'attacker', detail: {} })}\n`);
  assert.equal(children[0].killed, true);
});

test('close and process exit revoke all local session state', () => {
  const { manager, children } = harness();
  manager.open({ sessionId: 'session-1', peerId: '123456789', password: 'ephemeral', grant: { display: true, input: true, clipboard: false, fileTransfer: false, audio: false } });
  assert.equal(manager.sessions.size, 1);
  manager.closeSession('session-1');
  assert.equal(manager.sessions.size, 0);
  manager.open({ sessionId: 'session-2', peerId: '123456789', password: 'ephemeral', grant: { display: true, input: true, clipboard: false, fileTransfer: false, audio: false } });
  children[0].emit('exit', 1, null);
  assert.equal(manager.sessions.size, 0);
  assert.equal(manager.child, null);
});
