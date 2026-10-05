import { jsonResponse } from '../utils/response.js';
import { requireAuthIdentity } from '../utils/auth-identity.js';

const MAX_MESSAGE_ATTACHMENT_BYTES = 25 * 1024 * 1024;

async function requireStableAuth(request, env, db) {
  const auth = await requireAuthIdentity(request, env, db);
  if (auth.error) return auth;
  if (!Number.isFinite(auth.userId)) {
    return { error: '账号资料需要刷新后才能使用消息附件', status: 409 };
  }
  return auth;
}

function sanitizeFileName(value) {
  const raw = String(value || '').replaceAll('\\', '/').split('/').pop()?.trim() || '';
  const cleaned = raw.replace(/[\u0000-\u001f\u007f]/g, '').slice(0, 255);
  return cleaned || 'attachment';
}

function safeContentType(value) {
  const raw = String(value || '').trim().toLowerCase();
  if (!raw || raw.length > 200 || /[\r\n]/.test(raw)) return 'application/octet-stream';
  return raw;
}

export async function handleUploadDirectMessageAttachment(request, env, db) {
  const auth = await requireStableAuth(request, env, db);
  if (auth.error) return jsonResponse({ success: false, error: auth.error }, auth.status);
  if (!env.R2_BUCKET) return jsonResponse({ success: false, error: 'R2存储桶未绑定' }, 500);

  const url = new URL(request.url);
  const fileName = sanitizeFileName(url.searchParams.get('name'));
  const contentType = safeContentType(request.headers.get('content-type'));
  const declaredSize = Number(request.headers.get('content-length') || 0);
  if (Number.isFinite(declaredSize) && declaredSize > MAX_MESSAGE_ATTACHMENT_BYTES) {
    return jsonResponse({ success: false, error: '消息附件不能超过 25MB' }, 413);
  }

  const bytes = new Uint8Array(await request.arrayBuffer());
  if (bytes.length === 0) return jsonResponse({ success: false, error: '消息附件不能为空' }, 400);
  if (bytes.length > MAX_MESSAGE_ATTACHMENT_BYTES) {
    return jsonResponse({ success: false, error: '消息附件不能超过 25MB' }, 413);
  }

  const id = crypto.randomUUID();
  const objectKey = `message-attachments/${auth.userId}/${id}`;
  const createdAt = new Date().toISOString();
  await env.R2_BUCKET.put(objectKey, bytes, {
    httpMetadata: { contentType },
    customMetadata: {
      ownerUserId: String(auth.userId),
      fileName,
    },
  });

  try {
    await db.prepare(`
      INSERT INTO direct_message_attachments (
        id, uploader_user_id, object_key, file_name,
        content_type, size_bytes, message_id, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, NULL, ?)
    `).bind(
      id, auth.userId, objectKey, fileName,
      contentType, bytes.length, createdAt,
    ).run();
  } catch (error) {
    await env.R2_BUCKET.delete(objectKey);
    throw error;
  }

  return jsonResponse({
    success: true,
    attachment: {
      id,
      name: fileName,
      contentType,
      size: bytes.length,
    },
  }, 201);
}

export async function handleGetDirectMessageAttachment(request, env, db, attachmentId) {
  const auth = await requireStableAuth(request, env, db);
  if (auth.error) return jsonResponse({ success: false, error: auth.error }, auth.status);
  if (!env.R2_BUCKET) return jsonResponse({ success: false, error: 'R2存储桶未绑定' }, 500);

  const row = await db.prepare(`
    SELECT a.object_key, a.file_name, a.content_type, a.size_bytes
    FROM direct_message_attachments a
    JOIN direct_messages m ON m.id = a.message_id
    WHERE a.id = ?
      AND (m.sender_user_id = ? OR m.recipient_user_id = ?)
    LIMIT 1
  `).bind(attachmentId, auth.userId, auth.userId).first();
  if (!row) return jsonResponse({ success: false, error: '消息附件不存在或无权访问' }, 404);

  const object = await env.R2_BUCKET.get(row.object_key);
  if (!object) return jsonResponse({ success: false, error: '消息附件对象不存在' }, 404);
  const headers = new Headers();
  headers.set('Content-Type', row.content_type || 'application/octet-stream');
  headers.set('Content-Length', String(row.size_bytes));
  headers.set('Cache-Control', 'private, max-age=300');
  headers.set('X-Content-Type-Options', 'nosniff');
  headers.set('Content-Disposition', `attachment; filename*=UTF-8''${encodeURIComponent(row.file_name)}`);
  return new Response(object.body, { status: 200, headers });
}

export async function handleDeleteDirectMessageAttachment(request, env, db, attachmentId) {
  const auth = await requireStableAuth(request, env, db);
  if (auth.error) return jsonResponse({ success: false, error: auth.error }, auth.status);
  if (!env.R2_BUCKET) return jsonResponse({ success: false, error: 'R2存储桶未绑定' }, 500);

  const row = await db.prepare(`
    SELECT object_key
    FROM direct_message_attachments
    WHERE id = ? AND uploader_user_id = ? AND message_id IS NULL
    LIMIT 1
  `).bind(attachmentId, auth.userId).first();
  if (!row) return jsonResponse({ success: false, error: '未找到可删除的待发送附件' }, 404);

  await db.prepare(`
    DELETE FROM direct_message_attachments
    WHERE id = ? AND uploader_user_id = ? AND message_id IS NULL
  `).bind(attachmentId, auth.userId).run();
  await env.R2_BUCKET.delete(row.object_key);
  return jsonResponse({ success: true, attachmentId });
}
