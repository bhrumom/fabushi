import assert from 'node:assert/strict';
import test from 'node:test';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  generateHumanCallIceServers,
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
  assert.match(handler, /FABUSHI_TURN_KEY_ID/);
  assert.match(handler, /FABUSHI_TURN_KEY_API_TOKEN/);
  assert.match(handler, /rtc\.live\.cloudflare\.com\/v1\/turn\/keys/);
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

test('ICE configuration is short-lived, server-minted, and fail-closed', async () => {
  assert.deepEqual(
    normalizeHumanCallIceServers([
      { urls: ['stun:stun.cloudflare.com:3478'] },
      { urls: 'turns:turn.cloudflare.com:5349?transport=tcp', username: 'u', credential: 'p' },
    ]),
    [
      { urls: ['stun:stun.cloudflare.com:3478'] },
      { urls: ['turns:turn.cloudflare.com:5349?transport=tcp'], username: 'u', credential: 'p' },
    ],
  );
  assert.throws(() => normalizeHumanCallIceServers([]), /1-16/);
  assert.throws(
    () => normalizeHumanCallIceServers([{ urls: ['https://not-ice.invalid'] }]),
    /URL is invalid/,
  );

  const requests = [];
  const generated = await generateHumanCallIceServers(
    {
      FABUSHI_TURN_KEY_ID: '0123456789abcdef0123456789abcdef',
      FABUSHI_TURN_KEY_API_TOKEN: 'turn-key-secret-that-never-leaves-the-worker',
      FABUSHI_CALL_ICE_TTL_SECONDS: '1800',
    },
    async (url, init) => {
      requests.push({ url, init });
      return new Response(JSON.stringify({
        iceServers: [
          { urls: ['stun:stun.cloudflare.com:3478'] },
          {
            urls: ['turn:turn.cloudflare.com:3478?transport=udp', 'turns:turn.cloudflare.com:5349?transport=tcp'],
            username: 'short-lived-user',
            credential: 'short-lived-password',
          },
        ],
      }), { status: 201, headers: { 'content-type': 'application/json' } });
    },
  );
  assert.equal(generated.ttlSeconds, 1800);
  assert.equal(generated.iceServers.length, 2);
  assert.equal(requests.length, 1);
  assert.equal(
    requests[0].url,
    'https://rtc.live.cloudflare.com/v1/turn/keys/0123456789abcdef0123456789abcdef/credentials/generate-ice-servers',
  );
  assert.equal(requests[0].init.method, 'POST');
  assert.equal(requests[0].init.headers.authorization, 'Bearer turn-key-secret-that-never-leaves-the-worker');
  assert.deepEqual(JSON.parse(requests[0].init.body), { ttl: 1800 });

  await assert.rejects(
    () => generateHumanCallIceServers(
      {
        FABUSHI_TURN_KEY_ID: '0123456789abcdef0123456789abcdef',
        FABUSHI_TURN_KEY_API_TOKEN: 'secret',
      },
      async () => new Response('forbidden', { status: 403 }),
    ),
    /HTTP 403/,
  );
  await assert.rejects(
    () => generateHumanCallIceServers(
      {
        FABUSHI_TURN_KEY_ID: '0123456789abcdef0123456789abcdef',
        FABUSHI_TURN_KEY_API_TOKEN: 'secret',
      },
      async () => new Response(JSON.stringify({ iceServers: [{ urls: ['stun:stun.cloudflare.com:3478'] }] }), { status: 201 }),
    ),
    /does not contain authenticated TURN servers/,
  );
});
