import { verifyToken } from '../../auth-utils.js';
import { jsonResponse } from '../utils/response.js';
import { platformDb } from '../services/monetization-platform.js';
import { resolveCapabilityAccess } from '../services/monetization-access.js';

async function resolveIdentity(request, env, db) {
  const authorization = request.headers.get('Authorization') || '';
  if (!authorization.startsWith('Bearer ')) return { response: jsonResponse({ error: '未提供认证信息' }, 401) };
  const claims = await verifyToken(authorization.slice(7), env);
  if (!claims) return { response: jsonResponse({ error: '认证失败' }, 401) };
  let user = null;
  if (claims.userId != null && db?.getUserById) user = await db.getUserById(claims.userId);
  if (!user && claims.username && db?.getUser) user = await db.getUser(claims.username);
  const userId = String(user?.id ?? claims.userId ?? claims.sub ?? claims.username ?? '').trim();
  if (!userId) return { response: jsonResponse({ error: '账号身份不可用' }, 401) };
  return { userId };
}

export async function handleMonetizationAccess(request, env, db) {
  try {
    const identity = await resolveIdentity(request, env, db);
    if (identity.response) return identity.response;
    const url = new URL(request.url);
    const miniAppId = url.searchParams.get('miniAppId');
    const capability = url.searchParams.get('capability');
    if (!miniAppId || !capability) return jsonResponse({ error: 'miniAppId 与 capability 必填' }, 400);
    const access = await resolveCapabilityAccess(platformDb(env), {
      userId: identity.userId,
      miniAppId,
      capability,
    });
    return jsonResponse({ userId: identity.userId, miniAppId, capability, ...access });
  } catch (error) {
    const message = String(error?.message || error || 'unknown error');
    console.error('Monetization access check failed:', message);
    const status = error instanceof TypeError || error instanceof RangeError ? 400 : 500;
    return jsonResponse({ error: status === 400 ? message : 'Monetization access check failed' }, status);
  }
}
