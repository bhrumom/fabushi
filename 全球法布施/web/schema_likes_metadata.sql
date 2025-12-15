-- 点赞表 (升级版，支持内容元数据)
-- 添加 title 和 file_path 字段
ALTER TABLE content_likes ADD COLUMN title TEXT;
ALTER TABLE content_likes ADD COLUMN file_path TEXT;
