import { jsonResponse } from '../utils/response.js';

// 搜索文本
export async function handleSearch(request, env) {
  const url = new URL(request.url);
  const query = url.searchParams.get('q') || '';
  const limit = parseInt(url.searchParams.get('limit') || '50');
  
  if (!query) {
    return jsonResponse({ query: '', total: 0, results: [] });
  }

  if (!env.DB) {
    return jsonResponse({ error: '数据库未配置' }, 500);
  }

  const searchQuery = `%${query}%`;
  const { results } = await env.DB.prepare(`
    SELECT id, title, content, file_path as filePath, category 
    FROM text_contents 
    WHERE title LIKE ?1 OR content LIKE ?1 
    LIMIT ?2
  `).bind(searchQuery, limit).all();

  return jsonResponse({
    query,
    total: results.length,
    results: results.map(r => ({
      id: r.id,
      title: r.title,
      path: r.filePath,
      category: r.category,
      preview: r.content.substring(0, 200)
    }))
  });
}

// 索引文本
export async function handleIndexTexts(request, env) {
  if (!env.DB) {
    return jsonResponse({ error: '数据库未配置' }, 500);
  }

  const { texts } = await request.json();
  if (!Array.isArray(texts)) {
    return jsonResponse({ error: '无效的请求数据' }, 400);
  }

  await env.DB.prepare(`
    CREATE TABLE IF NOT EXISTS text_contents (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      title TEXT NOT NULL,
      content TEXT NOT NULL,
      file_path TEXT NOT NULL,
      category TEXT NOT NULL
    )
  `).run();

  let indexed = 0;
  for (const text of texts) {
    await env.DB.prepare(`
      INSERT INTO text_contents (title, content, file_path, category) 
      VALUES (?1, ?2, ?3, ?4)
    `).bind(text.title, text.content, text.filePath, text.category).run();
    indexed++;
  }

  return jsonResponse({ success: true, indexed });
}
