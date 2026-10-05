import { jsonResponse } from '../utils/response.js';
import { requireAuthIdentity } from '../utils/auth-identity.js';

const MAX_CALL_ID_CHARS = 200;
const MAX_DEVICE_ID_CHARS = 200;
const MAX_CLIENT_EVENT_ID_CHARS = 300;
const MAX_EVENT_PAYLOAD_BYTES = 256 * 1024;
const MAX_SIGNAL_KIND_CHARS = 64;
const MAX_TERMINAL_REASON_CHARS = 240;
const MAX_ICE_SERVERS = 16;
const MAX_ICE_URLS_PER_SERVER = 16;
const MAX_ICE_VALUE_CHARS = 2048;
const CALL_STATES = new Set([
  'invited',
  'ringing',
  'negotiating',
  'connected',
  'reconnecting',
  'ended',
  'failed',
]);
const TERMINAL_CALL_STATES = new Set(['ended', 'failed']);
const EVENT_KINDS = new Set(['transition', 'signal', 'media']);

function errorResponse(error, status = 400) {
  return jsonResponse({ success: false, error }, status);
}

function boundedText(value, label, maximum) {
  const text = String(value ?? '').trim();
  if (!text) throw new Error(label + ' is required');
  if (text.length > maximum) throw new Error(label + ' exceeds ' + maximum + ' characters');
  if (/[\u0000-\u001f\u007f]/.test(text)) throw new Error(label + ' contains control characters');
  return text;
}

function nonNegativeInteger(value, label) {
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed < 0) throw new Error(label + ' must be a non-negative integer');
  return parsed;
}

function clampLimit(value, fallback = 50, maximum = 200) {
  const parsed = Number.parseInt(String(value ?? ''), 10);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(Math.max(parsed, 1), maximum);
}

function normalizeTerminalReason(value, fallback) {
  const text = String(value ?? '').trim();
  const normalized = text || fallback;
  if (normalized.length > MAX_TERMINAL_REASON_CHARS) {
    throw new Error('call terminal reason exceeds ' + MAX_TERMINAL_REASON_CHARS + ' characters');
  }
  return normalized;
}

function ensureObject(value, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)) {
    throw new Error(label + ' must be an object');
  }
  return value;
}

function stableJson(value) {
  if (Array.isArray(value)) return '[' + value.map(stableJson).join(',') + ']';
  if (value && typeof value === 'object') {
    return '{' + Object.keys(value).sort().map((key) => JSON.stringify(key) + ':' + stableJson(value[key])).join(',') + '}';
  }
  return JSON.stringify(value);
}

function serializedPayload(value) {
  const payload = ensureObject(value, 'call event payload');
  const text = JSON.stringify(payload);
  if (new TextEncoder().encode(text).byteLength > MAX_EVENT_PAYLOAD_BYTES) {
    throw new Error('call event payload is too large');
  }
  return { payload, text };
}

function decodeCallId(rawCallId) {
  let decoded;
  try {
    decoded = decodeURIComponent(String(rawCallId ?? ''));
  } catch {
    throw new Error('call id is invalid');
  }
  return boundedText(decoded, 'call id', MAX_CALL_ID_CHARS);
}

export function normalizeHumanCallDeviceId(value) {
  const deviceId = boundedText(value, 'x-fabushi-device-id', MAX_DEVICE_ID_CHARS);
  if (!/^[A-Za-z0-9][A-Za-z0-9._:-]*$/.test(deviceId)) {
    throw new Error('x-fabushi-device-id is invalid');
  }
  return deviceId;
}

async function requireCallIdentity(request, env, db) {
  const auth = await requireAuthIdentity(request, env, db);
  if (auth.error) return { response: errorResponse(auth.error, auth.status) };
  if (!Number.isFinite(auth.userId)) {
    return { response: errorResponse('账号资料需要刷新后才能使用通话功能', 409) };
  }
  let deviceId;
  try {
    deviceId = normalizeHumanCallDeviceId(request.headers.get('x-fabushi-device-id'));
  } catch (error) {
    return { response: errorResponse(error.message, 400) };
  }
  return { auth, deviceId };
}

async function readJsonBody(request) {
  try {
    return await request.json();
  } catch {
    throw new Error('请求 JSON 无效');
  }
}

async function findUser(db, identifier) {
  const value = String(identifier ?? '').trim();
  if (!value) return null;
  const numeric = Number(value);
  if (Number.isFinite(numeric)) {
    const row = await db.prepare(
      'SELECT id, username FROM users WHERE id = ? OR user_no = ? LIMIT 1'
    ).bind(numeric, numeric).first();
    if (row) return row;
  }
  return await db.prepare(
    'SELECT id, username FROM users WHERE lower(username) = lower(?) LIMIT 1'
  ).bind(value).first();
}

async function areFriends(db, firstUserId, secondUserId) {
  const row = await db.prepare(
    "SELECT id FROM friend_requests WHERE status = 'accepted' " +
    'AND ((sender_user_id = ? AND recipient_user_id = ?) ' +
    'OR (sender_user_id = ? AND recipient_user_id = ?)) LIMIT 1'
  ).bind(firstUserId, secondUserId, secondUserId, firstUserId).first();
  return Boolean(row);
}

function projectCall(row) {
  return {
    callId: String(row.call_id),
    creatorUserId: row.creator_user_id,
    peerUserId: row.peer_user_id,
    creatorDeviceId: row.creator_device_id || null,
    peerDeviceId: row.peer_device_id || null,
    state: String(row.state),
    generation: Number(row.generation),
    eventSeq: Number(row.event_seq),
    terminalState: row.terminal_state || null,
    createdAt: String(row.created_at),
    updatedAt: String(row.updated_at),
  };
}

function projectEvent(row) {
  let payload;
  try {
    payload = JSON.parse(String(row.payload_json || '{}'));
  } catch {
    throw new Error('stored call event payload is invalid JSON');
  }
  return {
    callId: String(row.call_id),
    seq: Number(row.seq),
    generation: Number(row.generation),
    userId: row.user_id,
    deviceId: String(row.device_id),
    clientEventId: String(row.client_event_id),
    kind: String(row.kind),
    payload,
    createdAt: String(row.created_at),
  };
}

async function loadParticipantCall(db, callId, userId) {
  return await db.prepare(
    'SELECT call_id, creator_user_id, peer_user_id, creator_device_id, peer_device_id, ' +
    'state, generation, event_seq, terminal_state, last_event_token, created_at, updated_at ' +
    'FROM human_calls WHERE call_id = ? AND (creator_user_id = ? OR peer_user_id = ?) LIMIT 1'
  ).bind(callId, userId, userId).first();
}

function roleFor(row, userId) {
  if (Number(row.creator_user_id) === Number(userId)) {
    return { role: 'creator', claimColumn: 'creator_device_id', claimedDeviceId: row.creator_device_id || null };
  }
  if (Number(row.peer_user_id) === Number(userId)) {
    return { role: 'peer', claimColumn: 'peer_device_id', claimedDeviceId: row.peer_device_id || null };
  }
  throw new Error('call does not belong to authenticated account');
}

export function projectHumanCallTransition(state, generation, action, terminalReason = null) {
  const currentState = String(state || '');
  const currentGeneration = nonNegativeInteger(generation, 'call generation');
  const normalizedAction = boundedText(action, 'call transition action', 32);
  if (!CALL_STATES.has(currentState)) throw new Error('call state is invalid');
  if (TERMINAL_CALL_STATES.has(currentState)) throw new Error('terminal call session cannot transition');

  if ((currentState === 'invited' || currentState === 'ringing') && normalizedAction === 'accept') {
    return { state: 'negotiating', generation: currentGeneration, terminalState: null, terminalReason: null };
  }
  if ((currentState === 'negotiating' || currentState === 'reconnecting') && normalizedAction === 'connected') {
    return { state: 'connected', generation: currentGeneration, terminalState: null, terminalReason: null };
  }
  if ((currentState === 'invited' || currentState === 'ringing') && normalizedAction === 'decline') {
    return {
      state: 'ended',
      generation: currentGeneration,
      terminalState: 'ended',
      terminalReason: normalizeTerminalReason(terminalReason, 'declined'),
    };
  }
  if (
    ['invited', 'ringing', 'negotiating', 'connected', 'reconnecting'].includes(currentState)
    && normalizedAction === 'hangup'
  ) {
    return {
      state: 'ended',
      generation: currentGeneration,
      terminalState: 'ended',
      terminalReason: normalizeTerminalReason(terminalReason, 'hangup'),
    };
  }
  if (
    ['invited', 'ringing', 'negotiating', 'connected', 'reconnecting'].includes(currentState)
    && normalizedAction === 'fail'
  ) {
    return {
      state: 'failed',
      generation: currentGeneration,
      terminalState: 'failed',
      terminalReason: normalizeTerminalReason(terminalReason, 'failed'),
    };
  }
  if (
    ['negotiating', 'connected', 'reconnecting'].includes(currentState)
    && normalizedAction === 'reconnect'
  ) {
    return {
      state: 'reconnecting',
      generation: currentGeneration + 1,
      terminalState: null,
      terminalReason: null,
    };
  }
  if (currentState === 'reconnecting' && normalizedAction === 'resume') {
    return { state: 'negotiating', generation: currentGeneration, terminalState: null, terminalReason: null };
  }
  if (currentState === 'invited' && normalizedAction === 'ring') {
    return { state: 'ringing', generation: currentGeneration, terminalState: null, terminalReason: null };
  }
  throw new Error('invalid call transition: ' + currentState + ' -> ' + normalizedAction);
}

function normalizeIceUrl(value) {
  const url = String(value ?? '').trim();
  if (!url || url.length > 1024 || !/^(stun|turn|turns):[^\s]+$/i.test(url)) {
    throw new Error('Fabushi call ICE server URL is invalid');
  }
  return url;
}

export function normalizeHumanCallIceServers(raw) {
  let parsed = raw;
  if (typeof raw === 'string') {
    const text = raw.trim();
    if (!text) throw new Error('Fabushi call ICE server configuration is missing');
    try {
      parsed = JSON.parse(text);
    } catch {
      throw new Error('FABUSHI_CALL_ICE_SERVERS_JSON must be valid JSON');
    }
  }
  if (!Array.isArray(parsed) || parsed.length < 1 || parsed.length > MAX_ICE_SERVERS) {
    throw new Error('Fabushi call ICE server configuration must contain 1-' + MAX_ICE_SERVERS + ' servers');
  }
  return parsed.map((entry) => {
    if (!entry || typeof entry !== 'object' || Array.isArray(entry)) {
      throw new Error('Fabushi call ICE server entry is invalid');
    }
    const rawUrls = Array.isArray(entry.urls) ? entry.urls : [entry.urls];
    if (!rawUrls.length || rawUrls.length > MAX_ICE_URLS_PER_SERVER) {
      throw new Error('Fabushi call ICE server URL list is invalid');
    }
    const normalized = { urls: rawUrls.map(normalizeIceUrl) };
    if (entry.username != null) {
      const username = String(entry.username);
      if (username.length > MAX_ICE_VALUE_CHARS) throw new Error('Fabushi call ICE username is too long');
      normalized.username = username;
    }
    if (entry.credential != null) {
      const credential = String(entry.credential);
      if (credential.length > MAX_ICE_VALUE_CHARS) throw new Error('Fabushi call ICE credential is too long');
      normalized.credential = credential;
    }
    return normalized;
  });
}

function validateEventAgainstCall(row, body, deviceId) {
  const kind = boundedText(body.kind, 'call event kind', 32);
  if (!EVENT_KINDS.has(kind)) throw new Error('unsupported call event kind: ' + kind);
  const generation = nonNegativeInteger(body.generation, 'call event generation');
  const clientEventId = boundedText(body.clientEventId, 'call event id', MAX_CLIENT_EVENT_ID_CHARS);
  const { payload, text: payloadJson } = serializedPayload(body.payload);
  const role = roleFor(row, body.authUserId);
  if (role.claimedDeviceId && role.claimedDeviceId !== deviceId) {
    throw new Error('call transport is owned by another device');
  }

  let nextState = String(row.state);
  let nextGeneration = Number(row.generation);
  let nextTerminalState = row.terminal_state || null;

  if (kind === 'transition') {
    const action = payload.action;
    const requestedState = boundedText(payload.state, 'call transition state', 32);
    const projected = projectHumanCallTransition(
      row.state,
      row.generation,
      action,
      payload.terminalReason,
    );
    if (requestedState !== projected.state || generation !== projected.generation) {
      throw new Error('call transition disagrees with canonical state machine');
    }
    nextState = projected.state;
    nextGeneration = projected.generation;
    nextTerminalState = projected.terminalState;
  } else {
    if (TERMINAL_CALL_STATES.has(String(row.state))) {
      throw new Error('terminal call session cannot accept ' + kind + ' events');
    }
    if (generation !== Number(row.generation)) {
      throw new Error('stale call generation: expected ' + generation + ', current ' + row.generation);
    }
    if (kind === 'signal') {
      const senderDeviceId = normalizeHumanCallDeviceId(payload.senderDeviceId);
      if (senderDeviceId !== deviceId) throw new Error('call signal senderDeviceId must match authenticated device');
      boundedText(payload.signalKind, 'call signal kind', MAX_SIGNAL_KIND_CHARS);
      ensureObject(payload.signal, 'call signal payload');
    } else if (kind === 'media') {
      ensureObject(payload.mediaCapabilities, 'call media capabilities');
      ensureObject(payload.deviceSelection, 'call media device selection');
    }
  }

  return {
    kind,
    generation,
    clientEventId,
    payload,
    payloadJson,
    role,
    nextState,
    nextGeneration,
    nextTerminalState,
  };
}

function existingEventMatches(row, expected, deviceId) {
  if (!row) return false;
  let payload;
  try {
    payload = JSON.parse(String(row.payload_json || '{}'));
  } catch {
    return false;
  }
  return String(row.device_id) === deviceId
    && String(row.kind) === expected.kind
    && Number(row.generation) === expected.generation
    && stableJson(payload) === stableJson(expected.payload);
}

async function loadEventByClientId(db, callId, userId, clientEventId) {
  return await db.prepare(
    'SELECT call_id, seq, generation, user_id, device_id, client_event_id, kind, payload_json, created_at ' +
    'FROM human_call_events WHERE call_id = ? AND user_id = ? AND client_event_id = ? LIMIT 1'
  ).bind(callId, userId, clientEventId).first();
}

export async function handleGetHumanCallIceServers(request, env, db) {
  const identity = await requireCallIdentity(request, env, db);
  if (identity.response) return identity.response;
  let iceServers;
  try {
    iceServers = normalizeHumanCallIceServers(env.FABUSHI_CALL_ICE_SERVERS_JSON);
  } catch (error) {
    return errorResponse(error.message, 503);
  }
  const configuredTtl = Number(env.FABUSHI_CALL_ICE_TTL_SECONDS ?? 3600);
  const ttlSeconds = Number.isSafeInteger(configuredTtl) && configuredTtl >= 300 && configuredTtl <= 86400
    ? configuredTtl
    : 3600;
  return jsonResponse({ success: true, iceServers, ttlSeconds });
}

export async function handleListHumanCalls(request, env, db) {
  const identity = await requireCallIdentity(request, env, db);
  if (identity.response) return identity.response;
  const url = new URL(request.url);
  const limit = clampLimit(url.searchParams.get('limit'), 50, 200);
  const rows = await db.prepare(
    'SELECT call_id, creator_user_id, peer_user_id, creator_device_id, peer_device_id, ' +
    'state, generation, event_seq, terminal_state, created_at, updated_at ' +
    'FROM human_calls WHERE creator_user_id = ? OR peer_user_id = ? ' +
    'ORDER BY updated_at DESC, call_id DESC LIMIT ?'
  ).bind(identity.auth.userId, identity.auth.userId, limit).all();
  return jsonResponse({
    success: true,
    calls: (rows.results || []).map(projectCall),
  });
}

export async function handleCreateHumanCall(request, env, db) {
  const identity = await requireCallIdentity(request, env, db);
  if (identity.response) return identity.response;

  let body;
  try {
    body = await readJsonBody(request);
  } catch (error) {
    return errorResponse(error.message, 400);
  }

  let callId;
  let targetIdentifier;
  try {
    callId = boundedText(body.callId, 'call id', MAX_CALL_ID_CHARS);
    targetIdentifier = boundedText(body.targetUserId, 'target user id', 200);
  } catch (error) {
    return errorResponse(error.message, 400);
  }

  const target = await findUser(db, targetIdentifier);
  if (!target) return errorResponse('未找到联系人', 404);
  if (Number(target.id) === Number(identity.auth.userId)) {
    return errorResponse('不能呼叫自己', 400);
  }
  if (!(await areFriends(db, identity.auth.userId, target.id))) {
    return errorResponse('只能呼叫已添加的好友', 403);
  }

  const now = new Date().toISOString();
  const insert = await db.prepare(
    "INSERT INTO human_calls (" +
    'call_id, creator_user_id, peer_user_id, creator_device_id, peer_device_id, state, generation, event_seq, terminal_state, last_event_token, created_at, updated_at' +
    ") VALUES (?, ?, ?, ?, NULL, 'invited', 0, 0, NULL, NULL, ?, ?) " +
    'ON CONFLICT(call_id) DO NOTHING'
  ).bind(
    callId,
    identity.auth.userId,
    target.id,
    identity.deviceId,
    now,
    now,
  ).run();

  const row = await loadParticipantCall(db, callId, identity.auth.userId);
  if (!row) return errorResponse('通话创建结果无法确认', 500);

  const sameCall = Number(row.creator_user_id) === Number(identity.auth.userId)
    && Number(row.peer_user_id) === Number(target.id)
    && String(row.creator_device_id || '') === identity.deviceId;
  if (!sameCall) {
    return errorResponse('call id 已被另一通话或设备占用', 409);
  }

  const created = Number(insert.meta?.changes || 0) > 0;
  return jsonResponse({ success: true, call: projectCall(row) }, created ? 201 : 200);
}

export async function handleGetHumanCall(request, env, db, rawCallId) {
  const identity = await requireCallIdentity(request, env, db);
  if (identity.response) return identity.response;
  let callId;
  try {
    callId = decodeCallId(rawCallId);
  } catch (error) {
    return errorResponse(error.message, 400);
  }
  const row = await loadParticipantCall(db, callId, identity.auth.userId);
  if (!row) return errorResponse('通话不存在', 404);

  const url = new URL(request.url);
  let afterSeq;
  try {
    afterSeq = nonNegativeInteger(url.searchParams.get('afterSeq') || 0, 'afterSeq');
  } catch (error) {
    return errorResponse(error.message, 400);
  }
  const limit = clampLimit(url.searchParams.get('limit'), 100, 200);
  const eventRows = await db.prepare(
    'SELECT call_id, seq, generation, user_id, device_id, client_event_id, kind, payload_json, created_at ' +
    'FROM human_call_events WHERE call_id = ? AND seq > ? ORDER BY seq ASC LIMIT ?'
  ).bind(callId, afterSeq, limit).all();
  const events = (eventRows.results || []).map(projectEvent);
  const nextAfterSeq = events.length ? events[events.length - 1].seq : Math.min(afterSeq, Number(row.event_seq));
  return jsonResponse({
    success: true,
    call: projectCall(row),
    events,
    nextAfterSeq,
  });
}

export async function handleAppendHumanCallEvent(request, env, db, rawCallId) {
  const identity = await requireCallIdentity(request, env, db);
  if (identity.response) return identity.response;

  let callId;
  let body;
  try {
    callId = decodeCallId(rawCallId);
    body = await readJsonBody(request);
  } catch (error) {
    return errorResponse(error.message, 400);
  }

  let clientEventId;
  try {
    clientEventId = boundedText(body.clientEventId, 'call event id', MAX_CLIENT_EVENT_ID_CHARS);
  } catch (error) {
    return errorResponse(error.message, 400);
  }

  for (let attempt = 0; attempt < 4; attempt += 1) {
    const row = await loadParticipantCall(db, callId, identity.auth.userId);
    if (!row) return errorResponse('通话不存在', 404);

    const existing = await loadEventByClientId(db, callId, identity.auth.userId, clientEventId);
    let expected;
    try {
      expected = validateEventAgainstCall(
        row,
        { ...body, authUserId: identity.auth.userId },
        identity.deviceId,
      );
    } catch (error) {
      if (existing) {
        const replayExpected = {
          kind: String(body.kind || ''),
          generation: Number(body.generation),
          payload: body.payload,
        };
        if (existingEventMatches(existing, replayExpected, identity.deviceId)) {
          return jsonResponse({ success: true, call: projectCall(row), event: projectEvent(existing) });
        }
      }
      const status = /another device|stale call generation|canonical state machine|terminal call/.test(error.message)
        ? 409
        : 400;
      return errorResponse(error.message, status);
    }

    if (existing) {
      if (!existingEventMatches(existing, expected, identity.deviceId)) {
        return errorResponse('call event id 已用于不同事件内容', 409);
      }
      return jsonResponse({ success: true, call: projectCall(row), event: projectEvent(existing) });
    }

    const expectedEventSeq = Number(row.event_seq);
    const nextEventSeq = expectedEventSeq + 1;
    const now = new Date().toISOString();
    const claimColumn = expected.role.claimColumn;
    const updateSql =
      'UPDATE human_calls SET ' + claimColumn + ' = COALESCE(' + claimColumn + ', ?), ' +
      'state = ?, generation = ?, event_seq = event_seq + 1, terminal_state = ?, last_event_token = ?, updated_at = ? ' +
      'WHERE call_id = ? AND event_seq = ? AND generation = ? AND state = ? ' +
      'AND (' + claimColumn + ' IS NULL OR ' + claimColumn + ' = ?)';
    const insertSql =
      'INSERT INTO human_call_events ' +
      '(call_id, seq, generation, user_id, device_id, client_event_id, kind, payload_json, created_at) ' +
      'SELECT call_id, event_seq, ?, ?, ?, ?, ?, ?, ? FROM human_calls ' +
      'WHERE call_id = ? AND event_seq = ? AND generation = ? AND state = ? AND last_event_token = ?';

    try {
      await db.batch([
        db.prepare(updateSql).bind(
          identity.deviceId,
          expected.nextState,
          expected.nextGeneration,
          expected.nextTerminalState,
          expected.clientEventId,
          now,
          callId,
          expectedEventSeq,
          Number(row.generation),
          String(row.state),
          identity.deviceId,
        ),
        db.prepare(insertSql).bind(
          expected.generation,
          identity.auth.userId,
          identity.deviceId,
          expected.clientEventId,
          expected.kind,
          expected.payloadJson,
          now,
          callId,
          nextEventSeq,
          expected.nextGeneration,
          expected.nextState,
          expected.clientEventId,
        ),
      ]);
    } catch (error) {
      const replay = await loadEventByClientId(db, callId, identity.auth.userId, expected.clientEventId);
      if (replay && existingEventMatches(replay, expected, identity.deviceId)) {
        const latest = await loadParticipantCall(db, callId, identity.auth.userId);
        return jsonResponse({
          success: true,
          call: projectCall(latest || row),
          event: projectEvent(replay),
        });
      }
      if (attempt < 3) continue;
      console.error('human call event batch failed:', error?.message || error);
      return errorResponse('通话事件保存失败', 409);
    }

    const accepted = await loadEventByClientId(db, callId, identity.auth.userId, expected.clientEventId);
    if (!accepted) {
      if (attempt < 3) continue;
      return errorResponse('通话状态已变化，请同步后重试', 409);
    }
    if (!existingEventMatches(accepted, expected, identity.deviceId)) {
      return errorResponse('call event id 已用于不同事件内容', 409);
    }
    const latest = await loadParticipantCall(db, callId, identity.auth.userId);
    if (!latest) return errorResponse('通话在事件保存后消失', 500);
    return jsonResponse({ success: true, call: projectCall(latest), event: projectEvent(accepted) }, 201);
  }

  return errorResponse('通话状态竞争超过重试上限', 409);
}
