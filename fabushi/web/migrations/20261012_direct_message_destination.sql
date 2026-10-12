-- Canonical ConversationDestination metadata for Human message transport.
-- The existing direct_messages row remains the single durable transport owner.
-- destination_json never broadens the authorized Human peer; the canonical
-- Conversation owner validates child authority before dispatch.
ALTER TABLE direct_messages ADD COLUMN destination_json TEXT
  CHECK (destination_json IS NULL OR json_valid(destination_json));
