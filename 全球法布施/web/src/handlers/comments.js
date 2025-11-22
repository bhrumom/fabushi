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
        const comments = await db.prepare(`
      SELECT 
        c.id, c.video_id, c.user_id, c.content, c.created_at, c.parent_id, c.like_count,
        u.username, u.nickname, u.avatar
      FROM comments c
      LEFT JOIN users u ON c.user_id = u.username
      WHERE c.video_id = ?
      ORDER BY c.created_at DESC
      LIMIT ? OFFSET ?
    `).bind(videoId, pageSize, offset).all();

        // 获取总评论数
        const totalResult = await db.prepare(`
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

        const { videoId, content, parentId } = await request.json();

        if (!videoId || !content) {
            return jsonResponse({ error: '视频ID和内容不能为空' }, 400);
        }

        const now = new Date().toISOString();

        // 插入评论
        const result = await db.prepare(`
      INSERT INTO comments (video_id, user_id, content, created_at, parent_id)
      VALUES (?, ?, ?, ?, ?)
    `).bind(videoId, tokenData.username, content, now, parentId || null).run();

        // 获取新插入的评论详情（包含用户信息）
        const newComment = await db.prepare(`
      SELECT 
        c.id, c.video_id, c.user_id, c.content, c.created_at, c.parent_id, c.like_count,
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
        return jsonResponse({ error: '发布评论失败' }, 500);
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
        const comment = await db.prepare(`
      SELECT user_id FROM comments WHERE id = ?
    `).bind(commentId).first();

        if (!comment) {
            return jsonResponse({ error: '评论不存在' }, 404);
        }

        // 只有作者可以删除评论 (后续可添加管理员权限)
        if (comment.user_id !== tokenData.username) {
            return jsonResponse({ error: '无权删除此评论' }, 403);
        }

        await db.prepare(`
      DELETE FROM comments WHERE id = ?
    `).bind(commentId).run();

        return jsonResponse({ message: '评论已删除' });
    } catch (error) {
        console.error('删除评论失败:', error);
        return jsonResponse({ error: '删除评论失败' }, 500);
    }
}
