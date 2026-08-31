"use strict";

const assert = require('node:assert/strict');
const fs = require('node:fs');
const Module = require('node:module');
const os = require('node:os');
const path = require('node:path');
const test = require('node:test');

const defaultApp = {
  isPackaged: true,
  getPath(name) {
    if (name !== 'userData') throw new Error(`unexpected path: ${name}`);
    return '/tmp/fabushi-remote-device-test';
  },
};
const originalLoad = Module._load;
Module._load = function load(request, parent, isMain) {
  if (request === 'electron') return { app: defaultApp };
  return originalLoad.call(this, request, parent, isMain);
};
const {
  OFFICIAL_DEVICE_GATEWAY_URL,
  remoteDeviceGatewayUrl,
  remoteDeviceRuntime,
  validAgentSession,
} = require('./remote-device-agent-supervisor.cjs');
Module._load = originalLoad;

test('packaged apps always use the official account-scoped device gateway', () => {
  assert.equal(remoteDeviceGatewayUrl({ isPackaged: true }, {
    FABUSHI_REMOTE_DEVICE_GATEWAY_URL: 'wss://attacker.example/agent',
  }), OFFICIAL_DEVICE_GATEWAY_URL);
  assert.equal(remoteDeviceGatewayUrl({ isPackaged: false }, {}), null);
  assert.throws(
    () => remoteDeviceGatewayUrl({ isPackaged: false }, { FABUSHI_REMOTE_DEVICE_GATEWAY_URL: 'https://example.test/agent' }),
    /clean wss/u,
  );
});

test('device agent receives a bounded access session identity', () => {
  const session = validAgentSession({
    accessToken: 'a'.repeat(64),
    deviceId: 'desktop:stable-device',
    sessionId: 'account-session:stable-device',
    username: 'tester',
    accessTokenExpiresAt: 12345,
  });
  assert.equal(session.deviceId, 'desktop:stable-device');
  assert.equal(session.accessToken.length, 64);
  assert.equal(validAgentSession({ ...session, accessToken: 'short' }), null);
  assert.equal(validAgentSession({ ...session, deviceId: '../unsafe' }), null);
});

test('remote registration is available only from a complete embedded runtime', () => {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'fabushi-remote-runtime-'));
  try {
    const runtime = path.join(root, 'runtime');
    const bin = path.join(runtime, 'bin');
    fs.mkdirSync(bin, { recursive: true });
    fs.writeFileSync(path.join(bin, 'fabushi-computer-mcp.js'), '#!/usr/bin/env node\n');
    fs.writeFileSync(path.join(bin, 'fabushi-device-agent.js'), '#!/usr/bin/env node\n');
    for (const relative of [
      'lib/fabushi-computer-policy.js',
      'node_modules/@modelcontextprotocol/sdk/package.json',
      'node_modules/ws/package.json',
      'node_modules/zod/package.json',
    ]) {
      const target = path.join(runtime, relative);
      fs.mkdirSync(path.dirname(target), { recursive: true });
      fs.writeFileSync(target, relative.endsWith('.json') ? '{}\n' : 'export {};\n');
    }
    const selected = remoteDeviceRuntime({
      app: { isPackaged: false, getPath: () => path.join(root, 'data') },
      env: { FABUSHI_COMPUTER_MCP_ENTRY: path.join(bin, 'fabushi-computer-mcp.js') },
      platform: 'linux',
      resourcesPath: root,
      fs,
      execPath: '/opt/fabushi/fabushi',
    });
    assert.equal(selected.agentEntry, path.join(bin, 'fabushi-device-agent.js'));
    fs.rmSync(selected.agentEntry);
    assert.equal(remoteDeviceRuntime({
      app: { isPackaged: false, getPath: () => path.join(root, 'data') },
      env: { FABUSHI_COMPUTER_MCP_ENTRY: path.join(bin, 'fabushi-computer-mcp.js') },
      platform: 'linux',
      resourcesPath: root,
      fs,
      execPath: '/opt/fabushi/fabushi',
    }), null);
  } finally {
    fs.rmSync(root, { recursive: true, force: true });
  }
});
