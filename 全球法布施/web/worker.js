// Flutter Web + Backend API Cloudflare Worker
// 为Flutter Web应用提供静态文件服务和完整的后端API

// 导入后端Worker的所有功能
import backendWorker from '../cloudflare-backend/worker.js';

export default {
  async fetch(request, env, ctx) {
    const url = new URL(request.url);
    const path = url.pathname;
    
    // 处理CORS预检请求
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        status: 200,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization, Range',
          'Access-Control-Max-Age': '86400',
        }
      });
    }
    
    // API请求直接转发给后端Worker
    if (path.startsWith('/api/')) {
      return await backendWorker.fetch(request, env, ctx);
    }
    
    // R2代理请求转发给后端Worker
    if (path === '/r2') {
      return await backendWorker.fetch(request, env, ctx);
    }
    
    // 静态文件服务 - 服务Flutter Web构建的文件
    return await serveFlutterWeb(request, env);
  }
};

// 服务Flutter Web静态文件
async function serveFlutterWeb(request, env) {
  const url = new URL(request.url);
  let pathname = url.pathname;
  
  // 根路径重定向到index.html
  if (pathname === '/') {
    pathname = '/index.html';
  }
  
  // 尝试从ASSETS绑定获取文件
  try {
    const assetRequest = new Request(new URL(pathname, request.url), request);
    const response = await env.ASSETS.fetch(assetRequest);
    
    if (response.status === 404) {
      // 对于Flutter Web的路由，返回index.html（SPA路由）
      const indexRequest = new Request(new URL('/index.html', request.url), request);
      const indexResponse = await env.ASSETS.fetch(indexRequest);
      
      if (indexResponse.ok) {
        // 添加CORS头部
        const newResponse = new Response(indexResponse.body, {
          status: 200,
          statusText: 'OK',
          headers: indexResponse.headers
        });
        
        newResponse.headers.set('Access-Control-Allow-Origin', '*');
        newResponse.headers.set('Content-Type', 'text/html; charset=utf-8');
        
        return newResponse;
      }
    }
    
    // 为所有响应添加CORS头部
    const newResponse = new Response(response.body, {
      status: response.status,
      statusText: response.statusText,
      headers: response.headers
    });
    
    newResponse.headers.set('Access-Control-Allow-Origin', '*');
    
    return newResponse;
    
  } catch (error) {
    console.error('Error serving Flutter Web asset:', error);
    return new Response('Internal Server Error', { 
      status: 500,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'text/plain'
      }
    });
  }
}