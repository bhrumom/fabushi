-- 法流标签功能数据库迁移
-- 在 comments 表添加 tag 字段

ALTER TABLE comments ADD COLUMN tag TEXT;

-- 创建索引以优化按标签查询
CREATE INDEX IF NOT EXISTS idx_comments_tag ON comments(tag);
CREATE INDEX IF NOT EXISTS idx_comments_tag_created ON comments(tag, created_at DESC);
