-- Canonical Human direct-message retention authority.
-- Policy state extends the existing direct Conversation owner; message expiry stays
-- on direct_messages so there is no second message/TTL store.
CREATE TABLE IF NOT EXISTS direct_message_retention_policies (
  conversation_id TEXT PRIMARY KEY,
  user_low_id INTEGER NOT NULL,
  user_high_id INTEGER NOT NULL,
  retention_seconds INTEGER,
  retention_revision INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  CHECK (user_low_id > 0 AND user_high_id > 0 AND user_low_id < user_high_id),
  CHECK (retention_seconds IS NULL OR retention_seconds > 0),
  CHECK (retention_revision >= 0)
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_direct_message_retention_pair
  ON direct_message_retention_policies(user_low_id, user_high_id);

ALTER TABLE direct_messages ADD COLUMN expires_at_ms INTEGER
  CHECK (expires_at_ms IS NULL OR expires_at_ms > 0);
ALTER TABLE direct_messages ADD COLUMN expired_at_ms INTEGER
  CHECK (expired_at_ms IS NULL OR expired_at_ms > 0);

CREATE INDEX IF NOT EXISTS idx_direct_messages_due_expiry
  ON direct_messages(expires_at_ms)
  WHERE expires_at_ms IS NOT NULL AND expired_at_ms IS NULL;
