import { handleRegister, handleLogin, handleGetUserInfo } from './handlers/auth.js';
import { handleSendVerificationCode, handleForgotPassword, handleResetPassword } from './handlers/verification.js';
import { handleGetWechatLoginUrl, handleGetAlipayLoginUrl, handleAlipayLogin, handleAlipayRegister, handleBindEmail, handleMacOSAlipayCallback } from './handlers/thirdparty.js';
import { handleCreateAlipayOrder, handleQueryAlipayOrder, handleAlipayNotify } from './handlers/payment.js';
import { handleCreateRedeemCode, handleUseRedeemCode, handleGetPurchaseHistory, handleGetRedeemHistory } from './handlers/redeem.js';
import { handleCheckMembershipStatus, handleCheckAlipayMembership } from './handlers/membership.js';
import { handleMigrateKvToD1 } from './handlers/migration.js';
import { handleCheckAdminStatus, handleListRedeemCodes, handleDeleteRedeemCode, handleGetAdminPrice } from './handlers/admin.js';
import { handleGetAssetsList, handleR2List, handleR2Proxy } from './handlers/assets.js';
import { handleSearch, handleGetTextContent, handleGetCategories } from './handlers/search.js';
import { handleGetLeaderboard, handleUpdateTransferData } from './handlers/leaderboard.js';
import { handleToggleLike, handleGetLikeCount, handleBatchGetLikeCounts } from './handlers/likes.js';
import { jsonResponse } from './utils/response.js';

export async function route(request, env, db, ctx) {
  const url = new URL(request.url);
  const pathname = url.pathname;
  const method = request.method;

  if (method === 'OPTIONS') {
    return new Response(null, { headers: { 'Access-Control-Allow-Origin': '*' } });
  }

  // 健康检查
  if (pathname === '/health') {
    return jsonResponse({ status: 'ok', timestamp: new Date().toISOString() });
  }

  // 认证API
  if (pathname === '/api/auth/register' && method === 'POST') return await handleRegister(request, env, db);
  if (pathname === '/api/auth/login' && method === 'POST') return await handleLogin(request, env, db);
  if (pathname === '/api/auth/user-info' && method === 'GET') return await handleGetUserInfo(request, env, db);
  if (pathname === '/api/auth/send-verification-code' && method === 'POST') return await handleSendVerificationCode(request, env, ctx);
  if (pathname === '/api/auth/forgot-password' && method === 'POST') return await handleForgotPassword(request, env, db);
  if (pathname === '/api/auth/reset-password' && method === 'POST') return await handleResetPassword(request, env, db);
  if (pathname === '/api/auth/bind-email' && method === 'POST') return await handleBindEmail(request, env, db);
  
  // 第三方登录
  if (pathname === '/api/auth/wechat/login-url' && method === 'GET') return await handleGetWechatLoginUrl(request, env);
  if (pathname === '/api/auth/alipay/login-url' && method === 'GET') return await handleGetAlipayLoginUrl(request, env);
  if (pathname === '/api/auth/alipay/login' && method === 'POST') return await handleAlipayLogin(request, env);
  if (pathname === '/api/auth/alipay/register' && method === 'POST') return await handleAlipayRegister(request, env);
  if (pathname === '/api/auth/alipay/macos-callback' && method === 'GET') return await handleMacOSAlipayCallback(request, env);

  // 支付API
  if (pathname === '/api/alipay/create-order' && method === 'POST') return await handleCreateAlipayOrder(request, env, db);
  if (pathname === '/api/alipay/query-order' && method === 'GET') return await handleQueryAlipayOrder(request, env, db);
  if (pathname === '/api/alipay/notify' && method === 'POST') return await handleAlipayNotify(request, env, db);
  if (pathname === '/api/alipay/check-membership' && method === 'GET') return await handleCheckAlipayMembership(request, env, db);

  // 会员API
  if (pathname === '/api/stripe/membership-status' && method === 'GET') return await handleCheckMembershipStatus(request, env, db);

  // 兑换码API
  if (pathname === '/api/admin/create-redeem-code' && method === 'POST') return await handleCreateRedeemCode(request, env, db);
  if (pathname === '/api/admin/use-redeem-code' && method === 'POST') return await handleUseRedeemCode(request, env, db);
  if (pathname === '/api/admin/purchase-history' && method === 'GET') return await handleGetPurchaseHistory(request, env, db);
  if (pathname === '/api/admin/redeem-history' && method === 'GET') return await handleGetRedeemHistory(request, env, db);
  if (pathname === '/api/admin/redeem-codes' && method === 'GET') return await handleListRedeemCodes(request, env, db);
  if (pathname === '/api/admin/delete-redeem-code' && method === 'DELETE') return await handleDeleteRedeemCode(request, env, db);
  if (pathname === '/api/admin/check-status' && method === 'GET') return await handleCheckAdminStatus(request, env, db);
  if (pathname === '/api/admin/get-price' && method === 'POST') return await handleGetAdminPrice(request, env, db);

  // 资源API
  if (pathname === '/api/assets/list' && method === 'GET') return await handleGetAssetsList(request, env);
  if (pathname === '/r2' && url.searchParams.has('list')) return await handleR2List(request, env);
  if (pathname === '/r2' && url.searchParams.has('file')) return await handleR2Proxy(request, env);

  // 搜索API
  if (pathname === '/api/search' && method === 'GET') return await handleSearch(request, env, db);
  if (pathname === '/api/search/content' && method === 'GET') return await handleGetTextContent(request, env, db);
  if (pathname === '/api/search/categories' && method === 'GET') return await handleGetCategories(request, env, db);

  // 排行榜API
  if (pathname === '/api/leaderboard' && method === 'GET') return await handleGetLeaderboard(request, env, db);
  if (pathname === '/api/leaderboard/update' && method === 'POST') return await handleUpdateTransferData(request, env, db);

  // 点赞API
  if (pathname === '/api/likes/toggle' && method === 'POST') return await handleToggleLike(request, env, db);
  if (pathname === '/api/likes/count' && method === 'GET') return await handleGetLikeCount(request, env, db);
  if (pathname === '/api/likes/batch-counts' && method === 'POST') return await handleBatchGetLikeCounts(request, env, db);

  // 迁移API（管理员专用）
  if (pathname === '/api/admin/migrate-kv-to-d1' && method === 'POST') return await handleMigrateKvToD1(request, env, db);

  return null;
}
