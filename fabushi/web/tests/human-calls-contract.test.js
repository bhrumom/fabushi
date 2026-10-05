import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  normalizeHumanCallDeviceId,
  normalizeHumanCallIceServers,
  projectHumanCallTransition,
} from '../src/handlers/human-calls.js';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const router = readFileSync(join(root, 'src/routes/community-routes.js'), 'utf8');
const handler = readFileSync(join(root, 'src/handlers/human-calls.js'), 'utf8');
const migration = readFileSync(join(root, 'migrations/20261006_human_calls.sql'), 'utf8');

test('production Human call routes exactly match Desktop Host transport', () => {
  for (const path of [
    '/api/social/calls/ice',
    '/api/social/calls',
  ]) {
    assert.ok(router.includes(path), 'missing ' + path);
  }
  assert.match(router, /calls\\\/\(\[\^\/\]\+\)\\\/events/);
  assert.match(router, /calls\\\/\(\[\^\/\]\+\)\$\//);
  assert.match(handler, /requireAuthIdentity\(request, env, db\)/);
  assert.match(handler, /x-fabushi-device-id/);
  assert.match(handler, /FABUSHI_CALL_ICE_SERVERS_JSON/);
});

test('Human call storage owns device leases, monotonic replay, and idempotency', () => {
  assert.match(migration, /CREATE TABLE IF NOT EXISTS human_calls/i);
  assert.match(migration, /creator_device_id TEXT/i);
  assert.match(migration, /peer_device_id TEXT/i);
  assert.match(migration, /generation INTEGER NOT NULL DEFAULT 0/i);
  assert.match(migration, /event_seq INTEGER NOT NULL DEFAULT 0/i);
  assert.match(migration, /CREATE TABLE IF NOT EXISTS human_call_events/i);
  assert.match(migration, /PRIMARY KEY \(call_id, seq\)/i);
  assert.match(migration, /UNIQUE \(call_id, user_id, client_event_id\)/i);
  assert.match(handler, /event_seq = event_seq \+ 1/);
  assert.match(handler, /db\.batch\(\[/);
  assert.match(handler, /call transport is owned by another device/);
});

test('device identity accepts bounded production IDs and rejects unsafe values', () => {
  assert.equal(normalizeHumanCallDeviceId('gha-37334813964-1-macos-app'), 'gha-37334813964-1-macos-app');
  assert.equal(normalizeHumanCallDeviceId('device:mac.01'), 'device:mac.01');
  assert.throws(() => normalizeHumanCallDeviceId(''), /required/);
  assert.throws(() => normalizeHumanCallDeviceId('bad device'), /invalid/);
  assert.throws(() => normalizeHumanCallDeviceId('bad\nheader'), /control characters/);
});

test('call transition projection mirrors canonical Host generation semantics', () => {
  assert.deepEqual(
    projectHumanCallTransition('invited', 0, 'ring'),
    { state: 'ringing', generation: 0, terminalState: null, terminalReason: null },
  );
  assert.deepEqual(
    projectHumanCallTransition('ringing', 0, 'accept'),
    { state: 'negotiating', generation: 0, terminalState: null, terminalReason: null },
  );
  assert.deepEqual(
    projectHumanCallTransition('negotiating', 0, 'connected'),
    { state: 'connected', generation: 0, terminalState: null, terminalReason: null },
  );
  assert.deepEqual(
    projectHumanCallTransition('connected', 4, 'reconnect'),
    { state: 'reconnecting', generation: 5, terminalState: null, terminalReason: null },
  );
  assert.deepEqual(
    projectHumanCallTransition('reconnecting', 5, 'resume'),
    { state: 'negotiating', generation: 5, terminalState: null, terminalReason: null },
  );
  assert.deepEqual(
    projectHumanCallTransition('connected', 5, 'hangup'),
    { state: 'ended', generation: 5, terminalState: 'ended', terminalReason: 'hangup' },
  );
  assert.throws(() => projectHumanCallTransition('ended', 5, 'reconnect'), /terminal/);
  assert.throws(() => projectHumanCallTransition('connected', 5, 'accept'), /invalid call transition/);
});

test('ICE configuration is explicit and fail-closed', () => {
  assert.deepEqual(
    normalizeHumanCallIceServers(JSON.stringify([
      { urls: ['stun:stun.example.invalid:3478'] },
      { urls: 'turns:turn.example.invalid:5349', username: 'u', credential: 'p' },
    ])),
    [
      { urls: ['stun:stun.example.invalid:3478'] },
      { urls: ['turns:turn.example.invalid:5349'], username: 'u', credential: 'p' },
    ],
  );
  assert.throws(() => normalizeHumanCallIceServers(''), /missing/);
  assert.throws(() => normalizeHumanCallIceServers('[]'), /1-16/);
  assert.throws(
    () => normalizeHumanCallIceServers('[{"urls":["https://not-ice.invalid"]}]'),
    /URL is invalid/,
  );
});
