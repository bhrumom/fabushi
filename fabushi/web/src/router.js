import { handleSendSmsCode, handleSmsLogin } from './handlers/sms.js';
import { handleGetComments, handlePostComment, handleDeleteComment, handleGetTaggedPosts, handleGetHotFeed, handleGetPostDetail, handleBatchGetCommentCounts } from './handlers/comments.js';
import { handleCreateAlipayOrder, handleQueryAlipayOrder, handleAlipayNotify } from './handlers/payment.js';
import { handleVerifyAppleReceipt } from './handlers/apple-iap.js';
import { handleCreateRedeemCode } from './handlers/redeem.js';
import { handleMigrateKvToD1 } from './handlers/migration.js';
import { handleCheckAdminStatus, handleListRedeemCodes, handleDeleteRedeemCode, handleGetAdminPrice } from './handlers/admin.js';
import { handleGetAssetsList, handleR2List, handleR2Proxy } from './handlers/assets.js';
import { handleSearch, handleGetTextContent, handleGetCategories } from './handlers/search.js';
import { handleGetLeaderboard, handleGetLeaderboardRecords, handleGetPracticeLeaderboard, handleUpdateTransferData } from './handlers/leaderboard.js';
import { handleToggleLike, handleGetLikeCount, handleBatchGetLikeCounts, handleGetMyLikes, handleGetReceivedLikeCount } from './handlers/likes.js';
import { handleToggleFavorite, handleGetMyFavorites, handleBatchCheckFavorites } from './handlers/favorites.js';
import { handleBatchGetContentStats } from './handlers/content-stats.js';
import { handleOnlineJoin, handleOnlineHeartbeat, handleOnlineLeave, handleOnlineCount } from './handlers/online.js';
import { handleGetSyncData, handlePushSyncData, handleGetSyncState } from './handlers/sync.js';
import { handleToggleFollow, handleGetFollowList, handleGetFollowSummary, handleGetPracticePrivacy, handleUpdatePracticePrivacy } from './handlers/social.js';
import { handleBuiltinMigration, handleFullTextSearch, handleGetCategories as handleBuiltinCategories } from '../migrate-builtin-handler-fixed.js';
import { handleReport, handleBlockUser, handleGetReports, handleReviewReport, handleGetBlocks } from './handlers/moderation.js';
import { handleSubmitFeedback } from './handlers/feedback.js';
import { routeAuthRequest } from './routes/auth-routes.js';
import { routeMembershipRequest } from './routes/membership-routes.js';
import { routeMeditationRequest } from './routes/meditation-routes.js';
import { verifyToken } from '../auth-utils.js';
import { jsonResponse } from './utils/response.js';

function jsonStringifyAscii(value) {
  return JSON.stringify(value).replace(/[\u0080-\uffff]/g, (char) => {
    return `\\u${char.charCodeAt(0).toString(16).padStart(4, '0')}`;
  });
}

function createLegacyMeditationToken(username) {
  const payload = btoa(jsonStringifyAscii({ username }));
  return `legacy.${payload}.signature`;
}

async function normalizeMeditationAuthRequest(request, env, pathname) {
  if (!pathname.startsWith('/api/meditation/')) {
    return { request };
  }

  const authHeader = request.headers.get('Authorization');
  if (!authHeader?.startsWith('Bearer ')) {
    return { request };
  }

  try {
    const tokenData = await verifyToken(authHeader.substring(7), env);
    const username = tokenData?.username || tokenData?.sub;
    if (!username) {
      return {
        response: jsonResponse({ success: false, error: '认证失败，请重新登录' }, 401),
      };
    }

    const headers = new Headers(request.headers);
    headers.set('Authorization', `Bearer ${createLegacyMeditationToken(username)}`);
    return {
      request: new Request(request, { headers }),
    };
  } catch (error) {
    console.warn('修行接口认证预处理失败:', error);
    return {
      response: jsonResponse({ success: false, error: '认证失败，请重新登录' }, 401),
    };
  }
}

export async function route(request, env, db, ctx) {
  const url = new URL(request.url);
  const pathname = url.pathname;
  const method = request.method;

  if (method === 'OPTIONS') {
    return new Response(null, { headers: { 'Access-Control-Allow-Origin': '*' } });
  }

  if (pathname === '/health') {
    return jsonResponse({ status: 'ok', timestamp: new Date().toISOString() });
  }

  const normalizedMeditationAuth = await normalizeMeditationAuthRequest(request, env, pathname);
  if (normalizedMeditationAuth.response) {
    return normalizedMeditationAuth.response;
  }
  request = normalizedMeditationAuth.request;

  const authResponse = await routeAuthRequest({ pathname, method, request, env, db, ctx });
  if (authResponse) {
    return authResponse;
  }

  const membershipResponse = await routeMembershipRequest({ pathname, method, request, env, db, ctx });
  if (membershipResponse) {
    return membershipResponse;
  }

  const meditationResponse = await routeMeditationRequest({ pathname, method, request, env, db, ctx });
  if (meditationResponse) {
    return meditationResponse;
  }

  if (pathname === '/api/sms/send' && method === 'POST') return await handleSendSmsCode(request, env, db);
  if (pathname === '/api/sms/login' && method === 'POST') return await handleSmsLogin(request, env, db);

  if (pathname === '/api/comments' && method === 'GET') return await handleGetComments(request, env, db);
  if (pathname === '/api/comments' && method === 'POST') return await handlePostComment(request, env, db);
  if (pathname === '/api/comments' && method === 'DELETE') return await handleDeleteComment(request, env, db);
  if (pathname === '/api/comments/batch-counts' && method === 'POST') return await handleBatchGetCommentCounts(request, env, db);

  if (pathname === '/api/posts' && method === 'GET') return await handleGetTaggedPosts(request, env, db);
  if (pathname === '/api/posts/detail' && method === 'GET') return await handleGetPostDetail(request, env, db);
  if (pathname === '/api/feed/hot' && method === 'GET') return await handleGetHotFeed(request, env, db);

  if (pathname === '/api/alipay/create-order' && method === 'POST') return await handleCreateAlipayOrder(request, env, db);
  if (pathname === '/api/alipay/query-order' && method === 'GET') return await handleQueryAlipayOrder(request, env, db);
  if (pathname === '/api/alipay/notify' && method === 'POST') return await handleAlipayNotify(request, env, db);
  if (pathname === '/api/apple/verify-receipt' && method === 'POST') return await handleVerifyAppleReceipt(request, env, db);

  if (pathname === '/api/feedback' && method === 'POST') return await handleSubmitFeedback(request, env, db);

  if (pathname === '/api/admin/create-redeem-code' && method === 'POST') return await handleCreateRedeemCode(request, env, db);
  if (pathname === '/api/admin/redeem-codes' && method === 'GET') return await handleListRedeemCodes(request, env, db);
  if (pathname === '/api/admin/delete-redeem-code' && method === 'DELETE') return await handleDeleteRedeemCode(request, env, db);
  if (pathname === '/api/admin/check-status' && method === 'GET') return await handleCheckAdminStatus(request, env, db);
  if (pathname === '/api/admin/get-price' && method === 'POST') return await handleGetAdminPrice(request, env, db);

  if (pathname === '/api/assets/list' && method === 'GET') return await handleGetAssetsList(request, env);
  if (pathname === '/r2' && url.searchParams.has('list')) return await handleR2List(request, env);
  if (pathname === '/r2' && url.searchParams.has('file')) return await handleR2Proxy(request, env);

  if (pathname === '/api/search' && method === 'GET') return await handleSearch(request, env, db);
  if (pathname === '/api/search/content' && method === 'GET') return await handleGetTextContent(request, env, db);
  if (pathname === '/api/search/categories' && method === 'GET') return await handleGetCategories(request, env, db);

  if (pathname === '/api/leaderboard' && method === 'GET') return await handleGetLeaderboard(request, env, db);
  if (pathname === '/api/leaderboard/practice' && method === 'GET') return await handleGetPracticeLeaderboard(request, env, db);
  if (pathname === '/api/leaderboard/practice/records' && method === 'GET') return await handleGetLeaderboardRecords(request, env, db);
  if (pathname === '/api/leaderboard/records' && method === 'GET') return await handleGetLeaderboardRecords(request, env, db);
  if (pathname === '/api/leaderboard/update' && method === 'POST') return await handleUpdateTransferData(request, env, db);

  if (pathname === '/api/social/follow/toggle' && method === 'POST') return await handleToggleFollow(request, env, db);
  if (pathname === '/api/social/follows' && method === 'GET') return await handleGetFollowList(request, env, db);
  if (pathname === '/api/social/follow-summary' && method === 'GET') return await handleGetFollowSummary(request, env, db);
  if (pathname === '/api/social/practice-privacy' && method === 'GET') return await handleGetPracticePrivacy(request, env, db);
  if (pathname === '/api/social/practice-privacy' && method === 'POST') return await handleUpdatePracticePrivacy(request, env, db);

  if (pathname === '/api/likes/toggle' && method === 'POST') return await handleToggleLike(request, env, db);
  if (pathname === '/api/likes/count' && method === 'GET') return await handleGetLikeCount(request, env, db);
  if (pathname === '/api/likes/batch-counts' && method === 'POST') return await handleBatchGetLikeCounts(request, env, db);
  if (pathname === '/api/likes/my-likes' && method === 'GET') return await handleGetMyLikes(request, env, db);
  if (pathname === '/api/likes/received-count' && method === 'GET') return await handleGetReceivedLikeCount(request, env, db);

  if (pathname === '/api/favorites/toggle' && method === 'POST') return await handleToggleFavorite(request, env, db);
  if (pathname === '/api/favorites/my-favorites' && method === 'GET') return await handleGetMyFavorites(request, env, db);
  if (pathname === '/api/favorites/batch-check' && method === 'POST') return await handleBatchCheckFavorites(request, env, db);

  if (pathname === '/api/content/batch-stats' && method === 'POST') return await handleBatchGetContentStats(request, env, db);

  if (pathname === '/api/online/join' && method === 'POST') return await handleOnlineJoin(request, env);
  if (pathname === '/api/online/heartbeat' && method === 'POST') return await handleOnlineHeartbeat(request, env);
  if (pathname === '/api/online/leave' && method === 'POST') return await handleOnlineLeave(request, env);
  if (pathname === '/api/online/count' && method === 'GET') return await handleOnlineCount(request, env);

  if (pathname === '/api/sync' && method === 'GET') return await handleGetSyncData(request, env, db);
  if (pathname === '/api/sync' && method === 'POST') return await handlePushSyncData(request, env, db);
  if (pathname === '/api/sync/state' && method === 'GET') return await handleGetSyncState(request, env, db);

  if (pathname === '/api/admin/migrate-kv-to-d1' && method === 'POST') return await handleMigrateKvToD1(request, env, db);

  if (pathname === '/migrate-builtin-complete' && method === 'POST') return await handleBuiltinMigration(request, env);
  if (pathname === '/api/builtin/search' && method === 'GET') return await handleFullTextSearch(request, env);
  if (pathname === '/api/builtin/categories' && method === 'GET') return await handleBuiltinCategories(request, env);

  if (pathname === '/api/report' && method === 'POST') return await handleReport(request, env, db);
  if (pathname === '/api/block-user' && method === 'POST') return await handleBlockUser(request, env, db);
  if (pathname === '/api/admin/reports' && method === 'GET') return await handleGetReports(request, env, db);
  if (pathname === '/api/admin/reports/review' && method === 'POST') return await handleReviewReport(request, env, db);
  if (pathname === '/api/admin/blocks' && method === 'GET') return await handleGetBlocks(request, env, db);

  return null;
}
