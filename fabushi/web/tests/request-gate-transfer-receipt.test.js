import assert from 'node:assert/strict';
import { webcrypto } from 'node:crypto';
import test from 'node:test';

import { generateToken } from '../auth-utils.js';
import { enforceRequestSecurityGate } from '../src/security/request-gate.js';

if (!globalThis.crypto) globalThis.crypto = webcrypto;

const JWT_SECRET = 'transfer-gate-jwt-secret-that-is-at-least-32-bytes';
const TRANSFER_RECEIPT_SECRET = 'transfer-receipt-secret-that-is-at-least-32-bytes';

function createEnv() {
  const values = new Map();
  return {
    JWT_SECRET,
    TRANSFER_RECEIPT_SECRET,
    USERS_KV: {
      async get(key) { return values.get(key) ?? null; },
      async put(key, value) { values.set(key, value); },
    },
  };
}

function createDb() {
  return {
    async getUserById(id) {
      return Number(id) === 7 ? { id: 7, username: 'transfer_user', email: 'transfer@example.com' } : null;
    },
    async getUser(username) {
      return username === 'transfer_user' ? { id: 7, username, email: 'transfer@example.com' } : null;
    },
  };
}

async function signReceipt(payload, secret = TRANSFER_RECEIPT_SECRET) {
  const payloadPart = Buffer.from(JSON.stringify(payload)).toString('base64url');
  const key = await crypto.subtle.importKey(
    'raw',
    new TextEncoder().encode(secret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign('HMAC', key, new TextEncoder().encode(payloadPart));
  return `${payloadPart}.${Buffer.from(signature).toString('base64url')}`;
}

async function buildRequest({ bytes = 4096, jti = 'transfer_receipt_0001', userId = 7, receiptBytes = bytes } = {}) {
  const env = createEnv();
  const token = await generateToken({ id: 7, username: 'transfer_user' }, env);
  const receipt = await signReceipt({
    userId,
    bytes: receiptBytes,
    exp: Math.floor(Date.now() / 1000) + 300,
    jti,
  });
  const request = new Request('https://api.example.com/api/leaderboard/update', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      'X-Fabushi-Transfer-Receipt': receipt,
    },
    body: JSON.stringify({ bytes }),
  });
  return { env, request };
}

test('transfer metric accepts a matching server-signed receipt once', async () => {
  const { env, request } = await buildRequest();
  const db = createDb();
  assert.equal(await enforceRequestSecurityGate(request, env, db), null);

  const replay = await enforceRequestSecurityGate(request, env, db);
  assert.equal(replay.status, 409);
  assert.match((await replay.json()).error, /已使用/);
});

test('transfer metric rejects a signed receipt whose byte count differs from the request', async () => {
  const { env, request } = await buildRequest({ bytes: 4096, receiptBytes: 8192, jti: 'transfer_receipt_0002' });
  const response = await enforceRequestSecurityGate(request, env, createDb());
  assert.equal(response.status, 403);
  assert.match((await response.json()).error, /不匹配/);
});

test('transfer metric rejects a receipt bound to another account', async () => {
  const { env, request } = await buildRequest({ userId: 99, jti: 'transfer_receipt_0003' });
  const response = await enforceRequestSecurityGate(request, env, createDb());
  assert.equal(response.status, 403);
  assert.match((await response.json()).error, /不属于当前账号/);
});
