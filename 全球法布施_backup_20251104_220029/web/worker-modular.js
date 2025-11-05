// 模块化Worker入口
import { DatabaseService } from './src/services/database.js';
import { route } from './src/router.js';

export default {
  async fetch(request, env, ctx) {
    try {
      // 初始化数据库服务
      const db = new DatabaseService(env.DB);
      
      // 尝试路由到模块化处理器
      const response = await route(request, env, db);
      if (response) return response;

      // 未匹配的路由，回退到原worker.js处理
      // 这里可以导入原worker.js的其他功能
      return new Response('Not Found', { status: 404 });
      
    } catch (error) {
      console.error('Worker error:', error);
      return new Response('Internal Server Error', { 
        status: 500,
        headers: { 'Access-Control-Allow-Origin': '*' }
      });
    }
  }
};
