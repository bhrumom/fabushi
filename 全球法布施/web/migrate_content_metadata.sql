-- 迁移现有数据到 content_metadata 表
-- 从 content_likes 和 comments 表汇总数据

-- 1. 插入点赞数据
INSERT OR REPLACE INTO content_metadata (content_id, content_type, title, file_path, like_count, comment_count)
SELECT 
    content_id,
    COALESCE(MAX(content_type), 'text') as content_type,
    MAX(title) as title,
    MAX(file_path) as file_path,
    COUNT(*) as like_count,
    0 as comment_count
FROM content_likes
GROUP BY content_id;

-- 2. 更新评论数（合并到已有记录或插入新记录）
INSERT INTO content_metadata (content_id, content_type, title, file_path, like_count, comment_count)
SELECT 
    video_id as content_id,
    'text' as content_type,
    MAX(video_title) as title,
    NULL as file_path,
    0 as like_count,
    COUNT(*) as comment_count
FROM comments
GROUP BY video_id
ON CONFLICT(content_id) DO UPDATE SET 
    title = COALESCE(excluded.title, content_metadata.title),
    comment_count = excluded.comment_count;
