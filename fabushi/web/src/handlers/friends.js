import { jsonResponse } from '../utils/response.js';
import { requireAuthIdentity } from '../utils/auth-identity.js';

const MAX_MESSAGE_LENGTH = 4000;
const MAX_MESSAGE_ATTACHMENTS = 6;
const MAX_MESSAGE_RESOURCE_BYTES = 32 * 1024 * 1024;
const MAX_MESSAGE_RESOURCE_NAME_CHARS = 255;
const MAX_REACTION_BYTES = 32;
const DIRECT_MESSAGE_SELECT_FIELDS = 'id, sender_user_id, sender_username, recipient_user_id, recipient_username, body, client_request_id, created_at, read_at, reply_to_message_id, attachments_json, silent, scheduled_at_ms, delivery_state, delivered_at, destination_json, expires_at_ms, expired_at_ms';

export function normalizeDirectMessageDeliveryOptions(body, nowMs = Date.now()) {
  const silent = body?.silent ?? false;
  if (typeof silent !== 'boolean') {
    throw new Error('silent 必须是布尔值');
  }

  let scheduledAtMs = null;
  if (body?.scheduledAtMs !== undefined && body?.scheduledAtMs !== null) {
    if (typeof body.scheduledAtMs !== 'number'
      || !Number.isSafeInteger(body.scheduledAtMs)
      || body.scheduledAtMs <= 0) {
      throw new Error('scheduledAtMs 必须是正的安全整数毫秒时间戳');
    }
    scheduledAtMs = body.scheduledAtMs;
  }

  const scheduled = scheduledAtMs !== null && scheduledAtMs > nowMs;
  return {
    silent,
    scheduledAtMs,
    deliveryState: scheduled ? 'scheduled' : 'delivered',
    deliveredAt: scheduled ? null : new Date(nowMs).toISOString(),
  };
}

function canonicalDestinationId(value, label) {
  if (typeof value !== 'string') throw new Error(label + ' 必须是字符串');
  const normalized = value.trim();
  if (!normalized || normalized.length > 200) {
    throw new Error(label + ' 必须是 1 到 200 个字符');
  }
  return normalized;
}

export async function canonicalHumanDirectConversationId(firstUserId, secondUserId) {
  const participantIds = [String(firstUserId), String(secondUserId)].sort();
  const encoder = new TextEncoder();
  const encoded = participantIds.map((value) => encoder.encode(value));
  const totalLength = encoded.reduce((sum, bytes) => sum + 8 + bytes.byteLength, 0);
  const payload = new Uint8Array(totalLength);
  const view = new DataView(payload.buffer);
  let offset = 0;
  for (const bytes of encoded) {
    view.setBigUint64(offset, BigInt(bytes.byteLength), false);
    offset += 8;
    payload.set(bytes, offset);
    offset += bytes.byteLength;
  }
  const digest = new Uint8Array(await crypto.subtle.digest('SHA-256', payload));
  const hex = Array.from(digest, (byte) => byte.toString(16).padStart(2, '0')).join('');
  return `human-direct-${hex}`;
}

export async function authorizeDirectMessageDestination(
  destination,
  authenticatedUserId,
  targetUserId,
) {
  if (destination?.child?.kind !== 'savedSublist') return destination;

  const expectedConversationId = await canonicalHumanDirectConversationId(
    authenticatedUserId,
    targetUserId,
  );
  const expectedParticipantId = String(targetUserId);
  if (
    destination.conversationId !== expectedConversationId
    || destination.child.participantId !== expectedParticipantId
  ) {
    throw new Error('SavedSublist destination is not authorized for this Human conversation');
  }
  return destination;
}

export function normalizeDirectMessageDestination(value) {
  if (value === undefined || value === null) return null;
  if (typeof value !== 'object' || Array.isArray(value)) {
    throw new Error('destination 必须是对象');
  }
  const conversationId = canonicalDestinationId(value.conversationId, 'destination.conversationId');
  const rawChild = value.child;
  if (rawChild === undefined || rawChild === null) {
    return { conversationId, child: null };
  }
  if (typeof rawChild !== 'object' || Array.isArray(rawChild)) {
    throw new Error('destination.child 必须是对象或 null');
  }
  switch (rawChild.kind) {
    case 'topic':
      return {
        conversationId,
        child: {
          kind: 'topic',
          rootMessageId: canonicalDestinationId(
            rawChild.rootMessageId,
            'destination.child.rootMessageId',
          ),
        },
      };
    case 'savedSublist':
      return {
        conversationId,
        child: {
          kind: 'savedSublist',
          participantId: canonicalDestinationId(
            rawChild.participantId,
            'destination.child.participantId',
          ),
        },
      };
    case 'conversation':
      return {
        conversationId,
        child: {
          kind: 'conversation',
          conversationId: canonicalDestinationId(
            rawChild.conversationId,
            'destination.child.conversationId',
          ),
        },
      };
    default:
      throw new Error('destination.child.kind 不受支持');
  }
}

function parseStoredDestination(value) {
  if (value == null || value === '') return null;
  let parsed;
  try {
    parsed = JSON.parse(value);
  } catch {
    throw new Error('direct message destination metadata is invalid JSON');
  }
  return normalizeDirectMessageDestination(parsed);
}

function normalizeRetentionSeconds(value) {
  if (value === undefined || value === null) return null;
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value <= 0 || value > 0xffffffff) {
    throw new Error('retentionSeconds 必须为空或正的 32 位整数秒数');
  }
  return value;
}

function retentionPair(firstUserId, secondUserId) {
  const first = Number(firstUserId);
  const second = Number(secondUserId);
  return first < second ? [first, second] : [second, first];
}

async function readDirectMessageRetention(db, firstUserId, secondUserId) {
  const conversationId = await canonicalHumanDirectConversationId(firstUserId, secondUserId);
  const row = await db.prepare(
    'SELECT retention_seconds, retention_revision FROM direct_message_retention_policies WHERE conversation_id = ? LIMIT 1'
  ).bind(conversationId).first();
  return {
    conversationId,
    retentionSeconds: row?.retention_seconds == null ? null : Number(row.retention_seconds),
    revision: row == null ? 0 : Number(row.retention_revision),
  };
}

function conversationChildDraftIdentity(destination) {
  const child = destination?.child;
  if (child?.kind === 'topic') return { childKind: 'topic', childId: child.rootMessageId };
  if (child?.kind === 'savedSublist') return { childKind: 'savedSublist', childId: child.participantId };
  if (child?.kind === 'conversation') return { childKind: 'conversation', childId: child.conversationId };
  throw new Error('conversation child draft requires a typed child destination');
}

function projectConversationChildDraft(destination, row) {
  return {
    destination,
    text: row?.draft_text == null ? '' : String(row.draft_text),
    replyToMessageId: row?.reply_to_message_id == null ? null : String(row.reply_to_message_id),
    revision: row == null ? 0 : Number(row.draft_revision),
    updatedAt: row?.updated_at == null ? null : String(row.updated_at),
  };
}

async function readConversationChildDraft(db, ownerUserId, destination) {
  const { childKind, childId } = conversationChildDraftIdentity(destination);
  const row = await db.prepare(
    'SELECT draft_text, reply_to_message_id, draft_revision, updated_at FROM conversation_child_drafts WHERE owner_user_id = ? AND conversation_id = ? AND child_kind = ? AND child_id = ? LIMIT 1'
  ).bind(ownerUserId, destination.conversationId, childKind, childId).first();
  return projectConversationChildDraft(destination, row);
}

async function resolveSavedSublistDraftDestination(db, ownerUserId, targetIdentifier, rawDestination = null) {
  const target = await findUser(db, targetIdentifier);
  if (!target) throw new Error('未找到联系人');
  if (!(await areFriends(db, ownerUserId, target.id))) {
    throw new Error('只能同步已添加好友的 SavedSublist 草稿');
  }
  const canonicalDestination = {
    conversationId: await canonicalHumanDirectConversationId(ownerUserId, target.id),
    child: { kind: 'savedSublist', participantId: String(target.id) },
  };
  if (rawDestination == null) return { target, destination: canonicalDestination };
  const destination = normalizeDirectMessageDestination(rawDestination);
  if (destination?.child?.kind !== 'savedSublist') {
    throw new Error('SavedSublist 草稿必须使用 savedSublist child destination');
  }
  await authorizeDirectMessageDestination(destination, ownerUserId, target.id);
  return { target, destination };
}

async function validateConversationChildDraftReply(db, ownerUserId, targetUserId, destination, rawMessageId) {
  if (rawMessageId === undefined || rawMessageId === null || rawMessageId === '') return null;
  const rawReplyId = String(rawMessageId).trim();
  const messageId = positiveMessageId(
    rawReplyId.startsWith('human-server-message:')
      ? rawReplyId.slice('human-server-message:'.length)
      : rawReplyId,
  );
  if (messageId == null) throw new Error('草稿回复目标消息编号无效');
  const row = await db.prepare(
    "SELECT id, destination_json FROM direct_messages WHERE id = ? AND expired_at_ms IS NULL AND ((sender_user_id = ? AND recipient_user_id = ?) OR (sender_user_id = ? AND recipient_user_id = ?)) AND (sender_user_id = ? OR delivery_state = 'delivered') LIMIT 1"
  ).bind(messageId, ownerUserId, targetUserId, targetUserId, ownerUserId, ownerUserId).first();
  if (!row) throw new Error('草稿回复目标不属于当前会话');
  const storedDestination = parseStoredDestination(row.destination_json);
  if (JSON.stringify(storedDestination) !== JSON.stringify(destination)) {
    throw new Error('草稿回复目标不属于当前 ConversationChild');
  }
  return messageId;
}

export async function settleExpiredDirectMessages(db, nowMs = Date.now()) {
  if (!Number.isSafeInteger(nowMs) || nowMs <= 0) {
    throw new Error('direct message expiry settlement requires a positive safe integer timestamp');
  }
  const result = await db.prepare(
    "UPDATE direct_messages SET expired_at_ms = ?, body = '', attachments_json = '[]', reply_to_message_id = NULL WHERE expired_at_ms IS NULL AND expires_at_ms IS NOT NULL AND expires_at_ms <= ?"
  ).bind(nowMs, nowMs).run();
  return Number(result?.meta?.changes || 0);
}

export async function activateDueDirectMessages(db, nowMs = Date.now()) {
  if (!Number.isSafeInteger(nowMs) || nowMs <= 0) {
    throw new Error('direct message scheduler requires a positive safe integer timestamp');
  }
  const deliveredAt = new Date(nowMs).toISOString();
  const result = await db.prepare(
    "UPDATE direct_messages SET delivery_state = 'delivered', delivered_at = ? WHERE delivery_state = 'scheduled' AND scheduled_at_ms IS NOT NULL AND scheduled_at_ms <= ?"
  ).bind(deliveredAt, nowMs).run();
  return Number(result?.meta?.changes || 0);
}

function positiveMessageId(value) {
  const text = String(value ?? '').trim();
  if (!/^\d+$/.test(text)) return null;
  const parsed = Number(text);
  return Number.isSafeInteger(parsed) && parsed > 0 ? parsed : null;
}

function normalizedResourceName(value) {
  const cleaned = String(value || 'attachment')
    .replace(/[\u0000-\u001f\u007f]/g, '')
    .trim();
  return Array.from(cleaned || 'attachment').slice(0, MAX_MESSAGE_RESOURCE_NAME_CHARS).join('');
}

function normalizedContentType(value) {
  const type = String(value || 'application/octet-stream').trim().toLowerCase();
  if (!type || type.length > 200 || /[\r\n]/.test(type)) return 'application/octet-stream';
  return type;
}

function parseStoredAttachments(value) {
  let parsed;
  try {
    parsed = JSON.parse(value || '[]');
  } catch {
    throw new Error('direct message attachment metadata is invalid JSON');
  }
  if (!Array.isArray(parsed)) throw new Error('direct message attachment metadata is invalid');
  return parsed;
}

async function loadOwnedMessageAttachments(db, ownerUserId, requested) {
  if (!Array.isArray(requested)) {
    if (requested == null) return [];
    throw new Error('消息附件格式无效');
  }
  if (requested.length > MAX_MESSAGE_ATTACHMENTS) {
    throw new Error('消息附件数量超过限制');
  }

  const seen = new Set();
  const attachments = [];
  for (const candidate of requested) {
    const resourceId = String(candidate?.resourceId || '').trim();
    if (!resourceId || resourceId.length > 128 || seen.has(resourceId)) {
      throw new Error('消息附件资源编号无效');
    }
    seen.add(resourceId);
    const row = await db.prepare(
      'SELECT id, name, content_type, size, created_at FROM direct_message_resources WHERE id = ? AND owner_user_id = ? LIMIT 1'
    ).bind(resourceId, ownerUserId).first();
    if (!row) throw new Error('消息附件资源不存在或不属于当前账号');
    attachments.push({
      resourceId: String(row.id),
      name: String(row.name),
      contentType: String(row.content_type),
      size: Number(row.size),
      createdAt: String(row.created_at),
    });
  }
  return attachments;
}

async function validateReplyTarget(db, messageId, senderUserId, recipientUserId) {
  if (messageId == null) return null;
  const row = await db.prepare(
    'SELECT id FROM direct_messages WHERE id = ? AND expired_at_ms IS NULL AND ((sender_user_id = ? AND recipient_user_id = ?) OR (sender_user_id = ? AND recipient_user_id = ?)) AND (sender_user_id = ? OR delivery_state = \'delivered\') LIMIT 1'
  ).bind(messageId, senderUserId, recipientUserId, recipientUserId, senderUserId, senderUserId).first();
  if (!row) throw new Error('回复目标不属于当前会话');
  return Number(row.id);
}

async function loadReactionMap(db, messageIds, currentUserId) {
  const ids = messageIds
    .map((value) => positiveMessageId(value))
    .filter((value) => value != null);
  const map = new Map();
  if (!ids.length) return map;

  const placeholders = ids.map(() => '?').join(',');
  const rows = await db.prepare(
    'SELECT message_id, user_id, emoji FROM direct_message_reactions WHERE message_id IN (' + placeholders + ') ORDER BY message_id ASC, emoji ASC, user_id ASC'
  ).bind(...ids).all();

  for (const row of rows.results || []) {
    const key = String(row.message_id);
    let byEmoji = map.get(key);
    if (!byEmoji) {
      byEmoji = new Map();
      map.set(key, byEmoji);
    }
    const emoji = String(row.emoji);
    const aggregate = byEmoji.get(emoji) || { emoji, count: 0, reactedByMe: false };
    aggregate.count += 1;
    if (Number(row.user_id) === Number(currentUserId)) aggregate.reactedByMe = true;
    byEmoji.set(emoji, aggregate);
  }

  const projected = new Map();
  for (const [messageId, byEmoji] of map) {
    projected.set(messageId, Array.from(byEmoji.values()));
  }
  return projected;
}

function projectDirectMessage(row, currentUserId, reactions = []) {
  return {
    id: row.id,
    senderUserId: row.sender_user_id,
    senderUsername: row.sender_username,
    recipientUserId: row.recipient_user_id,
    recipientUsername: row.recipient_username,
    text: row.body,
    clientRequestId: row.client_request_id,
    createdAt: row.created_at,
    readAt: row.read_at,
    silent: Boolean(Number(row.silent || 0)),
    scheduledAtMs: row.scheduled_at_ms == null ? null : Number(row.scheduled_at_ms),
    deliveryState: row.delivery_state || 'delivered',
    deliveredAt: row.delivered_at ?? null,
    isOutgoing: Number(row.sender_user_id) === Number(currentUserId),
    replyToMessageId: row.reply_to_message_id ?? null,
    attachments: parseStoredAttachments(row.attachments_json),
    reactions,
    destination: parseStoredDestination(row.destination_json),
    expiresAtMs: row.expires_at_ms == null ? null : Number(row.expires_at_ms),
    expiredAtMs: row.expired_at_ms == null ? null : Number(row.expired_at_ms),
    expired: row.expired_at_ms != null,
  };
}

async function requireStableAuth(request, env, db) {
  const auth = await requireAuthIdentity(request, env, db);
  if (auth.error) return auth;
  if (!Number.isFinite(auth.userId)) {
    return { error: '账号资料需要刷新后才能使用好友功能', status: 409 };
  }
  return auth;
}

function mapContact(row, status = 'friend') {
  return {
    id: row.id,
    userId: row.id,
    username: row.username,
    userNo: row.user_no ?? null,
    displayName: row.nickname || row.username,
    nickname: row.nickname || null,
    avatarUrl:
      row.avatar || row.alipay_avatar || row.wechat_headimgurl || null,
    status,
  };
}

function clampLimit(value, fallback = 50, maximum = 100) {
  const parsed = Number.parseInt(value || '', 10);
  if (!Number.isFinite(parsed)) return fallback;
  return Math.min(Math.max(parsed, 1), maximum);
}

async function findUser(db, identifier) {
  const value = String(identifier ?? '').trim();
  if (!value) return null;
  const numeric = Number(value);
  if (Number.isFinite(numeric)) {
    const byId = await db.prepare(`
      SELECT id, username, user_no, nickname, avatar, alipay_avatar, wechat_headimgurl
      FROM users
      WHERE id = ? OR user_no = ?
      LIMIT 1
    `).bind(numeric, numeric).first();
    if (byId) return byId;
  }
  return await db.prepare(`
    SELECT id, username, user_no, nickname, avatar, alipay_avatar, wechat_headimgurl
    FROM users
    WHERE lower(username) = lower(?)
    LIMIT 1
  `).bind(value).first();
}

async function areFriends(db, firstUserId, secondUserId) {
  const row = await db.prepare(`
    SELECT id
    FROM friend_requests
    WHERE status = 'accepted'
      AND ((sender_user_id = ? AND recipient_user_id = ?)
        OR (sender_user_id = ? AND recipient_user_id = ?))
    LIMIT 1
  `).bind(firstUserId, secondUserId, secondUserId, firstUserId).first();
  return Boolean(row);
}

export async function handleSearchFriendUsers(request, env, db) {
  const auth = await requireStableAuth(request, env, db);
  if (auth.error) return jsonResponse({ success: false, error: auth.error }, auth.status);

  const url = new URL(request.url);
  const query = (url.searchParams.get('q') || '').trim();
  if (!query) return jsonResponse({ success: true, data: { users: [] } });
  const limit = clampLimit(url.searchParams.get('limit'), 20, 50);
  const like = `%${query.replaceAll('%', '\\%').replaceAll('_', '\\_')}%`;
  const numeric = Number(query);

  const rows = await db.prepare(`
    SELECT
      u.id, u.username, u.user_no, u.nickname, u.avatar,
      u.alipay_avatar, u.wechat_headimgurl,
      CASE
        WHEN EXISTS (
          SELECT 1 FROM friend_requests f
          WHERE f.status = 'accepted'
            AND ((f.sender_user_id = ? AND f.recipient_user_id = u.id)
              OR (f.sender_user_id = u.id AND f.recipient_user_id = ?))
        ) THEN 'friend'
        WHEN EXISTS (
          SELECT 1 FROM friend_requests f
          WHERE f.status = 'pending'
            AND f.sender_user_id = ? AND f.recipient_user_id = u.id
        ) THEN 'pending'
        ELSE 'available'
      END AS relationship_status
    FROM users u
    WHERE u.id != ?
      AND (
        lower(u.username) LIKE lower(?) ESCAPE '\\'
        OR lower(COALESCE(u.nickname, '')) LIKE lower(?) ESCAPE '\\'
        OR (? IS NOT NULL AND (u.id = ? OR u.user_no = ?))
      )
    ORDER BY
      CASE WHEN lower(u.username) = lower(?) THEN 0 ELSE 1 END,
      u.username ASC
    LIMIT ?
  `).bind(
    auth.userId, auth.userId, auth.userId, auth.userId,
    like, like,
    Number.isFinite(numeric) ? numeric : null,
    Number.isFinite(numeric) ? numeric : null,
    Number.isFinite(numeric) ? numeric : null,
    query, limit,
  ).all();

  return jsonResponse({
    success: true,
    data: {
      users: (rows.results || []).map((row) =>
        mapContact(row, row.relationship_status || 'available')),
    },
  });
}

export async function handleListFriends(request, env, db) {
  const auth = await requireStableAuth(request, env, db);
  if (auth.error) return jsonResponse({ success: false, error: auth.error }, auth.status);

  const rows = await db.prepare(`
    SELECT DISTINCT
      u.id, u.username, u.user_no, u.nickname, u.avatar,
      u.alipay_avatar, u.wechat_headimgurl,
      f.updated_at AS friendship_updated_at
    FROM friend_requests f
    JOIN users u ON u.id = CASE
      WHEN f.sender_user_id = ? THEN f.recipient_user_id
      ELSE f.sender_user_id
    END
    WHERE f.status = 'accepted'
      AND (f.sender_user_id = ? OR f.recipient_user_id = ?)
    ORDER BY f.updated_at DESC
  `).bind(auth.userId, auth.userId, auth.userId).all();

  return jsonResponse({
    success: true,
    data: { friends: (rows.results || []).map((row) => mapContact(row)) },
  });
}

export async function handleCreateFriendRequest(request, env, db) {
  const auth = await requireStableAuth(request, env, db);
  if (auth.error) return jsonResponse({ success: false, error: auth.error }, auth.status);

  const body = await request.json();
  const target = await findUser(
    db,
    body.targetUserId ?? body.targetUsername ?? body.username,
  );
  if (!target) return jsonResponse({ success: false, error: '未找到联系人' }, 404);
  if (target.id === auth.userId) {
    return jsonResponse({ success: false, error: '不能添加自己为好友' }, 400);
  }
  if (await areFriends(db, auth.userId, target.id)) {
    return jsonResponse({ success: true, alreadyFriends: true, user: mapContact(target) });
  }

  const reverse = await db.prepare(`
    SELECT id FROM friend_requests
    WHERE status = 'pending' AND sender_user_id = ? AND recipient_user_id = ?
    LIMIT 1
  `).bind(target.id, auth.userId).first();
  if (reverse) {
    return jsonResponse({
      success: false,
      error: '对方已经向你发送好友申请，请先接受该申请',
      incomingRequestId: reverse.id,
    }, 409);
  }

  const message = String(body.message || '').trim().slice(0, 300);
  const now = new Date().toISOString();
  await db.prepare(`
    INSERT INTO friend_requests (
      sender_user_id, sender_username, recipient_user_id,
      recipient_username, message, status, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, 'pending', ?, ?)
    ON CONFLICT(sender_user_id, recipient_user_id) WHERE status = 'pending'
    DO UPDATE SET message = excluded.message, updated_at = excluded.updated_at
  `).bind(
    auth.userId, auth.username, target.id, target.username, message, now, now,
  ).run();

  return jsonResponse({ success: true, status: 'pending', user: mapContact(target, 'pending') }, 201);
}

export async function handleListIncomingFriendRequests(request, env, db) {
  const auth = await requireStableAuth(request, env, db);
  if (auth.error) return jsonResponse({ success: false, error: auth.error }, auth.status);

  const rows = await db.prepare(`
    SELECT
      f.id AS request_id, f.message, f.created_at,
      u.id, u.username, u.user_no, u.nickname, u.avatar,
      u.alipay_avatar, u.wechat_headimgurl
    FROM friend_requests f
    JOIN users u ON u.id = f.sender_user_id
    WHERE f.recipient_user_id = ? AND f.status = 'pending'
    ORDER BY f.created_at DESC
  `).bind(auth.userId).all();

  return jsonResponse({
    success: true,
    data: {
      requests: (rows.results || []).map((row) => ({
        id: row.request_id,
        requestId: row.request_id,
        message: row.message || '',
        createdAt: row.created_at,
        fromUser: mapContact(row, 'pending'),
      })),
    },
  });
}

export async function handleAcceptFriendRequest(request, env, db, requestId) {
  const auth = await requireStableAuth(request, env, db);
  if (auth.error) return jsonResponse({ success: false, error: auth.error }, auth.status);
  const id = Number(requestId);
  if (!Number.isFinite(id)) {
    return jsonResponse({ success: false, error: '好友申请编号无效' }, 400);
  }

  const pending = await db.prepare(`
    SELECT id, sender_user_id
    FROM friend_requests
    WHERE id = ? AND recipient_user_id = ? AND status = 'pending'
    LIMIT 1
  `).bind(id, auth.userId).first();
  if (!pending) return jsonResponse({ success: false, error: '好友申请不存在或已处理' }, 404);

  const now = new Date().toISOString();
  await db.prepare(`
    UPDATE friend_requests SET status = 'accepted', updated_at = ?
    WHERE id = ? AND recipient_user_id = ? AND status = 'pending'
  `).bind(now, id, auth.userId).run();
  return jsonResponse({ success: true, requestId: id, status: 'accepted' });
}

export async function handleGetDirectMessageResource(request, env, db, rawResourceId) {
  const auth = await requireStableAuth(request, env, db);
  if (auth.error) return jsonResponse({ success: false, error: auth.error }, auth.status);
  if (!env.R2_BUCKET) return new Response('R2 storage unavailable', { status: 500 });

  const resourceId = String(rawResourceId || '').trim();
  if (!resourceId || resourceId.length > 128) {
    return jsonResponse({ success: false, error: '消息附件资源编号无效' }, 400);
  }

  const resource = await db.prepare(
    `SELECT r.id, r.owner_user_id, r.object_key, r.name, r.content_type, r.size
     FROM direct_message_resources r
     WHERE r.id = ?
       AND (
         r.owner_user_id = ?
         OR EXISTS (
           SELECT 1
           FROM direct_messages d, json_each(d.attachments_json) attachment
           WHERE d.expired_at_ms IS NULL
             AND (d.sender_user_id = ? OR (d.recipient_user_id = ? AND d.delivery_state = 'delivered'))
             AND json_extract(attachment.value, '$.resourceId') = r.id
         )
       )
     LIMIT 1`
  ).bind(resourceId, auth.userId, auth.userId, auth.userId).first();
  if (!resource) {
    return jsonResponse({ success: false, error: '消息附件不存在或无权访问' }, 404);
  }

  const object = await env.R2_BUCKET.get(String(resource.object_key));
  if (!object) {
    return jsonResponse({ success: false, error: '消息附件对象不存在' }, 404);
  }
  const headers = new Headers();
  headers.set('Content-Type', normalizedContentType(resource.content_type));
  headers.set('Content-Length', String(resource.size));
  headers.set('Cache-Control', 'private, no-store');
  headers.set('X-Content-Type-Options', 'nosniff');
  const safeName = normalizedResourceName(resource.name).replaceAll('"', '');
  headers.set('Content-Disposition', `inline; filename="${safeName}"`);
  return new Response(object.body, { status: 200, headers });
}

export async function handleUploadDirectMessageResource(request, env, db) {
  const auth = await requireStableAuth(request, env, db);
  if (auth.error) return jsonResponse({ success: false, error: auth.error }, auth.status);
  if (!env.R2_BUCKET) {
    return jsonResponse({ success: false, error: 'R2存储桶未绑定，无法保存消息附件' }, 500);
  }

  let formData;
  try {
    formData = await request.formData();
  } catch {
    return jsonResponse({ success: false, error: '消息附件上传格式无效' }, 400);
  }
  const file = formData.get('file');
  if (!file || typeof file.arrayBuffer !== 'function') {
    return jsonResponse({ success: false, error: '请选择要上传的消息附件' }, 400);
  }

  const announcedSize = Number(file.size);
  if (Number.isFinite(announcedSize) && announcedSize > MAX_MESSAGE_RESOURCE_BYTES) {
    return jsonResponse({ success: false, error: '消息附件不能超过32MB' }, 413);
  }
  const bytes = await file.arrayBuffer();
  if (!bytes.byteLength) {
    return jsonResponse({ success: false, error: '消息附件不能为空' }, 400);
  }
  if (bytes.byteLength > MAX_MESSAGE_RESOURCE_BYTES) {
    return jsonResponse({ success: false, error: '消息附件不能超过32MB' }, 413);
  }

  const resourceId = crypto.randomUUID();
  const name = normalizedResourceName(file.name);
  const contentType = normalizedContentType(file.type);
  const createdAt = new Date().toISOString();
  const objectKey = 'message-resources/' + auth.userId + '/' + resourceId;

  await env.R2_BUCKET.put(objectKey, bytes, {
    httpMetadata: { contentType },
    customMetadata: {
      ownerUserId: String(auth.userId),
      resourceId,
      name,
    },
  });

  try {
    await db.prepare(
      'INSERT INTO direct_message_resources (id, owner_user_id, object_key, name, content_type, size, created_at) VALUES (?, ?, ?, ?, ?, ?, ?)'
    ).bind(resourceId, auth.userId, objectKey, name, contentType, bytes.byteLength, createdAt).run();
  } catch (error) {
    try {
      await env.R2_BUCKET.delete(objectKey);
    } catch {
      // Preserve the database failure as the authoritative error.
    }
    throw error;
  }

  return jsonResponse({
    success: true,
    resource: { resourceId, name, contentType, size: bytes.byteLength, createdAt },
  }, 201);
}

export async function handleSendDirectMessage(request, env, db) {
  const auth = await requireStableAuth(request, env, db);
  if (auth.error) return jsonResponse({ success: false, error: auth.error }, auth.status);
  const body = await request.json();
  const target = await findUser(
    db,
    body.contactId ?? body.targetUserId ?? body.targetUsername ?? body.username,
  );
  if (!target) return jsonResponse({ success: false, error: '未找到联系人' }, 404);
  if (!(await areFriends(db, auth.userId, target.id))) {
    return jsonResponse({ success: false, error: '只能给已添加的好友发送消息' }, 403);
  }

  const text = String(body.text ?? body.message ?? '').trim();
  const clientRequestId = String(body.clientRequestId || '').trim() || null;
  let destination;
  try {
    destination = normalizeDirectMessageDestination(body.destination);
  } catch (error) {
    return jsonResponse({ success: false, error: error.message }, 400);
  }
  try {
    destination = await authorizeDirectMessageDestination(
      destination,
      auth.userId,
      target.id,
    );
  } catch (error) {
    return jsonResponse({ success: false, error: error.message }, 403);
  }
  const destinationJson = destination == null ? null : JSON.stringify(destination);
  let delivery;
  try {
    delivery = normalizeDirectMessageDeliveryOptions(body);
  } catch (error) {
    return jsonResponse({ success: false, error: error.message }, 400);
  }
  if (text.length > MAX_MESSAGE_LENGTH) {
    return jsonResponse({ success: false, error: '消息不能超过 ' + MAX_MESSAGE_LENGTH + ' 个字符' }, 400);
  }
  if (clientRequestId && clientRequestId.length > 200) {
    return jsonResponse({ success: false, error: '消息请求编号不能超过 200 个字符' }, 400);
  }

  let attachments;
  try {
    attachments = await loadOwnedMessageAttachments(db, auth.userId, body.attachments);
  } catch (error) {
    return jsonResponse({ success: false, error: error.message }, 400);
  }
  if (!text && !attachments.length) {
    return jsonResponse({ success: false, error: '消息或附件至少需要一项' }, 400);
  }

  let replyToMessageId = null;
  if (body.replyToMessageId != null && String(body.replyToMessageId).trim()) {
    replyToMessageId = positiveMessageId(body.replyToMessageId);
    if (replyToMessageId == null) {
      return jsonResponse({ success: false, error: '回复目标编号无效' }, 400);
    }
    try {
      replyToMessageId = await validateReplyTarget(db, replyToMessageId, auth.userId, target.id);
    } catch (error) {
      return jsonResponse({ success: false, error: error.message }, 400);
    }
  }

  const attachmentsJson = JSON.stringify(attachments);
  const createdAtMs = Date.now();
  const createdAt = new Date(createdAtMs).toISOString();
  const retention = await readDirectMessageRetention(db, auth.userId, target.id);
  const expiryBaseMs = delivery.scheduledAtMs ?? createdAtMs;
  const expiresAtMs = retention.retentionSeconds == null
    ? null
    : expiryBaseMs + retention.retentionSeconds * 1000;
  if (expiresAtMs != null && !Number.isSafeInteger(expiresAtMs)) {
    return jsonResponse({ success: false, error: '消息到期时间超出安全整数范围' }, 400);
  }
  const result = await db.prepare(
    "INSERT INTO direct_messages (sender_user_id, sender_username, recipient_user_id, recipient_username, body, client_request_id, created_at, reply_to_message_id, attachments_json, silent, scheduled_at_ms, delivery_state, delivered_at, destination_json, expires_at_ms, expired_at_ms) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NULL) ON CONFLICT(sender_user_id, client_request_id) WHERE client_request_id IS NOT NULL DO NOTHING"
  ).bind(
    auth.userId,
    auth.username,
    target.id,
    target.username,
    text,
    clientRequestId,
    createdAt,
    replyToMessageId,
    attachmentsJson,
    delivery.silent ? 1 : 0,
    delivery.scheduledAtMs,
    delivery.deliveryState,
    delivery.deliveredAt,
    destinationJson,
    expiresAtMs,
  ).run();

  let persistedRow = null;
  let deduplicated = false;
  if (result.meta?.changes > 0 && result.meta?.last_row_id) {
    persistedRow = await db.prepare(
      `SELECT ${DIRECT_MESSAGE_SELECT_FIELDS} FROM direct_messages WHERE id = ? LIMIT 1`
    ).bind(result.meta.last_row_id).first();
  } else if (clientRequestId) {
    persistedRow = await db.prepare(
      `SELECT ${DIRECT_MESSAGE_SELECT_FIELDS} FROM direct_messages WHERE sender_user_id = ? AND client_request_id = ? LIMIT 1`
    ).bind(auth.userId, clientRequestId).first();
    deduplicated = true;
  }

  if (!persistedRow) {
    return jsonResponse({ success: false, error: '消息保存结果无法确认' }, 500);
  }

  if (deduplicated && persistedRow.expired_at_ms != null) {
    return jsonResponse({
      success: false,
      error: '消息请求编号对应的消息已经按保留策略到期',
      tombstone: {
        messageId: persistedRow.id,
        clientRequestId: persistedRow.client_request_id,
        expiredAtMs: Number(persistedRow.expired_at_ms),
      },
    }, 410);
  }

  if (deduplicated) {
    let storedAttachments;
    try {
      storedAttachments = parseStoredAttachments(persistedRow.attachments_json);
    } catch {
      return jsonResponse({ success: false, error: '已保存消息的附件元数据损坏' }, 500);
    }
    const samePayload =
      Number(persistedRow.recipient_user_id) === Number(target.id)
      && String(persistedRow.body) === text
      && (persistedRow.reply_to_message_id == null ? null : Number(persistedRow.reply_to_message_id)) === replyToMessageId
      && JSON.stringify(storedAttachments) === attachmentsJson
      && Boolean(Number(persistedRow.silent || 0)) === delivery.silent
      && (persistedRow.scheduled_at_ms == null ? null : Number(persistedRow.scheduled_at_ms)) === delivery.scheduledAtMs
      && (persistedRow.destination_json == null ? null : String(persistedRow.destination_json)) === destinationJson;
    if (!samePayload) {
      return jsonResponse({ success: false, error: '消息请求编号已用于不同内容' }, 409);
    }
  }

  const reactions = await loadReactionMap(db, [persistedRow.id], auth.userId);
  return jsonResponse({
    success: true,
    deduplicated,
    message: projectDirectMessage(
      persistedRow,
      auth.userId,
      reactions.get(String(persistedRow.id)) || [],
    ),
  }, deduplicated ? 200 : 201);
}

export async function handleListDirectMessages(request, env, db) {
  const auth = await requireStableAuth(request, env, db);
  if (auth.error) return jsonResponse({ success: false, error: auth.error }, auth.status);
  await settleExpiredDirectMessages(db);
  const url = new URL(request.url);
  const target = await findUser(
    db,
    url.searchParams.get('contactId') || url.searchParams.get('username'),
  );
  if (!target) return jsonResponse({ success: false, error: '未找到联系人' }, 404);
  if (!(await areFriends(db, auth.userId, target.id))) {
    return jsonResponse({ success: false, error: '只能读取已添加好友的消息' }, 403);
  }
  const limit = clampLimit(url.searchParams.get('limit'), 50, 200);
  const before = (url.searchParams.get('before') || '').trim();
  const rows = await db.prepare(
    `SELECT ${DIRECT_MESSAGE_SELECT_FIELDS} FROM direct_messages
     WHERE ((sender_user_id = ? AND recipient_user_id = ?) OR (sender_user_id = ? AND recipient_user_id = ?))
       AND (sender_user_id = ? OR delivery_state = 'delivered')
       AND expired_at_ms IS NULL
       AND (? = '' OR created_at < ?)
     ORDER BY CASE WHEN delivery_state = 'delivered' THEN COALESCE(delivered_at, created_at) ELSE created_at END DESC, id DESC
     LIMIT ?`
  ).bind(
    auth.userId,
    target.id,
    target.id,
    auth.userId,
    auth.userId,
    before,
    before,
    limit,
  ).all();

  const orderedRows = (rows.results || []).reverse();
  const reactions = await loadReactionMap(db, orderedRows.map((row) => row.id), auth.userId);
  const messages = orderedRows.map((row) => projectDirectMessage(
    row,
    auth.userId,
    reactions.get(String(row.id)) || [],
  ));
  return jsonResponse({ success: true, data: { contact: mapContact(target), messages } });
}

export async function handleGetDirectMessageRetention(request, env, db) {
  const auth = await requireStableAuth(request, env, db);
  if (auth.error) return jsonResponse({ success: false, error: auth.error }, auth.status);
  const url = new URL(request.url);
  const target = await findUser(db, url.searchParams.get('contactId') || url.searchParams.get('username'));
  if (!target) return jsonResponse({ success: false, error: '未找到联系人' }, 404);
  if (!(await areFriends(db, auth.userId, target.id))) {
    return jsonResponse({ success: false, error: '只能读取已添加好友的消息保留策略' }, 403);
  }
  const retention = await readDirectMessageRetention(db, auth.userId, target.id);
  return jsonResponse({ success: true, retention });
}

export async function handleSetDirectMessageRetention(request, env, db) {
  const auth = await requireStableAuth(request, env, db);
  if (auth.error) return jsonResponse({ success: false, error: auth.error }, auth.status);
  const body = await request.json();
  const target = await findUser(
    db,
    body.contactId ?? body.targetUserId ?? body.targetUsername ?? body.username,
  );
  if (!target) return jsonResponse({ success: false, error: '未找到联系人' }, 404);
  if (!(await areFriends(db, auth.userId, target.id))) {
    return jsonResponse({ success: false, error: '只能修改已添加好友的消息保留策略' }, 403);
  }
  let retentionSeconds;
  try {
    retentionSeconds = normalizeRetentionSeconds(body.retentionSeconds);
  } catch (error) {
    return jsonResponse({ success: false, error: error.message }, 400);
  }
  const expectedRevision = body.expectedRevision;
  if (!Number.isSafeInteger(expectedRevision) || expectedRevision < 0) {
    return jsonResponse({ success: false, error: 'expectedRevision 必须是非负安全整数' }, 400);
  }

  const current = await readDirectMessageRetention(db, auth.userId, target.id);
  if (current.revision !== expectedRevision) {
    return jsonResponse({
      success: false,
      error: '消息保留策略版本已过期',
      retention: current,
    }, 409);
  }

  const [userLowId, userHighId] = retentionPair(auth.userId, target.id);
  const nextRevision = expectedRevision + 1;
  const updatedAt = new Date().toISOString();
  let result;
  if (expectedRevision === 0) {
    result = await db.prepare(
      'INSERT INTO direct_message_retention_policies (conversation_id, user_low_id, user_high_id, retention_seconds, retention_revision, updated_at) VALUES (?, ?, ?, ?, ?, ?) ON CONFLICT(conversation_id) DO NOTHING'
    ).bind(current.conversationId, userLowId, userHighId, retentionSeconds, nextRevision, updatedAt).run();
  } else {
    result = await db.prepare(
      'UPDATE direct_message_retention_policies SET retention_seconds = ?, retention_revision = ?, updated_at = ? WHERE conversation_id = ? AND retention_revision = ?'
    ).bind(retentionSeconds, nextRevision, updatedAt, current.conversationId, expectedRevision).run();
  }
  if (Number(result?.meta?.changes || 0) !== 1) {
    const latest = await readDirectMessageRetention(db, auth.userId, target.id);
    return jsonResponse({
      success: false,
      error: '消息保留策略版本已过期',
      retention: latest,
    }, 409);
  }
  return jsonResponse({
    success: true,
    retention: {
      conversationId: current.conversationId,
      retentionSeconds,
      revision: nextRevision,
    },
  });
}

export async function handleGetConversationChildDraft(request, env, db) {
  const auth = await requireStableAuth(request, env, db);
  if (auth.error) return jsonResponse({ success: false, error: auth.error }, auth.status);
  const url = new URL(request.url);
  let resolved;
  try {
    resolved = await resolveSavedSublistDraftDestination(
      db,
      auth.userId,
      url.searchParams.get('contactId') || url.searchParams.get('username'),
    );
  } catch (error) {
    const status = error.message === '未找到联系人' ? 404 : 403;
    return jsonResponse({ success: false, error: error.message }, status);
  }
  const draft = await readConversationChildDraft(db, auth.userId, resolved.destination);
  return jsonResponse({ success: true, draft });
}

export async function handleSetConversationChildDraft(request, env, db) {
  const auth = await requireStableAuth(request, env, db);
  if (auth.error) return jsonResponse({ success: false, error: auth.error }, auth.status);
  let body;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ success: false, error: 'ConversationChild 草稿请求格式无效' }, 400);
  }
  if (body == null || typeof body !== 'object' || Array.isArray(body)) {
    return jsonResponse({ success: false, error: 'ConversationChild 草稿请求格式无效' }, 400);
  }

  let resolved;
  try {
    resolved = await resolveSavedSublistDraftDestination(
      db,
      auth.userId,
      body.contactId ?? body.targetUserId ?? body.targetUsername ?? body.username,
      body.destination,
    );
  } catch (error) {
    const status = error.message === '未找到联系人' ? 404
      : error.message.includes('已添加好友') ? 403
        : 400;
    return jsonResponse({ success: false, error: error.message }, status);
  }

  if (typeof body.text !== 'string' || body.text.length > MAX_MESSAGE_LENGTH) {
    return jsonResponse({ success: false, error: '草稿文本必须是长度不超过 4000 的字符串' }, 400);
  }
  const expectedRevision = body.expectedRevision;
  if (!Number.isSafeInteger(expectedRevision) || expectedRevision < 0 || expectedRevision >= Number.MAX_SAFE_INTEGER) {
    return jsonResponse({ success: false, error: 'expectedRevision 必须是可安全递增的非负整数' }, 400);
  }

  let replyToMessageId;
  try {
    replyToMessageId = await validateConversationChildDraftReply(
      db,
      auth.userId,
      resolved.target.id,
      resolved.destination,
      body.replyToMessageId,
    );
  } catch (error) {
    return jsonResponse({ success: false, error: error.message }, 400);
  }

  const current = await readConversationChildDraft(db, auth.userId, resolved.destination);
  if (current.revision !== expectedRevision) {
    return jsonResponse({ success: false, error: 'ConversationChild 草稿版本已过期', draft: current }, 409);
  }

  const { childKind, childId } = conversationChildDraftIdentity(resolved.destination);
  const nextRevision = expectedRevision + 1;
  const updatedAt = new Date().toISOString();
  let result;
  if (expectedRevision === 0) {
    result = await db.prepare(
      'INSERT INTO conversation_child_drafts (owner_user_id, conversation_id, child_kind, child_id, draft_text, reply_to_message_id, draft_revision, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?) ON CONFLICT(owner_user_id, conversation_id, child_kind, child_id) DO NOTHING'
    ).bind(
      auth.userId,
      resolved.destination.conversationId,
      childKind,
      childId,
      body.text,
      replyToMessageId,
      nextRevision,
      updatedAt,
    ).run();
  } else {
    result = await db.prepare(
      'UPDATE conversation_child_drafts SET draft_text = ?, reply_to_message_id = ?, draft_revision = ?, updated_at = ? WHERE owner_user_id = ? AND conversation_id = ? AND child_kind = ? AND child_id = ? AND draft_revision = ?'
    ).bind(
      body.text,
      replyToMessageId,
      nextRevision,
      updatedAt,
      auth.userId,
      resolved.destination.conversationId,
      childKind,
      childId,
      expectedRevision,
    ).run();
  }
  if (Number(result?.meta?.changes || 0) !== 1) {
    const latest = await readConversationChildDraft(db, auth.userId, resolved.destination);
    return jsonResponse({ success: false, error: 'ConversationChild 草稿版本已过期', draft: latest }, 409);
  }
  return jsonResponse({
    success: true,
    draft: {
      destination: resolved.destination,
      text: body.text,
      replyToMessageId: replyToMessageId == null ? null : String(replyToMessageId),
      revision: nextRevision,
      updatedAt,
    },
  });
}

export async function handleSetDirectMessageReaction(request, env, db, rawMessageId) {
  const auth = await requireStableAuth(request, env, db);
  if (auth.error) return jsonResponse({ success: false, error: auth.error }, auth.status);
  const messageId = positiveMessageId(rawMessageId);
  if (messageId == null) {
    return jsonResponse({ success: false, error: '消息编号无效' }, 400);
  }
  const message = await db.prepare(
    "SELECT id, sender_user_id, recipient_user_id FROM direct_messages WHERE id = ? AND expired_at_ms IS NULL AND (sender_user_id = ? OR delivery_state = 'delivered') LIMIT 1"
  ).bind(messageId, auth.userId).first();
  if (!message || (
    Number(message.sender_user_id) !== Number(auth.userId)
    && Number(message.recipient_user_id) !== Number(auth.userId)
  )) {
    return jsonResponse({ success: false, error: '消息不存在' }, 404);
  }

  const peerUserId = Number(message.sender_user_id) === Number(auth.userId)
    ? Number(message.recipient_user_id)
    : Number(message.sender_user_id);
  if (!(await areFriends(db, auth.userId, peerUserId))) {
    return jsonResponse({ success: false, error: '只能操作已添加好友的消息' }, 403);
  }

  const body = await request.json();
  const emoji = String(body.emoji || '').trim();
  const active = body.active;
  if (!emoji || new TextEncoder().encode(emoji).byteLength > MAX_REACTION_BYTES) {
    return jsonResponse({ success: false, error: '消息表情无效或过长' }, 400);
  }
  if (typeof active !== 'boolean') {
    return jsonResponse({ success: false, error: '消息表情状态必须是布尔值' }, 400);
  }

  const now = new Date().toISOString();
  if (active) {
    await db.prepare(
      'INSERT INTO direct_message_reactions (message_id, user_id, emoji, created_at, updated_at) VALUES (?, ?, ?, ?, ?) ON CONFLICT(message_id, user_id, emoji) DO UPDATE SET updated_at = excluded.updated_at'
    ).bind(messageId, auth.userId, emoji, now, now).run();
  } else {
    await db.prepare(
      'DELETE FROM direct_message_reactions WHERE message_id = ? AND user_id = ? AND emoji = ?'
    ).bind(messageId, auth.userId, emoji).run();
  }

  const reactions = await loadReactionMap(db, [messageId], auth.userId);
  return jsonResponse({
    success: true,
    messageId,
    reactions: reactions.get(String(messageId)) || [],
  });
}
