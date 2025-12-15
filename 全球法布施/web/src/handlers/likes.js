import { jsonResponse } from '../utils/response.js';
import { verifyToken } from '../../auth-utils.js';

export async function handleToggleLike(request, env, db) {
    try {
        const authHeader = request.headers.get('Authorization');
        const token = authHeader?.replace('Bearer ', '');

        // 验证 token 获取用户信息
        let userId = null;
        if (token) {
            const decoded = await verifyToken(token, env);
            userId = decoded?.username || null;
        }

        const { contentId, contentType, action, title, filePath } = await request.json();

        if (!contentId || !contentType) {
            return jsonResponse({ error: '缺少必要参数' }, 400);
        }

        if (action === 'like') {
            // 点赞时保存内容元数据（标题和文件路径）
            await db.prepare(
                'INSERT OR IGNORE INTO content_likes (content_id, content_type, user_id, title, file_path, created_at) VALUES (?, ?, ?, ?, ?, ?)'
            ).bind(contentId, contentType, userId, title || null, filePath || null, new Date().toISOString()).run();
        } else if (action === 'unlike') {
            if (userId) {
                await db.prepare('DELETE FROM content_likes WHERE content_id = ? AND user_id = ?')
                    .bind(contentId, userId).run();
            } else {
                await db.prepare('DELETE FROM content_likes WHERE content_id = ? AND user_id IS NULL')
                    .bind(contentId).run();
            }
        }

        const result = await db.prepare(
            'SELECT COUNT(*) as count FROM content_likes WHERE content_id = ?'
        ).bind(contentId).first();

        return jsonResponse({ success: true, likeCount: result.count });
    } catch (error) {
        console.error('Toggle like error:', error);
        return jsonResponse({ error: '操作失败' }, 500);
    }
}

export async function handleGetLikeCount(request, env, db) {
    try {
        const url = new URL(request.url);
        const contentId = url.searchParams.get('contentId');

        if (!contentId) {
            return jsonResponse({ error: '缺少contentId参数' }, 400);
        }

        const result = await db.prepare(
            'SELECT COUNT(*) as count FROM content_likes WHERE content_id = ?'
        ).bind(contentId).first();

        return jsonResponse({ likeCount: result.count || 0 });
    } catch (error) {
        console.error('Get like count error:', error);
        return jsonResponse({ error: '获取失败' }, 500);
    }
}

export async function handleBatchGetLikeCounts(request, env, db) {
    try {
        const { contentIds } = await request.json();

        if (!contentIds || !Array.isArray(contentIds)) {
            return jsonResponse({ error: '缺少contentIds参数' }, 400);
        }

        const placeholders = contentIds.map(() => '?').join(',');
        const results = await db.prepare(
            `SELECT content_id, COUNT(*) as count FROM content_likes WHERE content_id IN (${placeholders}) GROUP BY content_id`
        ).bind(...contentIds).all();

        const likeCounts = {};
        results.results.forEach(row => {
            likeCounts[row.content_id] = row.count;
        });

        return jsonResponse({ likeCounts });
    } catch (error) {
        console.error('Batch get like counts error:', error);
        return jsonResponse({ error: '获取失败' }, 500);
    }
}

export async function handleGetMyLikes(request, env, db) {
    try {
        const authHeader = request.headers.get('Authorization');
        const token = authHeader?.replace('Bearer ', '');

        if (!token) {
            return jsonResponse({ error: '未登录' }, 401);
        }

        const decoded = await verifyToken(token, env);
        if (!decoded?.username) {
            return jsonResponse({ error: '无效的token' }, 401);
        }

        const results = await db.prepare(
            'SELECT content_id as id, content_type as contentType, title, file_path as filePath, created_at as likedAt FROM content_likes WHERE user_id = ? ORDER BY created_at DESC'
        ).bind(decoded.username).all();

        return jsonResponse({ success: true, likes: results.results });
    } catch (error) {
        console.error('Get my likes error:', error);
        return jsonResponse({ error: '获取失败' }, 500);
    }
}
