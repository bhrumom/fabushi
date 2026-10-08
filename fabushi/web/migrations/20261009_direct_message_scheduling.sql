-- Canonical direct-message silent + scheduled delivery semantics.
-- D1 remains the single durable message/scheduler truth. A Worker cron only
-- advances due rows from scheduled -> delivered; it owns no parallel payload.

ALTER TABLE direct_messages ADD COLUMN silent INTEGER NOT NULL DEFAULT 0
  CHECK (silent IN (0, 1));
ALTER TABLE direct_messages ADD COLUMN scheduled_at_ms INTEGER
  CHECK (scheduled_at_ms IS NULL OR scheduled_at_ms > 0);
ALTER TABLE direct_messages ADD COLUMN delivery_state TEXT NOT NULL DEFAULT 'delivered'
  CHECK (delivery_state IN ('scheduled', 'delivered'));
ALTER TABLE direct_messages ADD COLUMN delivered_at TEXT;

UPDATE direct_messages
SET delivery_state = 'delivered',
    delivered_at = COALESCE(delivered_at, created_at)
WHERE delivery_state = 'delivered';

CREATE INDEX IF NOT EXISTS idx_direct_messages_due_schedule
  ON direct_messages(delivery_state, scheduled_at_ms)
  WHERE delivery_state = 'scheduled';

CREATE INDEX IF NOT EXISTS idx_direct_messages_recipient_delivery
  ON direct_messages(recipient_user_id, sender_user_id, delivery_state, created_at DESC);
