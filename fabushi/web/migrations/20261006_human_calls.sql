-- Canonical account-scoped 1:1 Human call signaling authority.
-- The Desktop Host owns the local CallSession state machine; D1 owns
-- participant authorization, device leases, monotonic event sequencing, and
-- durable cross-device replay for the production transport.

CREATE TABLE IF NOT EXISTS human_calls (
  call_id TEXT PRIMARY KEY,
  creator_user_id INTEGER NOT NULL,
  peer_user_id INTEGER NOT NULL,
  creator_device_id TEXT,
  peer_device_id TEXT,
  state TEXT NOT NULL CHECK (state IN (
    'invited', 'ringing', 'negotiating', 'connected',
    'reconnecting', 'ended', 'failed'
  )),
  generation INTEGER NOT NULL DEFAULT 0 CHECK (generation >= 0),
  event_seq INTEGER NOT NULL DEFAULT 0 CHECK (event_seq >= 0),
  terminal_state TEXT CHECK (terminal_state IS NULL OR terminal_state IN ('ended', 'failed')),
  last_event_token TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (creator_user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (peer_user_id) REFERENCES users(id) ON DELETE CASCADE,
  CHECK (creator_user_id != peer_user_id)
);

CREATE INDEX IF NOT EXISTS idx_human_calls_creator_updated
  ON human_calls(creator_user_id, updated_at DESC);
CREATE INDEX IF NOT EXISTS idx_human_calls_peer_updated
  ON human_calls(peer_user_id, updated_at DESC);

CREATE TABLE IF NOT EXISTS human_call_events (
  call_id TEXT NOT NULL,
  seq INTEGER NOT NULL CHECK (seq > 0),
  generation INTEGER NOT NULL CHECK (generation >= 0),
  user_id INTEGER NOT NULL,
  device_id TEXT NOT NULL,
  client_event_id TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('transition', 'signal', 'media')),
  payload_json TEXT NOT NULL CHECK (json_valid(payload_json)),
  created_at TEXT NOT NULL,
  PRIMARY KEY (call_id, seq),
  UNIQUE (call_id, user_id, client_event_id),
  FOREIGN KEY (call_id) REFERENCES human_calls(call_id) ON DELETE CASCADE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS idx_human_call_events_replay
  ON human_call_events(call_id, seq ASC);
