-- 添加评论表
CREATE TABLE IF NOT EXISTS comments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  video_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  content TEXT NOT NULL,
  created_at TEXT NOT NULL,
  parent_id INTEGER,
  like_count INTEGER DEFAULT 0
);

CREATE INDEX idx_comments_video_id ON comments(video_id);
CREATE INDEX idx_comments_user_id ON comments(user_id);

-- 更新用户表，添加昵称和头像字段
-- 注意：SQLite不支持在一条语句中添加多个列，需要分多次执行
-- 如果列已存在，这些语句可能会失败，所以建议在应用层处理或手动执行

-- 添加 nickname 字段
ALTER TABLE users ADD COLUMN nickname TEXT;

-- 添加 avatar 字段
ALTER TABLE users ADD COLUMN avatar TEXT;
