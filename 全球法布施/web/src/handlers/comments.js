import { jsonResponse } from '../utils/response.js';
import { verifyToken } from '../../auth-utils.js';

// 获取评论列表
export async function handleGetComments(request, env, db) {
    try {
        const url = new URL(request.url);
        const videoId = url.searchParams.get('videoId');
        const page = parseInt(url.searchParams.get('page') || '1');
        const pageSize = parseInt(url.searchParams.get('pageSize') || '20');
        const offset = (page - 1) * pageSize;

        if (!videoId) {
            return jsonResponse({ error: '视频ID不能为空' }, 400);
        }

        // 获取评论列表，包含用户信息
        // 使用LEFT JOIN关联users表获取头像和昵称
        const comments = await db.db.prepare(`
      SELECT 
        c.id, c.video_id, c.user_id, c.content, c.created_at, c.parent_id, c.like_count, c.tag,
        u.username, u.nickname, u.avatar
      FROM comments c
      LEFT JOIN users u ON c.user_id = u.username
      WHERE c.video_id = ?
      ORDER BY c.created_at DESC
      LIMIT ? OFFSET ?
    `).bind(videoId, pageSize, offset).all();

        // 获取总评论数
        const totalResult = await db.db.prepare(`
      SELECT COUNT(*) as count FROM comments WHERE video_id = ?
    `).bind(videoId).first();

        return jsonResponse({
            comments: comments.results,
            total: totalResult.count,
            page,
            pageSize
        });
    } catch (error) {
        console.error('获取评论失败:', error);
        return jsonResponse({ error: '获取评论失败' }, 500);
    }
}

// 发布评论
export async function handlePostComment(request, env, db) {
    try {
        const authHeader = request.headers.get('Authorization');
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return jsonResponse({ error: '未提供认证信息' }, 401);
        }

        const token = authHeader.substring(7);
        const tokenData = await verifyToken(token, env);
        if (!tokenData) {
            return jsonResponse({ error: '认证失败' }, 401);
        }

        const { videoId, content, parentId, tag } = await request.json();

        if (!videoId || !content) {
            return jsonResponse({ error: '视频ID和内容不能为空' }, 400);
        }

        // 验证标签值
        const validTags = ['ganying', 'fayuan', null];
        if (tag && !validTags.includes(tag)) {
            return jsonResponse({ error: '无效的标签类型' }, 400);
        }

        const now = new Date().toISOString();

        // 插入评论（包含标签）
        const result = await db.db.prepare(`
      INSERT INTO comments (video_id, user_id, content, created_at, parent_id, tag)
      VALUES (?, ?, ?, ?, ?, ?)
    `).bind(videoId, tokenData.username, content, now, parentId || null, tag || null).run();

        // 获取新插入的评论详情（包含用户信息和标签）
        const newComment = await db.db.prepare(`
      SELECT 
        c.id, c.video_id, c.user_id, c.content, c.created_at, c.parent_id, c.like_count, c.tag,
        u.username, u.nickname, u.avatar
      FROM comments c
      LEFT JOIN users u ON c.user_id = u.username
      WHERE c.id = ?
    `).bind(result.meta.last_row_id).first();

        return jsonResponse({
            message: '评论发布成功',
            comment: newComment
        }, 201);
    } catch (error) {
        console.error('发布评论失败:', error);
        return jsonResponse({ error: '发布评论失败: ' + error.message }, 500);
    }
}

// 删除评论
export async function handleDeleteComment(request, env, db) {
    try {
        const authHeader = request.headers.get('Authorization');
        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return jsonResponse({ error: '未提供认证信息' }, 401);
        }

        const token = authHeader.substring(7);
        const tokenData = await verifyToken(token, env);
        if (!tokenData) {
            return jsonResponse({ error: '认证失败' }, 401);
        }

        const url = new URL(request.url);
        const commentId = url.searchParams.get('id');

        if (!commentId) {
            return jsonResponse({ error: '评论ID不能为空' }, 400);
        }

        // 检查评论是否存在以及是否属于当前用户
        const comment = await db.db.prepare(`
      SELECT user_id FROM comments WHERE id = ?
    `).bind(commentId).first();

        if (!comment) {
            return jsonResponse({ error: '评论不存在' }, 404);
        }

        // 只有作者可以删除评论 (后续可添加管理员权限)
        if (comment.user_id !== tokenData.username) {
            return jsonResponse({ error: '无权删除此评论' }, 403);
        }

        await db.db.prepare(`
      DELETE FROM comments WHERE id = ?
    `).bind(commentId).run();

        return jsonResponse({ message: '评论已删除' });
    } catch (error) {
        console.error('删除评论失败:', error);
        return jsonResponse({ error: '删除评论失败' }, 500);
    }
}

// 获取带标签的帖子列表（感应/发愿）
export async function handleGetTaggedPosts(request, env, db) {
    try {
        const url = new URL(request.url);
        const tag = url.searchParams.get('tag');
        const page = parseInt(url.searchParams.get('page') || '1');
        const pageSize = parseInt(url.searchParams.get('pageSize') || '20');
        const offset = (page - 1) * pageSize;

        if (!tag || !['ganying', 'fayuan'].includes(tag)) {
            return jsonResponse({ error: '标签类型无效，必须是 ganying 或 fayuan' }, 400);
        }

        // 获取带标签的帖子，包含用户信息和点赞数
        const posts = await db.db.prepare(`
      SELECT 
        c.id, c.video_id, c.user_id, c.content, c.created_at, c.tag, c.like_count,
        u.username, u.nickname, u.avatar
      FROM comments c
      LEFT JOIN users u ON c.user_id = u.username
      WHERE c.tag = ?
      ORDER BY c.created_at DESC
      LIMIT ? OFFSET ?
    `).bind(tag, pageSize, offset).all();

        // 获取总数
        const totalResult = await db.db.prepare(`
      SELECT COUNT(*) as count FROM comments WHERE tag = ?
    `).bind(tag).first();

        return jsonResponse({
            posts: posts.results,
            total: totalResult.count,
            page,
            pageSize
        });
    } catch (error) {
        console.error('获取帖子列表失败:', error);
        return jsonResponse({ error: '获取帖子列表失败' }, 500);
    }
}

// 获取热门内容（按点赞数排序）
export async function handleGetHotFeed(request, env, db) {
    try {
        const url = new URL(request.url);
        const page = parseInt(url.searchParams.get('page') || '1');
        const pageSize = parseInt(url.searchParams.get('pageSize') || '20');
        const offset = (page - 1) * pageSize;

        // 获取点赞数最高的内容
        // 这里从 likes 表统计各内容的点赞数
        const hotContent = await db.db.prepare(`
      SELECT 
        content_id as id,
        content_type,
        COUNT(*) as like_count
      FROM likes
      GROUP BY content_id
      ORDER BY like_count DESC
      LIMIT ? OFFSET ?
    `).bind(pageSize, offset).all();

        // 获取总数
        const totalResult = await db.db.prepare(`
      SELECT COUNT(DISTINCT content_id) as count FROM likes
    `).first();

        return jsonResponse({
            hotContent: hotContent.results,
            total: totalResult.count,
            page,
            pageSize
        });
    } catch (error) {
        console.error('获取热门内容失败:', error);
        return jsonResponse({ error: '获取热门内容失败' }, 500);
    }
}

// 获取帖子详情（包含原视频信息）
export async function handleGetPostDetail(request, env, db) {
    try {
        const url = new URL(request.url);
        const postId = url.searchParams.get('id');

        if (!postId) {
            return jsonResponse({ error: '帖子ID不能为空' }, 400);
        }

        // 获取帖子详情
        const post = await db.db.prepare(`
      SELECT 
        c.id, c.video_id, c.user_id, c.content, c.created_at, c.tag, c.like_count,
        u.username, u.nickname, u.avatar
      FROM comments c
      LEFT JOIN users u ON c.user_id = u.username
      WHERE c.id = ? AND c.tag IS NOT NULL
    `).bind(postId).first();

        if (!post) {
            return jsonResponse({ error: '帖子不存在' }, 404);
        }

        return jsonResponse({ post });
    } catch (error) {
        console.error('获取帖子详情失败:', error);
        return jsonResponse({ error: '获取帖子详情失败' }, 500);
    }
}
