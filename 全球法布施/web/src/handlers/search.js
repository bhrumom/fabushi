import { jsonResponse } from '../utils/response.js';

// 使用D1数据库搜索文本
export async function handleSearch(request, env, db) {
  try {
    const url = new URL(request.url);
    const query = url.searchParams.get('q') || '';
    const category = url.searchParams.get('category'); // 可选：按分类筛选
    const limit = parseInt(url.searchParams.get('limit') || '50');
    const offset = parseInt(url.searchParams.get('offset') || '0');

    if (!query) {
      return jsonResponse({ query: '', total: 0, results: [] });
    }

    // 构建SQL查询
    const searchPattern = `%${query}%`;
    let sql = `
      SELECT id, title, content, file_path, category,
             CASE 
               WHEN title LIKE ? THEN 1
               ELSE 0
             END as title_match
      FROM text_contents
      WHERE title LIKE ? OR content LIKE ?
    `;

    const params = [searchPattern, searchPattern, searchPattern];

    // 添加分类筛选
    if (category) {
      sql += ' AND category = ?';
      params.push(category);
    }

    // 排序：标题匹配优先
    sql += ' ORDER BY title_match DESC, id ASC';

    // 分页
    sql += ' LIMIT ? OFFSET ?';
    params.push(limit, offset);

    const { results } = await db.prepare(sql).bind(...params).all();

    // 生成预览
    const formattedResults = results.map(row => {
      const queryLower = query.toLowerCase();
      const contentLower = row.content.toLowerCase();
      const index = contentLower.indexOf(queryLower);

      let preview = row.content;
      if (index !== -1) {
        const start = Math.max(0, index - 50);
        const end = Math.min(row.content.length, index + query.length + 150);
        preview = (start > 0 ? '...' : '') +
          row.content.substring(start, end) +
          (end < row.content.length ? '...' : '');
      } else {
        preview = row.content.substring(0, 200);
      }

      return {
        id: row.file_path,
        title: row.title,
        path: row.file_path,
        category: row.category,
        preview,
        contentLength: row.content.length,
        titleMatch: row.title_match === 1
      };
    });

    // 获取总数
    let countSql = 'SELECT COUNT(*) as total FROM text_contents WHERE title LIKE ? OR content LIKE ?';
    const countParams = [searchPattern, searchPattern];
    if (category) {
      countSql += ' AND category = ?';
      countParams.push(category);
    }
    const { total } = await db.prepare(countSql).bind(...countParams).first();

    return jsonResponse({
      query,
      category: category || 'all',
      total: total || 0,
      limit,
      offset,
      results: formattedResults
    });
  } catch (error) {
    console.error('Search error:', error);
    return jsonResponse({
      error: error.message,
      query: query || '',
      total: 0,
      results: []
    }, 500);
  }
}

// 获取经文内容（从D1）
export async function handleGetTextContent(request, env, db) {
  try {
    const url = new URL(request.url);
    const path = url.searchParams.get('path');

    if (!path) {
      return jsonResponse({ error: '缺少path参数' }, 400);
    }

    const result = await db
      .prepare('SELECT title, content, file_path, category FROM text_contents WHERE file_path = ?')
      .bind(path)
      .first();

    if (!result) {
      return jsonResponse({ error: '未找到内容' }, 404);
    }

    return jsonResponse({
      title: result.title,
      content: result.content,
      path: result.file_path,
      category: result.category
    });
  } catch (error) {
    console.error('Get text content error:', error);
    return jsonResponse({ error: error.message }, 500);
  }
}

// 获取所有分类
export async function handleGetCategories(request, env, db) {
  try {
    const { results } = await db
      .prepare('SELECT DISTINCT category, COUNT(*) as count FROM text_contents GROUP BY category')
      .all();

    return jsonResponse({
      categories: results.map(r => ({
        name: r.category,
        count: r.count
      }))
    });
  } catch (error) {
    console.error('Get categories error:', error);
    return jsonResponse({ error: error.message }, 500);
  }
}
