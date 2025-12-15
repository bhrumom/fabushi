-- 统一的内容元数据表
-- 解决 content_likes 和 comments 使用不同 ID 导致热门内容数据错位的问题

CREATE TABLE IF NOT EXISTS content_metadata (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  content_id TEXT UNIQUE NOT NULL,      -- 统一的内容ID（使用 file_path 或原 video_id）
  content_type TEXT NOT NULL DEFAULT 'text',
  title TEXT,
  file_path TEXT,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  like_count INTEGER DEFAULT 0,
  comment_count INTEGER DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_content_metadata_content_id ON content_metadata(content_id);
CREATE INDEX IF NOT EXISTS idx_content_metadata_file_path ON content_metadata(file_path);
CREATE INDEX IF NOT EXISTS idx_content_metadata_like_count ON content_metadata(like_count);
