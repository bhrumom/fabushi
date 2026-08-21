import { verifyToken } from '../../auth-utils.js';
import { jsonResponse } from '../utils/response.js';
import { isAdmin } from '../utils/helpers.js';

const ADMIN_ONLY_PATHS = new Set([
  '/migrate-builtin-complete',
  '/api/admin/reports',
  '/api/admin/reports/review',
  '/api/admin/blocks',
  '/api/admin/create-redeem-code',
  '/api/admin/redeem-codes',
  '/api/admin/delete-redeem-code',
]);

function decodeBase64Url(value) {
  const normalized = String(value || '').replace(/-/g, '+').replace(/_/g, '/');
  const padding = normalized.length % 4 === 0 ? '' : '='.repeat(4 - (normalized.length % 4));
  const raw = atob(normalized + padding);
  return Uint8Array.from(raw, (char) => char.charCodeAt(0));
}

async function verifyHmacReceipt(receipt, secret) {
  const parts = String(receipt || '').split('.');
  if (parts.length !== 2) return null;
  const [payloadPart, signaturePart] = parts;
  let payload;
  try {
    payload = JSON.parse(new TextDecoder().decode(decodeBase64Url(payloadPart)));
  } catch {
    return null;
  }
  try {
    const key = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(secret),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['verify'],
    );
    const valid = await crypto.subtle.verify(
      'HMAC',
      key,
      decodeBase64Url(signaturePart),
      new TextEncoder().encode(payloadPart),
    );
    return valid ? payload : null;
  } catch {
    return null;
  }
}

async function resolveTokenAndUser(request, env, db) {
  const auth = request.headers.get('Authorization') || '';
  if (!auth.startsWith('Bearer ')) return { token: null, user: null };
  const token = await verifyToken(auth.slice(7), env);
  if (!token) return { token: null, user: null };
  if (token.userId !== undefined && token.userId !== null && db.getUserById) {
    const user = await db.getUserById(token.userId);
    if (user) return { token, user };
  }
  if (token.username) return { token, user: await db.getUser(token.username) };
  return { token, user: null };
}

async function resolveUser(request, env, db) {
  return (await resolveTokenAndUser(request, env, db)).user;
}

function isUniqueConstraintError(error) {
  const message = String(error?.message || error || '').toLowerCase();
  return message.includes('unique constraint') || message.includes('primary key') || message.includes('constraint failed');
}

async function claimTransferReceipt(db, { jti, user, bytes, exp }) {
  if (!db?.prepare) throw new Error('transfer receipt claim database unavailable');
  try {
    await db.prepare(`
      INSERT INTO transfer_receipt_claims
        (jti, account_user_id, username, bytes, expires_at, claimed_at)
      VALUES (?, ?, ?, ?, ?, ?)
    `).bind(
      jti,
      user.id === undefined || user.id === null ? null : String(user.id),
      String(user.username || ''),
      bytes,
      exp,
      new Date().toISOString(),
    ).run();
    return true;
  } catch (error) {
    if (isUniqueConstraintError(error)) return false;
    throw error;
  }
}

async function enforceTransferReceipt(request, env, db) {
  const { user } = await resolveTokenAndUser(request, env, db);
  if (!user) return jsonResponse({ error: '认证失败' }, 401);

  const secret = String(env.TRANSFER_RECEIPT_SECRET || '').trim();
  if (secret.length < 32) {
    console.error('TRANSFER_RECEIPT_SECRET is missing or insecure');
    return jsonResponse({ error: '传输统计服务暂不可用' }, 503);
  }

  const receipt = request.headers.get('X-Fabushi-Transfer-Receipt') || '';
  const payload = await verifyHmacReceipt(receipt, secret);
  if (!payload) return jsonResponse({ error: '传输凭证无效' }, 403);

  let body;
  try {
    body = await request.clone().json();
  } catch {
    return jsonResponse({ error: '请求内容无效' }, 400);
  }
  const bytes = Number(body?.bytes);
  const receiptBytes = Number(payload?.bytes);
  const now = Math.floor(Date.now() / 1000);
  const exp = Number(payload?.exp);
  const jti = String(payload?.jti || '');
  const receiptUserId = payload?.userId === undefined || payload?.userId === null ? '' : String(payload.userId);
  const receiptUsername = String(payload?.username || '');

  if (!Number.isSafeInteger(bytes) || bytes <= 0 || bytes > 10 * 1024 * 1024 * 1024) {
    return jsonResponse({ error: '传输字节数无效' }, 400);
  }
  if (receiptBytes !== bytes || !Number.isSafeInteger(exp) || exp < now || exp > now + 600) {
    return jsonResponse({ error: '传输凭证已过期或与请求不匹配' }, 403);
  }
  if (!/^[A-Za-z0-9_-]{16,128}$/.test(jti)) {
    return jsonResponse({ error: '传输凭证标识无效' }, 403);
  }
  const stableUserMatch = user.id !== undefined && user.id !== null && receiptUserId === String(user.id);
  const usernameMatch = receiptUsername && receiptUsername === String(user.username || '');
  if (!stableUserMatch && !usernameMatch) {
    return jsonResponse({ error: '传输凭证不属于当前账号' }, 403);
  }

  try {
    const claimed = await claimTransferReceipt(db, { jti, user, bytes, exp });
    if (!claimed) return jsonResponse({ error: '传输凭证已使用' }, 409);
  } catch (error) {
    console.error('transfer receipt atomic claim failed:', error?.message || error);
    return jsonResponse({ error: '传输凭证防重放存储不可用' }, 503);
  }
  return null;
}

export async function enforceRequestSecurityGate(request, env, db) {
  const url = new URL(request.url);
  const pathname = url.pathname;

  if (pathname === '/api/leaderboard/update' && request.method === 'POST') {
    return await enforceTransferReceipt(request, env, db);
  }

  if (!ADMIN_ONLY_PATHS.has(pathname)) return null;
  const user = await resolveUser(request, env, db);
  if (!user) return jsonResponse({ error: '认证失败' }, 401);
  if (!isAdmin(user.email, env)) return jsonResponse({ error: '权限不足' }, 403);
  return null;
}
