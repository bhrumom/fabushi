-- Human Call PushKit endpoints are a projection of the existing account+device owner.
-- The canonical Human Call state remains in human_calls/human_call_events.
CREATE TABLE IF NOT EXISTS human_call_voip_devices (
  user_id INTEGER NOT NULL,
  device_id TEXT NOT NULL,
  voip_token TEXT NOT NULL,
  token_updated_at TEXT NOT NULL,
  last_success_at TEXT,
  last_failure_at TEXT,
  PRIMARY KEY (user_id, device_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_human_call_voip_token_unique
  ON human_call_voip_devices(voip_token);

CREATE TABLE IF NOT EXISTS human_call_push_deliveries (
  call_id TEXT NOT NULL,
  generation INTEGER NOT NULL CHECK (generation >= 0),
  device_id TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'delivered', 'retryable-failure', 'invalid-token')),
  attempt_count INTEGER NOT NULL DEFAULT 0 CHECK (attempt_count >= 0),
  last_http_status INTEGER,
  last_reason TEXT,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (call_id, generation, device_id),
  FOREIGN KEY (call_id) REFERENCES human_calls(call_id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_human_call_push_retry
  ON human_call_push_deliveries(status, updated_at);
