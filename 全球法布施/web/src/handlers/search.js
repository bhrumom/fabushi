import { jsonResponse } from '../utils/response.js';

// 获取所有txt文件列表（包括乾隆大藏经）
async function getTextFiles(env) {
  // 使用预定义的文件列表（从dharma_assets.dart生成）
  const files = [
    // 经文
    { path: 'assets/built_in/经文/般若波罗蜜多心经.txt', category: '经文' },
    { path: 'assets/built_in/经文/妙法莲华经精选.txt', category: '经文' },
    { path: 'assets/built_in/经文/智慧法语.txt', category: '经文' },
    { path: 'assets/built_in/经文/阿弥陀佛圣号.txt', category: '经文' },
    // 咒语
    { path: 'assets/built_in/咒语/772陀罗尼梵音(hum版).txt', category: '咒语' },
    { path: 'assets/built_in/咒语/慈悲咒语.txt', category: '咒语' },
    { path: 'assets/built_in/咒语/和平祈愿.txt', category: '咒语' },
  ];
  
  // 如果需要搜索乾隆大藏经，需要从manifest读取文件列表
  // 这里先返回基础文件列表
  return files;
}

// 从R2或静态资源获取文件列表
async function getAllTextFilesFromManifest(env) {
  try {
    // 尝试读取asset-manifest.json
    const manifestUrl = new URL('/assets/data/asset-manifest.json', 'https://dummy.local');
    const manifestResponse = await env.ASSETS.fetch(manifestUrl.toString());
    
    if (manifestResponse.ok) {
      const manifest = await manifestResponse.json();
      const txtFiles = [];
      
      // manifest是数组格式
      for (const item of manifest) {
        const path = item.key;
        if (path && path.endsWith('.txt')) {
          let category = '经文';
          if (path.includes('咒语')) category = '咒语';
          else if (path.includes('乾隆大藏经')) category = '乾隆大藏经';
          
          txtFiles.push({ path, category });
        }
      }
      
      console.log(`Found ${txtFiles.length} text files in manifest`);
      return txtFiles;
    }
  } catch (e) {
    console.error('Error reading manifest:', e);
  }
  
  // 如果读取manifest失败，返回基础列表
  return getTextFiles(env);
}

// 读取文件内容
async function readTextFile(env, path) {
  try {
    // 确保路径以 / 开头
    const normalizedPath = path.startsWith('/') ? path : `/${path}`;
    const fileUrl = new URL(normalizedPath, 'https://dummy.local');
    const response = await env.ASSETS.fetch(fileUrl.toString());
    if (response.ok) {
      return await response.text();
    }
    console.log(`File not found: ${normalizedPath}, status: ${response.status}`);
  } catch (e) {
    console.error(`Error reading ${path}:`, e);
  }
  return null;
}

// 搜索文本
export async function handleSearch(request, env) {
  try {
    console.log('Search handler called');
    console.log('env.ASSETS:', !!env?.ASSETS);
    
    if (!env || !env.ASSETS) {
      console.error('ASSETS not available');
      return jsonResponse({ error: 'ASSETS not available', query: '', total: 0, results: [] }, 500);
    }

    const url = new URL(request.url);
    const query = url.searchParams.get('q') || '';
    const includeAll = url.searchParams.get('all') === 'true';
    
    console.log('Search query:', query, 'includeAll:', includeAll);
    
    if (!query) {
      return jsonResponse({ query: '', total: 0, results: [] });
    }

    const files = includeAll ? await getAllTextFilesFromManifest(env) : await getTextFiles(env);
  const results = [];
  const queryLower = query.toLowerCase();

  for (const file of files) {
    const content = await readTextFile(env, file.path);
    if (!content) continue;

    const title = file.path.split('/').pop().replace('.txt', '');
    const titleLower = title.toLowerCase();
    const contentLower = content.toLowerCase();

    // 检查标题或内容是否匹配
    if (titleLower.includes(queryLower) || contentLower.includes(queryLower)) {
      // 生成预览
      let preview = content;
      const index = contentLower.indexOf(queryLower);
      
      if (index !== -1) {
        const start = Math.max(0, index - 50);
        const end = Math.min(content.length, index + query.length + 150);
        preview = (start > 0 ? '...' : '') + 
                  content.substring(start, end) + 
                  (end < content.length ? '...' : '');
      } else {
        preview = content.substring(0, 200);
      }

      results.push({
        id: file.path,
        title,
        path: file.path,
        category: file.category,
        preview,
        contentLength: content.length,
        titleMatch: titleLower.includes(queryLower)
      });
    }
  }

  // 标题匹配优先排序
  results.sort((a, b) => {
    if (a.titleMatch && !b.titleMatch) return -1;
    if (!a.titleMatch && b.titleMatch) return 1;
    return 0;
  });

    return jsonResponse({
      query,
      total: results.length,
      results
    });
  } catch (error) {
    console.error('Search error:', error);
    console.error('Error stack:', error.stack);
    return jsonResponse({ 
      error: error.message, 
      stack: error.stack,
      query: query || '', 
      total: 0, 
      results: [] 
    }, 500);
  }
}

// 获取经文内容
export async function handleGetTextContent(request, env) {
  const url = new URL(request.url);
  const path = url.searchParams.get('path');
  
  if (!path) {
    return jsonResponse({ error: '缺少path参数' }, 400);
  }

  const content = await readTextFile(env, path);
  if (!content) {
    return jsonResponse({ error: '未找到内容' }, 404);
  }

  const title = path.split('/').pop().replace('.txt', '');
  const category = path.includes('经文') ? '经文' : '咒语';

  return jsonResponse({
    title,
    content,
    path,
    category
  });
}
