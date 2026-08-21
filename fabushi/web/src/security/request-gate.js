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

async function resolveUser(request, env, db) {
  const auth = request.headers.get('Authorization') || '';
  if (!auth.startsWith('Bearer ')) return null;
  const token = await verifyToken(auth.slice(7), env);
  if (!token) return null;
  if (token.userId !== undefined && token.userId !== null && db.getUserById) {
    const user = await db.getUserById(token.userId);
    if (user) return user;
  }
  if (token.username) return await db.getUser(token.username);
  return null;
}

export async function enforceRequestSecurityGate(request, env, db) {
  const url = new URL(request.url);
  const pathname = url.pathname;
  if (!ADMIN_ONLY_PATHS.has(pathname)) return null;

  const user = await resolveUser(request, env, db);
  if (!user) return jsonResponse({ error: '认证失败' }, 401);
  if (!isAdmin(user.email, env)) return jsonResponse({ error: '权限不足' }, 403);
  return null;
}
