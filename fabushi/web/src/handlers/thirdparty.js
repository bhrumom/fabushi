import { jsonResponse } from '../utils/response.js';
import { verifyToken } from '../../auth-utils.js';

async function resolveAuthenticatedUser(db, tokenData) {
  if (tokenData?.userId !== undefined && tokenData?.userId !== null && db.getUserById) {
    const user = await db.getUserById(tokenData.userId);
    if (user) return user;
  }
  if (tokenData?.username) return await db.getUser(tokenData.username);
  return null;
}

export async function handleBindEmail(request, env, db) {
  const authHeader = request.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) return jsonResponse({ error: '未提供认证信息' }, 401);

  const tokenData = await verifyToken(authHeader.substring(7), env);
  if (!tokenData) return jsonResponse({ error: '认证失败' }, 401);
  const user = await resolveAuthenticatedUser(db, tokenData);
  if (!user) return jsonResponse({ error: '用户不存在' }, 404);

  const { email } = await request.json();
  if (!email) return jsonResponse({ error: '邮箱与验证码不能为空' }, 400);

  const normalizedEmail = email.toLowerCase();
  const existing = await db.getUserByEmail(normalizedEmail);
  if (existing && existing.id !== user.id) {
    return jsonResponse({ error: '该邮箱已被其他账号绑定' }, 400);
  }

  await db.prepare('UPDATE users SET email = ?, email_verified = ?, updated_at = ? WHERE id = ?')
    .bind(normalizedEmail, 1, new Date().toISOString(), user.id)
    .run();
  await db.prepare('DELETE FROM email_username_mapping WHERE user_id = ? OR email = ?')
    .bind(user.id, normalizedEmail)
    .run();
  await db.prepare('INSERT OR REPLACE INTO email_username_mapping (email, username, user_id) VALUES (?, ?, ?)')
    .bind(normalizedEmail, user.username, user.id)
    .run();

  return jsonResponse({ message: '邮箱绑定成功', email: normalizedEmail });
}
