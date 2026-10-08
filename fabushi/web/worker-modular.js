// 模块化 Worker 入口
import { DatabaseService } from './src/services/database.js';
import { route } from './src/router.js';
import { OnlineCounter } from './src/durable-objects/OnlineCounter.js';
import { jsonResponse } from './src/utils/response.js';
import { enforceRequestSecurityGate } from './src/security/request-gate.js';
import { configureRuntimeAdminEmails } from './src/utils/helpers.js';
import { activateDueDirectMessages } from './src/handlers/friends.js';

export { OnlineCounter };

export default {
  async scheduled(controller, env, ctx) {
    const db = new DatabaseService(env.DB);
    const run = activateDueDirectMessages(db, controller?.scheduledTime || Date.now())
      .then((delivered) => {
        if (delivered > 0) console.log('Activated due direct messages:', delivered);
      })
      .catch((error) => {
        console.error('Direct message scheduler failed:', error?.message || error);
        throw error;
      });
    ctx.waitUntil(run);
  },

  async fetch(request, env, ctx) {
    try {
      const url = new URL(request.url);
      configureRuntimeAdminEmails(env);

      if (url.pathname === '/api/online/ws') {
        const upgradeHeader = request.headers.get('Upgrade');
        const activityType = url.searchParams.get('activityType');
        if (upgradeHeader && upgradeHeader.toLowerCase() === 'websocket') {
          if (!activityType || !['global_sending', 'zen_room'].includes(activityType)) {
            return new Response('Invalid activityType', { status: 400 });
          }
          try {
            const id = env.ONLINE_COUNTER.idFromName(activityType);
            const stub = env.ONLINE_COUNTER.get(id);
            return await stub.fetch(request);
          } catch (error) {
            console.error('Online counter forwarding failed:', error?.message || error);
            return new Response('WebSocket upgrade failed', { status: 500 });
          }
        }
      }

      const db = new DatabaseService(env.DB);
      const denied = await enforceRequestSecurityGate(request, env, db);
      if (denied) return denied;

      const response = await route(request, env, db, ctx);
      if (response) return response;

      return jsonResponse({
        success: false,
        error: 'Not Found',
        message: 'This Cloudflare Worker is an API backend only.',
        path: url.pathname
      }, 404);
    } catch (error) {
      console.error('Worker error:', error?.message || error);
      return jsonResponse({ success: false, error: 'Internal Server Error' }, 500);
    }
  }
};
