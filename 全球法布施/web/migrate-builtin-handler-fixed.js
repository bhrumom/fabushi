/**
 * 内置内容迁移到D1数据库处理器 - 修复版本
 * 支持全文搜索和批量插入，自动创建表结构
 */

// 创建表的SQL语句
const CREATE_TABLES_SQL = `
-- 创建texts表存储文本内容
CREATE TABLE IF NOT EXISTS texts (
    id TEXT PRIMARY KEY,
    title TEXT NOT NULL,
    content TEXT NOT NULL,
    file_path TEXT NOT NULL,
    category TEXT NOT NULL,
    file_name TEXT NOT NULL,
    word_count INTEGER DEFAULT 0,
    source TEXT DEFAULT 'builtin',
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- 创建FTS5虚拟表用于全文搜索
CREATE VIRTUAL TABLE IF NOT EXISTS texts_fts USING fts5(
    title,
    content,
    category,
    content='texts',
    content_rowid='rowid'
);

-- 创建索引优化查询性能
CREATE INDEX IF NOT EXISTS idx_texts_category ON texts(category);
CREATE INDEX IF NOT EXISTS idx_texts_source ON texts(source);
CREATE INDEX IF NOT EXISTS idx_texts_created_at ON texts(created_at);
CREATE INDEX IF NOT EXISTS idx_texts_word_count ON texts(word_count);
`;

async function ensureTablesExist(env) {
    try {
        // 分别执行每个CREATE语句
        const statements = CREATE_TABLES_SQL.split(';').filter(s => s.trim());

        for (const statement of statements) {
            if (statement.trim()) {
                await env.DB.prepare(statement.trim()).run();
            }
        }

        console.log('✅ 数据库表结构检查完成');
        return true;
    } catch (error) {
        console.error('❌ 创建表失败:', error);
        return false;
    }
}

export async function handleBuiltinMigration(request, env) {
    try {
        // 首先确保表存在
        const tablesReady = await ensureTablesExist(env);
        if (!tablesReady) {
            return new Response(JSON.stringify({
                success: false,
                error: "Failed to create database tables"
            }), {
                status: 500,
                headers: { 'Content-Type': 'application/json' }
            });
        }

        const { texts } = await request.json();

        if (!texts || !Array.isArray(texts)) {
            return new Response(JSON.stringify({
                success: false,
                error: "Invalid texts data"
            }), {
                status: 400,
                headers: { 'Content-Type': 'application/json' }
            });
        }

        console.log(`📥 接收到 ${texts.length} 个文本进行迁移`);

        let successful = 0;
        let failed = 0;

        // 逐个处理文本以避免批量操作问题
        for (const text of texts) {
            try {
                const {
                    id,
                    title,
                    content,
                    filePath,
                    category,
                    fileName,
                    wordCount,
                    source = 'builtin'
                } = text;

                // 插入到texts表
                await env.DB.prepare(`
                    INSERT OR REPLACE INTO texts (
                        id, title, content, file_path, category, 
                        file_name, word_count, source, created_at, updated_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'))
                `).bind(id, title, content, filePath, category, fileName, wordCount, source).run();

                successful++;
                console.log(`✅ 插入成功: ${title}`);

            } catch (error) {
                failed++;
                console.error(`❌ 插入失败: ${text.title}`, error);
            }
        }

        console.log(`📊 迁移完成 - 成功: ${successful}, 失败: ${failed}`);

        return new Response(JSON.stringify({
            success: true,
            message: `Successfully migrated ${successful} texts`,
            stats: {
                total: texts.length,
                successful,
                failed
            }
        }), {
            status: 200,
            headers: { 'Content-Type': 'application/json' }
        });

    } catch (error) {
        console.error('❌ 迁移失败:', error);

        return new Response(JSON.stringify({
            success: false,
            error: error.message
        }), {
            status: 500,
            headers: { 'Content-Type': 'application/json' }
        });
    }
}

/**
 * 全文搜索处理器
 */
export async function handleFullTextSearch(request, env) {
    try {
        const url = new URL(request.url);
        const query = url.searchParams.get('q');
        const category = url.searchParams.get('category');
        const limit = parseInt(url.searchParams.get('limit') || '20');
        const offset = parseInt(url.searchParams.get('offset') || '0');

        if (!query || query.trim().length === 0) {
            return new Response(JSON.stringify({
                success: false,
                error: "Search query is required"
            }), {
                status: 400,
                headers: {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
                }
            });
        }

        console.log(`🔍 全文搜索: "${query}" 分类: ${category || '全部'}`);

        // 使用 FTS5 进行极端性能搜索，添加通配符支持
        const ftsQuery = query.split('').filter(c => c.trim()).join(' ') + '*';
        console.log(`🔎 转换 FTS 查询: "${ftsQuery}"`);

        let searchQuery = `
            SELECT 
                f.id, f.title, f.category, f.file_path, f.word_count,
                snippet(texts_fts, 1, '<b>', '</b>', '...', 64) as snippet
            FROM texts_fts f
            WHERE texts_fts MATCH ?
        `;

        let params = [ftsQuery];

        if (category && category !== 'all') {
            searchQuery += ` AND category = ?`;
            params.push(category);
        }

        searchQuery += ` ORDER BY rank LIMIT ? OFFSET ?`;
        params.push(limit, offset);

        // 执行搜索
        let searchResults = await env.DB.prepare(searchQuery)
            .bind(...params)
            .all();

        // 如果 FTS5 没有结果，回退到普通的 LIKE 搜索以支持更模糊的匹配
        if (!searchResults.results || searchResults.results.length === 0) {
            console.log('⚠️ FTS5 无结果，回退到 LIKE 搜索');
            let likeQuery = `
                SELECT 
                    id, title, category, file_path, word_count,
                    SUBSTR(content, 1, 100) as snippet
                FROM texts
                WHERE (title LIKE ? OR content LIKE ?)
            `;
            let likeParams = [`%${query}%`, `%${query}%`];

            if (category && category !== 'all') {
                likeQuery += ` AND category = ?`;
                likeParams.push(category);
            }

            likeQuery += ` ORDER BY title LIKE ? DESC, word_count DESC LIMIT ? OFFSET ?`;
            likeParams.push(`%${query}%`, limit, offset);

            searchResults = await env.DB.prepare(likeQuery)
                .bind(...likeParams)
                .all();
        }

        // 获取总数
        let total = 0;
        try {
            let countQuery = `SELECT COUNT(*) as total FROM texts_fts WHERE texts_fts MATCH ?`;
            let countParams = [ftsQuery];
            if (category && category !== 'all') {
                countQuery += ` AND category = ?`;
                countParams.push(category);
            }

            const countResult = await env.DB.prepare(countQuery)
                .bind(...countParams)
                .first();

            total = countResult?.total || 0;

            // 如果 FTS 总数为 0，尝试获取 LIKE 的总数
            if (total === 0) {
                let likeCountQuery = `SELECT COUNT(*) as total FROM texts WHERE (title LIKE ? OR content LIKE ?)`;
                let likeCountParams = [`%${query}%`, `%${query}%`];
                if (category && category !== 'all') {
                    likeCountQuery += ` AND category = ?`;
                    likeCountParams.push(category);
                }
                const likeCountResult = await env.DB.prepare(likeCountQuery)
                    .bind(...likeCountParams)
                    .first();
                total = likeCountResult?.total || 0;
            }
        } catch (e) {
            console.error('获取总数失败:', e);
        }

        console.log(`📊 FTS5 搜索结果: ${searchResults.results?.length || 0} 条，总计: ${total} 条`);

        return new Response(JSON.stringify({
            success: true,
            data: {
                results: (searchResults.results || []).map(r => ({
                    ...r,
                    content: r.snippet // 用高亮片段作为预览内容
                })),
                pagination: {
                    total,
                    limit,
                    offset,
                    hasMore: offset + limit < total
                },
                query,
                category
            }
        }), {
            status: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            }
        });

    } catch (error) {
        console.error('❌ 搜索失败:', error);

        return new Response(JSON.stringify({
            success: false,
            error: error.message
        }), {
            status: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            }
        });
    }
}

/**
 * 获取分类列表
 */
export async function handleGetCategories(request, env) {
    try {
        const categoriesResult = await env.DB.prepare(`
            SELECT category, COUNT(*) as count
            FROM texts
            WHERE source = 'builtin'
            GROUP BY category
            ORDER BY count DESC
        `).all();

        return new Response(JSON.stringify({
            success: true,
            data: categoriesResult.results || []
        }), {
            status: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
                'Access-Control-Allow-Headers': 'Content-Type, Authorization'
            }
        });

    } catch (error) {
        console.error('❌ 获取分类失败:', error);

        return new Response(JSON.stringify({
            success: false,
            error: error.message
        }), {
            status: 500,
            headers: { 'Content-Type': 'application/json' }
        });
    }
}