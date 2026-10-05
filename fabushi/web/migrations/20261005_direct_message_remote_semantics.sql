-- Extend the canonical account D1 direct-message owner for Desktop Human
-- communication. Binary payloads stay in the existing R2_BUCKET; D1 owns only
-- resource identity/metadata plus canonical message relations and reactions.

ALTER TABLE direct_messages ADD COLUMN reply_to_message_id INTEGER
  REFERENCES direct_messages(id) ON DELETE SET NULL;
ALTER TABLE direct_messages ADD COLUMN attachments_json TEXT NOT NULL DEFAULT '[]';

CREATE INDEX IF NOT EXISTS idx_direct_messages_reply_to
  ON direct_messages(reply_to_message_id);

CREATE TABLE IF NOT EXISTS direct_message_resources (
  id TEXT PRIMARY KEY,
  owner_user_id INTEGER NOT NULL,
  object_key TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  content_type TEXT NOT NULL,
  size INTEGER NOT NULL CHECK (size > 0 AND size <= 33554432),
  created_at TEXT NOT NULL,
  FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_direct_message_resources_owner_created
  ON direct_message_resources(owner_user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS direct_message_reactions (
  message_id INTEGER NOT NULL,
  user_id INTEGER NOT NULL,
  emoji TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (message_id, user_id, emoji),
  FOREIGN KEY (message_id) REFERENCES direct_messages(id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_direct_message_reactions_message
  ON direct_message_reactions(message_id, emoji);
