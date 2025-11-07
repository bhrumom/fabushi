-- 点赞表
CREATE TABLE IF NOT EXISTS content_likes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  content_id TEXT NOT NULL,
  content_type TEXT NOT NULL,
  user_id TEXT,
  created_at TEXT NOT NULL,
  UNIQUE(content_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_content_likes_content_id ON content_likes(content_id);
CREATE INDEX IF NOT EXISTS idx_content_likes_user_id ON content_likes(user_id);
