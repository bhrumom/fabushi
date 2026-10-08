import assert from 'node:assert/strict';
import test from 'node:test';
import { generateKeyPairSync } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

import {
  deliverIncomingHumanCall,
  generateHumanCallIceServers,
  normalizeHumanCallDeviceId,
  normalizeHumanCallIceServers,
  projectHumanCallTransition,
} from '../src/handlers/human-calls.js';
import {
  humanCallVoIPTopic,
  normalizeHumanCallPushPayload,
  normalizeHumanCallVoIPToken,
  sendHumanCallVoIPPush,
} from '../src/utils/human-call-apns.js';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const router = readFileSync(join(root, 'src/routes/community-routes.js'), 'utf8');
const handler = readFileSync(join(root, 'src/handlers/human-calls.js'), 'utf8');
const migration = readFileSync(join(root, 'migrations/20261006_human_calls.sql'), 'utf8');
const pushMigration = readFileSync(join(root, 'migrations/20261009_human_call_voip_push.sql'), 'utf8');

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


test('PushKit registration and APNs payload contracts are strict and secret-free', async () => {
  const token = 'ab'.repeat(32);
  assert.equal(normalizeHumanCallVoIPToken(token.toUpperCase()), token);
  assert.throws(() => normalizeHumanCallVoIPToken('not-a-token'), /invalid/);
  assert.throws(() => normalizeHumanCallVoIPToken('a'.repeat(33)), /invalid/);
  assert.equal(humanCallVoIPTopic, 'com.ombhrum.fabushi.voip');
  assert.deepEqual(
    normalizeHumanCallPushPayload({ callId: 'call-1', generation: 4, displayName: 'Alice', hasVideo: true }),
    { callId: 'call-1', generation: 4, displayName: 'Alice', hasVideo: true },
  );
  assert.throws(() => normalizeHumanCallPushPayload({ callId: 'call-1', generation: -1 }), /generation/);

  const { privateKey } = generateKeyPairSync('ec', { namedCurve: 'P-256' });
  const pem = privateKey.export({ type: 'pkcs8', format: 'pem' }).toString();
  const env = {
    FABUSHI_APNS_TEAM_ID: 'TEAMID1234',
    FABUSHI_APNS_KEY_ID: 'KEYID12345',
    FABUSHI_APNS_PRIVATE_KEY: pem,
  };
  const requests = [];
  const delivered = await sendHumanCallVoIPPush(env, token, {
    callId: 'call-1',
    generation: 4,
    displayName: 'Alice',
    hasVideo: true,
  }, async (url, init) => {
    requests.push({ url, init });
    return new Response(null, { status: 200 });
  }, () => 1_800_000_000_000);
  assert.equal(delivered.ok, true);
  assert.equal(requests.length, 1);
  assert.equal(requests[0].url, 'https://api.push.apple.com/3/device/' + token);
  assert.equal(requests[0].init.headers['apns-push-type'], 'voip');
  assert.equal(requests[0].init.headers['apns-topic'], 'com.ombhrum.fabushi.voip');
  assert.equal(requests[0].init.headers['apns-priority'], '10');
  assert.deepEqual(JSON.parse(requests[0].init.body), {
    aps: { 'content-available': 1 },
    callId: 'call-1',
    generation: 4,
    displayName: 'Alice',
    hasVideo: true,
  });
  assert.ok(/^bearer eyJ/u.test(requests[0].init.headers.authorization));
  assert.equal(requests[0].init.headers.authorization.includes(token), false);

  const invalid = await sendHumanCallVoIPPush(env, token, {
    callId: 'call-2',
    generation: 0,
    displayName: 'Bob',
    hasVideo: false,
  }, async () => new Response(JSON.stringify({ reason: 'Unregistered' }), {
    status: 410,
    headers: { 'content-type': 'application/json' },
  }), () => 1_800_000_000_000);
  assert.deepEqual(invalid, {
    ok: false,
    status: 410,
    reason: 'Unregistered',
    permanentInvalid: true,
  });

  const retryable = await sendHumanCallVoIPPush(env, token, {
    callId: 'call-3',
    generation: 0,
    displayName: 'Carol',
    hasVideo: false,
  }, async () => new Response(JSON.stringify({ reason: 'InternalServerError' }), {
    status: 500,
    headers: { 'content-type': 'application/json' },
  }), () => 1_800_000_000_000);
  assert.equal(retryable.permanentInvalid, false);
});

test('Human Call push storage stays account+device scoped and idempotent', () => {
  assert.match(pushMigration, /PRIMARY KEY \(user_id, device_id\)/i);
  assert.match(pushMigration, /UNIQUE INDEX IF NOT EXISTS idx_human_call_voip_token_unique/i);
  assert.match(pushMigration, /PRIMARY KEY \(call_id, generation, device_id\)/i);
  assert.match(pushMigration, /retryable-failure/i);
  assert.match(handler, /ON CONFLICT\(user_id, device_id\) DO UPDATE/i);
  assert.match(handler, /existing\?\.status === 'delivered'/);
  assert.match(handler, /result\.permanentInvalid/);
  assert.match(handler, /DELETE FROM human_call_voip_devices WHERE user_id = \? AND device_id = \? AND voip_token = \?/);
  assert.ok(router.includes('/api/social/calls/voip-device'));
});


test('stale-generation idempotent replay reuses the persisted event and wakes at most once', () => {
  const catchReplay = handler.match(
    /catch \(error\) \{[\s\S]*?if \(existing\) \{[\s\S]*?const replayExpected = \{[\s\S]*?if \(existingEventMatches\(existing, replayExpected, identity\.deviceId\)\) \{([\s\S]*?)return jsonResponse\(\{ success: true, call: projectCall\(row\), event: projectEvent\(existing\) \}\);/
  );
  assert.ok(catchReplay, 'stale replay branch must stay explicit');
  const branch = catchReplay[1];
  assert.equal((branch.match(/maybeDeliverCreatorMediaWake/g) || []).length, 1);
  assert.match(branch, /\.\.\.replayExpected/);
  assert.match(branch, /role: roleFor\(row, identity\.auth\.userId\)/);
  assert.doesNotMatch(branch, /maybeDeliverCreatorMediaWake\(env, db, row, identity, expected\)/);
  assert.match(handler, /stale call generation: expected/);
});


class MemoryPushDb {
  constructor(devices = []) {
    this.devices = new Map(devices.map((entry) => [entry.deviceId, {
      userId: entry.userId,
      deviceId: entry.deviceId,
      token: entry.token,
      lastSuccessAt: null,
      lastFailureAt: null,
    }]));
    this.deliveries = new Map();
  }

  prepare(sql) {
    return {
      bind: (...args) => ({
        all: async () => {
          if (/SELECT device_id, voip_token FROM human_call_voip_devices/u.test(sql)) {
            const [userId] = args;
            return {
              results: [...this.devices.values()]
                .filter((entry) => entry.userId === userId)
                .sort((left, right) => left.deviceId.localeCompare(right.deviceId))
                .map((entry) => ({ device_id: entry.deviceId, voip_token: entry.token })),
            };
          }
          throw new Error('unsupported all SQL: ' + sql);
        },
        first: async () => {
          if (/SELECT status, attempt_count FROM human_call_push_deliveries/u.test(sql)) {
            const [callId, generation, deviceId] = args;
            return this.deliveries.get(`${callId}:${generation}:${deviceId}`) ?? null;
          }
          throw new Error('unsupported first SQL: ' + sql);
        },
        run: async () => {
          if (/INSERT INTO human_call_push_deliveries/u.test(sql)) {
            const [callId, generation, deviceId, attemptCount] = args;
            const key = `${callId}:${generation}:${deviceId}`;
            const previous = this.deliveries.get(key);
            this.deliveries.set(key, {
              status: 'pending',
              attempt_count: attemptCount,
              last_http_status: previous?.last_http_status ?? null,
              last_reason: previous?.last_reason ?? null,
            });
            return { meta: { changes: 1 } };
          }
          if (/UPDATE human_call_push_deliveries SET status/u.test(sql)) {
            const [status, httpStatus, reason, _updatedAt, callId, generation, deviceId] = args;
            const key = `${callId}:${generation}:${deviceId}`;
            const previous = this.deliveries.get(key) ?? { attempt_count: 0 };
            this.deliveries.set(key, {
              ...previous,
              status,
              last_http_status: httpStatus,
              last_reason: reason,
            });
            return { meta: { changes: 1 } };
          }
          if (/UPDATE human_call_voip_devices SET last_success_at/u.test(sql)) {
            const [_timestamp, userId, deviceId] = args;
            const device = this.devices.get(deviceId);
            assert.equal(device?.userId, userId);
            device.lastSuccessAt = 'set';
            device.lastFailureAt = null;
            return { meta: { changes: 1 } };
          }
          if (/UPDATE human_call_voip_devices SET last_failure_at/u.test(sql)) {
            const [_timestamp, userId, deviceId] = args;
            const device = this.devices.get(deviceId);
            assert.equal(device?.userId, userId);
            device.lastFailureAt = 'set';
            return { meta: { changes: 1 } };
          }
          if (/DELETE FROM human_call_voip_devices WHERE user_id = \? AND device_id = \? AND voip_token = \?/u.test(sql)) {
            const [userId, deviceId, token] = args;
            const device = this.devices.get(deviceId);
            if (device?.userId === userId && device.token === token) this.devices.delete(deviceId);
            return { meta: { changes: device ? 1 : 0 } };
          }
          throw new Error('unsupported run SQL: ' + sql);
        },
      }),
    };
  }
}

function apnsTestEnv() {
  const { privateKey } = generateKeyPairSync('ec', { namedCurve: 'P-256' });
  return {
    FABUSHI_APNS_TEAM_ID: 'TEAMID1234',
    FABUSHI_APNS_KEY_ID: 'KEYID12345',
    FABUSHI_APNS_PRIVATE_KEY: privateKey.export({ type: 'pkcs8', format: 'pem' }).toString(),
  };
}

test('Human Call wake delivery handles no-token and multiple devices without duplicate delivery', async () => {
  const noDeviceDb = new MemoryPushDb();
  let fetchCount = 0;
  const noTargets = await deliverIncomingHumanCall(
    apnsTestEnv(),
    noDeviceDb,
    { call_id: 'call-empty', peer_user_id: 7, state: 'ringing', generation: 2 },
    'Alice',
    false,
    async () => {
      fetchCount += 1;
      return new Response(null, { status: 200 });
    },
  );
  assert.deepEqual(noTargets, []);
  assert.equal(fetchCount, 0);

  const db = new MemoryPushDb([
    { userId: 7, deviceId: 'iphone-a', token: 'aa'.repeat(32) },
    { userId: 7, deviceId: 'iphone-b', token: 'bb'.repeat(32) },
    { userId: 8, deviceId: 'other-account', token: 'cc'.repeat(32) },
  ]);
  const sent = [];
  const row = { call_id: 'call-multi', peer_user_id: 7, state: 'ringing', generation: 3 };
  const first = await deliverIncomingHumanCall(apnsTestEnv(), db, row, 'Alice', true, async (url, init) => {
    sent.push({ url, body: JSON.parse(init.body) });
    return new Response(null, { status: 200 });
  });
  assert.equal(first.length, 2);
  assert.equal(sent.length, 2);
  assert.deepEqual(first.map((entry) => entry.deviceId), ['iphone-a', 'iphone-b']);
  assert.ok(sent.every((entry) => entry.body.callId === 'call-multi'));
  assert.ok(sent.every((entry) => entry.body.generation === 3));
  assert.ok(sent.every((entry) => entry.body.hasVideo === true));

  const replay = await deliverIncomingHumanCall(apnsTestEnv(), db, row, 'Alice', true, async () => {
    throw new Error('delivered replay must not contact APNs again');
  });
  assert.deepEqual(replay, [
    { deviceId: 'iphone-a', status: 'delivered', replay: true },
    { deviceId: 'iphone-b', status: 'delivered', replay: true },
  ]);
});

test('Human Call wake delivery retries transient failures and revokes APNs-invalid tokens', async () => {
  const db = new MemoryPushDb([
    { userId: 11, deviceId: 'iphone-retry', token: 'dd'.repeat(32) },
    { userId: 11, deviceId: 'iphone-invalid', token: 'ee'.repeat(32) },
  ]);
  const row = { call_id: 'call-retry', peer_user_id: 11, state: 'ringing', generation: 5 };
  let retryAttempts = 0;
  const first = await deliverIncomingHumanCall(apnsTestEnv(), db, row, 'Bob', false, async (url) => {
    if (url.endsWith('dd'.repeat(32))) {
      retryAttempts += 1;
      return new Response(JSON.stringify({ reason: 'InternalServerError' }), {
        status: 500,
        headers: { 'content-type': 'application/json' },
      });
    }
    return new Response(JSON.stringify({ reason: 'Unregistered' }), {
      status: 410,
      headers: { 'content-type': 'application/json' },
    });
  });
  assert.deepEqual(first.map((entry) => entry.status), ['invalid-token', 'retryable-failure'].sort());
  assert.equal(db.devices.has('iphone-invalid'), false);
  assert.equal(db.devices.has('iphone-retry'), true);
  assert.equal(db.deliveries.get('call-retry:5:iphone-retry').attempt_count, 1);

  const second = await deliverIncomingHumanCall(apnsTestEnv(), db, row, 'Bob', false, async (url) => {
    assert.ok(url.endsWith('dd'.repeat(32)));
    retryAttempts += 1;
    return new Response(null, { status: 200 });
  });
  assert.deepEqual(second, [{ deviceId: 'iphone-retry', status: 'delivered', replay: false }]);
  assert.equal(retryAttempts, 2);
  assert.equal(db.deliveries.get('call-retry:5:iphone-retry').attempt_count, 2);
  assert.equal(db.deliveries.get('call-retry:5:iphone-retry').status, 'delivered');
});

test('Human Call wake delivery rejects stale/non-ringing session state before APNs', async () => {
  const db = new MemoryPushDb([
    { userId: 9, deviceId: 'iphone-a', token: 'aa'.repeat(32) },
  ]);
  let fetchCount = 0;
  for (const row of [
    { call_id: 'call-ended', peer_user_id: 9, state: 'ended', generation: 3 },
    { call_id: 'call-bad-generation', peer_user_id: 9, state: 'ringing', generation: -1 },
  ]) {
    assert.deepEqual(
      await deliverIncomingHumanCall(apnsTestEnv(), db, row, 'Alice', false, async () => {
        fetchCount += 1;
        return new Response(null, { status: 200 });
      }),
      [],
    );
  }
  assert.equal(fetchCount, 0);
});
