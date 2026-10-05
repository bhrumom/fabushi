import { jsonResponse } from '../utils/response.js';
import { requireAuthIdentity } from '../utils/auth-identity.js';

const MAX_MESSAGE_LENGTH = 4000;

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


function parseJsonArray(value) {
  if (Array.isArray(value)) return value;
  if (typeof value !== 'string' || !value) return [];
  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed) ? parsed : [];
  } catch {
    return [];
  }
}

function mapDirectMessage(row, authUserId) {
  return {
    id: row.id,
    senderUserId: row.sender_user_id,
    senderUsername: row.sender_username,
    recipientUserId: row.recipient_user_id,
    recipientUsername: row.recipient_username,
    text: row.body,
    clientRequestId: row.client_request_id,
    createdAt: row.created_at,
    readAt: row.read_at ?? null,
    isOutgoing: row.sender_user_id === authUserId,
    replyToMessageId: row.reply_to_message_id ?? null,
    attachments: parseJsonArray(row.attachments_json),
    reactions: parseJsonArray(row.reactions_json).map((reaction) => ({
      ...reaction,
      isSelf: Number(reaction.userId) === Number(authUserId),
    })),
  };
}

async function requireConversationMessage(db, messageId, firstUserId, secondUserId) {
  const id = Number(messageId);
  if (!Number.isSafeInteger(id) || id <= 0) return null;
  return await db.prepare(`
    SELECT id, sender_user_id, recipient_user_id
    FROM direct_messages
    WHERE id = ?
      AND ((sender_user_id = ? AND recipient_user_id = ?)
        OR (sender_user_id = ? AND recipient_user_id = ?))
    LIMIT 1
  `).bind(id, firstUserId, secondUserId, secondUserId, firstUserId).first();
}

async function resolveMessageAttachments(db, authUserId, attachmentIds, permittedMessageId = null) {
  if (!Array.isArray(attachmentIds) || attachmentIds.length === 0) return [];
  const ids = [...new Set(attachmentIds.map((value) => String(value || '').trim()).filter(Boolean))];
  if (ids.length === 0) return [];
  if (ids.length > 10) throw new Error('ATTACHMENT_LIMIT');
  const placeholders = ids.map(() => '?').join(', ');
  const rows = await db.prepare(`
    SELECT id, file_name, content_type, size_bytes
    FROM direct_message_attachments
    WHERE uploader_user_id = ?
      AND (message_id IS NULL OR message_id = ?)
      AND id IN (${placeholders})
  `).bind(authUserId, permittedMessageId, ...ids).all();
  if ((rows.results || []).length !== ids.length) throw new Error('ATTACHMENT_NOT_OWNED');
  const byId = new Map((rows.results || []).map((row) => [String(row.id), row]));
  return ids.map((id) => {
    const row = byId.get(id);
    return {
      id,
      name: row.file_name,
      contentType: row.content_type,
      size: row.size_bytes,
    };
  });
}

function directMessageSelectColumns() {
  return `
    dm.id, dm.sender_user_id, dm.sender_username, dm.recipient_user_id,
    dm.recipient_username, dm.body, dm.client_request_id, dm.created_at,
    dm.read_at, dm.reply_to_message_id, dm.attachments_json,
    COALESCE((
      SELECT json_group_array(json_object(
        'emoji', r.emoji,
        'userId', r.user_id,
        'createdAt', r.created_at
      ))
      FROM direct_message_reactions r
      WHERE r.message_id = dm.id
    ), '[]') AS reactions_json
  `;
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

  const clientRequestId = String(body.clientRequestId || '').trim() || null;
  if (clientRequestId && clientRequestId.length > 200) {
    return jsonResponse({ success: false, error: '消息请求编号不能超过 200 个字符' }, 400);
  }
  const existingRequestRow = clientRequestId
    ? await db.prepare(`
        SELECT ${directMessageSelectColumns()}
        FROM direct_messages dm
        WHERE dm.sender_user_id = ? AND dm.client_request_id = ?
        LIMIT 1
      `).bind(auth.userId, clientRequestId).first()
    : null;

  let attachments;
  try {
    attachments = await resolveMessageAttachments(
      db,
      auth.userId,
      body.attachmentIds,
      existingRequestRow?.id ?? null,
    );
  } catch (error) {
    if (error?.message === 'ATTACHMENT_LIMIT') {
      return jsonResponse({ success: false, error: '每条消息最多包含 10 个附件' }, 400);
    }
    if (error?.message === 'ATTACHMENT_NOT_OWNED') {
      return jsonResponse({ success: false, error: '消息附件不存在、已使用或不属于当前账号' }, 400);
    }
    throw error;
  }

  const text = String(body.text ?? body.message ?? '').trim();
  if (!text && attachments.length === 0) {
    return jsonResponse({ success: false, error: '消息或附件不能为空' }, 400);
  }
  if (text.length > MAX_MESSAGE_LENGTH) {
    return jsonResponse({ success: false, error: `消息不能超过 ${MAX_MESSAGE_LENGTH} 个字符` }, 400);
  }

  const rawReplyId = body.replyToMessageId ?? body.replyToId ?? null;
  let replyToMessageId = null;
  if (rawReplyId !== null && rawReplyId !== undefined && rawReplyId !== '') {
    const reply = await requireConversationMessage(db, rawReplyId, auth.userId, target.id);
    if (!reply) return jsonResponse({ success: false, error: '回复目标不属于当前会话' }, 400);
    replyToMessageId = Number(reply.id);
  }

  const attachmentIds = attachments.map((attachment) => attachment.id);
  const attachmentsJson = JSON.stringify(attachments);
  let persistedRow = existingRequestRow;
  let deduplicated = persistedRow != null;

  if (persistedRow == null) {
    const createdAt = new Date().toISOString();
    const result = await db.prepare(`
      INSERT INTO direct_messages (
        sender_user_id, sender_username, recipient_user_id,
        recipient_username, body, client_request_id, created_at,
        reply_to_message_id, attachments_json
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(sender_user_id, client_request_id) WHERE client_request_id IS NOT NULL
      DO NOTHING
    `).bind(
      auth.userId, auth.username, target.id, target.username,
      text, clientRequestId, createdAt, replyToMessageId, attachmentsJson,
    ).run();

    const insertedId = Number(result.meta?.last_row_id || 0);
    if (result.meta?.changes !== 0 && insertedId > 0) {
      persistedRow = await db.prepare(`
        SELECT ${directMessageSelectColumns()}
        FROM direct_messages dm
        WHERE dm.id = ?
        LIMIT 1
      `).bind(insertedId).first();
    } else if (clientRequestId) {
      deduplicated = true;
      persistedRow = await db.prepare(`
        SELECT ${directMessageSelectColumns()}
        FROM direct_messages dm
        WHERE dm.sender_user_id = ? AND dm.client_request_id = ?
        LIMIT 1
      `).bind(auth.userId, clientRequestId).first();
    }
  }
  if (!persistedRow) {
    return jsonResponse({ success: false, error: '消息保存结果无法确认' }, 500);
  }

  const persisted = mapDirectMessage(persistedRow, auth.userId);
  if (
    persisted.recipientUserId !== target.id
    || persisted.text !== text
    || Number(persisted.replyToMessageId || 0) !== Number(replyToMessageId || 0)
    || JSON.stringify(persisted.attachments || []) !== attachmentsJson
  ) {
    return jsonResponse({ success: false, error: '消息请求编号已绑定到不同内容' }, 409);
  }

  if (attachmentIds.length > 0) {
    await db.batch(attachmentIds.map((attachmentId) => db.prepare(`
      UPDATE direct_message_attachments
      SET message_id = ?
      WHERE id = ? AND uploader_user_id = ?
        AND (message_id IS NULL OR message_id = ?)
    `).bind(persisted.id, attachmentId, auth.userId, persisted.id)));
  }

  return jsonResponse({
    success: true,
    deduplicated,
    message: persisted,
  }, deduplicated ? 200 : 201);
}

export async function handleListDirectMessages(request, env, db) {
  const auth = await requireStableAuth(request, env, db);
  if (auth.error) return jsonResponse({ success: false, error: auth.error }, auth.status);
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
  const rows = await db.prepare(`
    SELECT ${directMessageSelectColumns()}
    FROM direct_messages dm
    WHERE ((dm.sender_user_id = ? AND dm.recipient_user_id = ?)
      OR (dm.sender_user_id = ? AND dm.recipient_user_id = ?))
      AND (? = '' OR dm.created_at < ?)
    ORDER BY dm.created_at DESC, dm.id DESC
    LIMIT ?
  `).bind(
    auth.userId, target.id, target.id, auth.userId,
    before, before, limit,
  ).all();

  const messages = (rows.results || []).reverse().map((row) =>
    mapDirectMessage(row, auth.userId));
  return jsonResponse({ success: true, data: { contact: mapContact(target), messages } });
}

export async function handleSetDirectMessageReaction(request, env, db, messageId) {
  const auth = await requireStableAuth(request, env, db);
  if (auth.error) return jsonResponse({ success: false, error: auth.error }, auth.status);
  const id = Number(messageId);
  if (!Number.isSafeInteger(id) || id <= 0) {
    return jsonResponse({ success: false, error: '消息编号无效' }, 400);
  }
  const message = await db.prepare(`
    SELECT id
    FROM direct_messages
    WHERE id = ? AND (sender_user_id = ? OR recipient_user_id = ?)
    LIMIT 1
  `).bind(id, auth.userId, auth.userId).first();
  if (!message) return jsonResponse({ success: false, error: '消息不存在或无权操作' }, 404);

  const body = await request.json();
  const emoji = String(body.emoji || '').trim();
  if (!emoji || emoji.length > 32) {
    return jsonResponse({ success: false, error: 'Reaction 必须是 1-32 个字符' }, 400);
  }
  const active = body.active !== false;
  if (active) {
    await db.prepare(`
      INSERT INTO direct_message_reactions (message_id, user_id, emoji, created_at)
      VALUES (?, ?, ?, ?)
      ON CONFLICT(message_id, user_id, emoji) DO NOTHING
    `).bind(id, auth.userId, emoji, new Date().toISOString()).run();
  } else {
    await db.prepare(`
      DELETE FROM direct_message_reactions
      WHERE message_id = ? AND user_id = ? AND emoji = ?
    `).bind(id, auth.userId, emoji).run();
  }

  const rows = await db.prepare(`
    SELECT emoji, user_id, created_at
    FROM direct_message_reactions
    WHERE message_id = ?
    ORDER BY created_at ASC, user_id ASC, emoji ASC
  `).bind(id).all();
  return jsonResponse({
    success: true,
    messageId: id,
    reactions: (rows.results || []).map((row) => ({
      emoji: row.emoji,
      userId: row.user_id,
      createdAt: row.created_at,
      isSelf: Number(row.user_id) === Number(auth.userId),
    })),
  });
}
