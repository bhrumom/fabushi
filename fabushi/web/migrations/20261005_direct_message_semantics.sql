-- Message relations, authenticated attachment objects, and reactions for
-- Fabushi-owned direct messaging. Telegram remains research-only; these tables
-- extend the existing canonical direct_messages owner.

ALTER TABLE direct_messages ADD COLUMN reply_to_message_id INTEGER;
ALTER TABLE direct_messages ADD COLUMN attachments_json TEXT NOT NULL DEFAULT '[]';

CREATE INDEX IF NOT EXISTS idx_direct_messages_reply
  ON direct_messages(reply_to_message_id);

CREATE TABLE IF NOT EXISTS direct_message_attachments (
  id TEXT PRIMARY KEY,
  uploader_user_id INTEGER NOT NULL,
  object_key TEXT NOT NULL UNIQUE,
  file_name TEXT NOT NULL,
  content_type TEXT NOT NULL,
  size_bytes INTEGER NOT NULL CHECK (size_bytes > 0),
  message_id INTEGER,
  created_at TEXT NOT NULL,
  FOREIGN KEY (uploader_user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (message_id) REFERENCES direct_messages(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_direct_message_attachments_owner_unbound
  ON direct_message_attachments(uploader_user_id, message_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_direct_message_attachments_message
  ON direct_message_attachments(message_id);

CREATE TABLE IF NOT EXISTS direct_message_reactions (
  message_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  emoji TEXT NOT NULL CHECK (length(emoji) BETWEEN 1 AND 32),
  created_at TEXT NOT NULL,
  PRIMARY KEY (message_id, user_id, emoji),
  FOREIGN KEY (message_id) REFERENCES direct_messages(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_direct_message_reactions_message
  ON direct_message_reactions(message_id, created_at ASC);
