const CANONICAL_VOIP_TOPIC = 'com.ombhrum.fabushi.voip';
const APNS_PRODUCTION_ORIGIN = 'https://api.push.apple.com';
const MAX_TOKEN_CHARS = 512;
const MAX_DISPLAY_NAME_CHARS = 200;
const cachedProviderTokens = new Map();

function bounded(value, label, max) {
  const text = String(value ?? '').trim();
  if (!text || text.length > max || /[\u0000-\u001f\u007f]/u.test(text)) {
    throw new Error(label + ' is invalid');
  }
  return text;
}

function base64Url(bytes) {
  let binary = '';
  const array = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  for (const byte of array) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/gu, '-').replace(/\//gu, '_').replace(/=+$/gu, '');
}

function pemPkcs8Bytes(value) {
  const pem = String(value ?? '').trim();
  if (
    pem.length < 64
    || pem.length > 16 * 1024
    || !pem.startsWith('-----BEGIN PRIVATE KEY-----')
    || !pem.endsWith('-----END PRIVATE KEY-----')
  ) {
    throw new Error('FABUSHI_APNS_PRIVATE_KEY is invalid');
  }
  const body = pem
    .replace(/-----BEGIN PRIVATE KEY-----/gu, '')
    .replace(/-----END PRIVATE KEY-----/gu, '')
    .replace(/\s+/gu, '');
  if (!/^[A-Za-z0-9+/=]+$/u.test(body)) throw new Error('FABUSHI_APNS_PRIVATE_KEY is invalid');
  const binary = atob(body);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0));
}

export function normalizeHumanCallVoIPToken(value) {
  const token = String(value ?? '').trim().toLowerCase();
  if (token.length < 32 || token.length > MAX_TOKEN_CHARS || !/^[0-9a-f]+$/u.test(token) || token.length % 2 !== 0) {
    throw new Error('humanCallVoIPToken is invalid');
  }
  return token;
}

export function normalizeHumanCallPushPayload(value) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Human Call push payload is invalid');
  const callId = bounded(value.callId, 'callId', 200);
  const generation = Number(value.generation);
  if (!Number.isSafeInteger(generation) || generation < 0) throw new Error('generation is invalid');
  const displayName = bounded(value.displayName || 'Fabushi 通话', 'displayName', MAX_DISPLAY_NAME_CHARS);
  return { callId, generation, displayName, hasVideo: value.hasVideo === true };
}

async function providerToken(env, now = Date.now) {
  const teamId = bounded(env.FABUSHI_APNS_TEAM_ID, 'FABUSHI_APNS_TEAM_ID', 32);
  const keyId = bounded(env.FABUSHI_APNS_KEY_ID, 'FABUSHI_APNS_KEY_ID', 32);
  if (!/^[A-Z0-9]{6,32}$/u.test(teamId) || !/^[A-Z0-9]{6,32}$/u.test(keyId)) {
    throw new Error('APNs signing identity is invalid');
  }
  const issuedAt = Math.floor(now() / 1000);
  const cacheKey = teamId + ':' + keyId;
  const cached = cachedProviderTokens.get(cacheKey);
  if (cached && issuedAt - cached.issuedAt < 45 * 60) return cached.token;

  const header = new TextEncoder().encode(JSON.stringify({ alg: 'ES256', kid: keyId }));
  const claims = new TextEncoder().encode(JSON.stringify({ iss: teamId, iat: issuedAt }));
  const signingInput = base64Url(header) + '.' + base64Url(claims);
  const key = await crypto.subtle.importKey(
    'pkcs8',
    pemPkcs8Bytes(env.FABUSHI_APNS_PRIVATE_KEY),
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    key,
    new TextEncoder().encode(signingInput),
  );
  const token = signingInput + '.' + base64Url(signature);
  cachedProviderTokens.set(cacheKey, { token, issuedAt });
  return token;
}

function permanentTokenFailure(status, reason) {
  return status === 410
    || (status === 400 && ['BadDeviceToken', 'DeviceTokenNotForTopic', 'Unregistered'].includes(reason));
}

export async function sendHumanCallVoIPPush(env, deviceToken, rawPayload, fetchImpl = fetch, now = Date.now) {
  const token = normalizeHumanCallVoIPToken(deviceToken);
  const payload = normalizeHumanCallPushPayload(rawPayload);
  const topic = String(env.FABUSHI_APNS_VOIP_TOPIC || CANONICAL_VOIP_TOPIC).trim();
  if (topic !== CANONICAL_VOIP_TOPIC) throw new Error('FABUSHI_APNS_VOIP_TOPIC must match the shipping iOS VoIP topic');
  const authorization = await providerToken(env, now);
  const response = await fetchImpl(APNS_PRODUCTION_ORIGIN + '/3/device/' + token, {
    method: 'POST',
    headers: {
      authorization: 'bearer ' + authorization,
      'apns-push-type': 'voip',
      'apns-topic': topic,
      'apns-priority': '10',
      'apns-expiration': '0',
      'content-type': 'application/json',
    },
    body: JSON.stringify({ aps: { 'content-available': 1 }, ...payload }),
  });
  let reason = '';
  if (!response.ok) {
    try {
      const body = await response.json();
      reason = String(body?.reason || '').slice(0, 120);
    } catch {}
  }
  return {
    ok: response.ok,
    status: response.status,
    reason,
    permanentInvalid: permanentTokenFailure(response.status, reason),
  };
}

export const humanCallVoIPTopic = CANONICAL_VOIP_TOPIC;
