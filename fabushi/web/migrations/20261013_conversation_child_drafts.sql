CREATE TABLE IF NOT EXISTS conversation_child_drafts (
  owner_user_id INTEGER NOT NULL,
  conversation_id TEXT NOT NULL,
  child_kind TEXT NOT NULL,
  child_id TEXT NOT NULL,
  draft_text TEXT NOT NULL DEFAULT '',
  reply_to_message_id INTEGER,
  draft_revision INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (owner_user_id, conversation_id, child_kind, child_id),
  FOREIGN KEY (owner_user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (reply_to_message_id) REFERENCES direct_messages(id) ON DELETE SET NULL,
  CHECK (length(conversation_id) BETWEEN 1 AND 200),
  CHECK (child_kind IN ('topic', 'savedSublist', 'conversation')),
  CHECK (length(child_id) BETWEEN 1 AND 200),
  CHECK (length(draft_text) <= 4000),
  CHECK (draft_revision >= 0)
);

CREATE INDEX IF NOT EXISTS idx_conversation_child_drafts_owner_updated
  ON conversation_child_drafts(owner_user_id, updated_at DESC);
