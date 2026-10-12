#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "usage: $0 <database-binding> <environment> [extra wrangler args...]" >&2
  exit 64
fi

binding="$1"
environment="$2"
shift 2
extra_args=("$@")

wrangler_json() {
  local sql="$1"
  npx --yes wrangler@latest d1 execute "$binding" \
    --env "$environment" \
    --remote \
    --command "$sql" \
    --json \
    "${extra_args[@]}"
}

json_truthy_field() {
  local field="$1"
  jq -e --arg field "$field" '[.. | objects | select(has($field)) | .[$field]] | any(. == 1 or . == true)' >/dev/null
}

column_exists() {
  local table="$1"
  local column="$2"
  local output
  output="$(wrangler_json "
    SELECT CASE WHEN EXISTS(
      SELECT 1 FROM pragma_table_info('$table') WHERE name='$column'
    ) THEN 1 ELSE 0 END AS present;
  ")"
  json_truthy_field present <<<"$output"
}

ensure_column() {
  local table="$1"
  local column="$2"
  local alter_sql="$3"
  if column_exists "$table" "$column"; then
    echo "Column already present: $table.$column"
    return
  fi
  echo "Repairing missing column: $table.$column"
  wrangler_json "$alter_sql" >/dev/null
  if ! column_exists "$table" "$column"; then
    echo "::error::Column repair did not materialize: $table.$column" >&2
    exit 1
  fi
}

require_schema_effects() {
  local migration_name="$1"
  local predicate_sql="$2"
  local output
  output="$(wrangler_json "
    SELECT CASE WHEN ($predicate_sql) THEN 1 ELSE 0 END AS ok;
  ")"
  if ! json_truthy_field ok <<<"$output"; then
    echo "::error::Refusing to mark $migration_name applied: required production schema effects are incomplete." >&2
    echo "$output" >&2
    exit 1
  fi
}

migration_recorded() {
  local migration_name="$1"
  local output
  output="$(wrangler_json "
    SELECT CASE WHEN EXISTS(
      SELECT 1 FROM d1_migrations WHERE name = '$migration_name'
    ) THEN 1 ELSE 0 END AS recorded;
  ")"
  json_truthy_field recorded <<<"$output"
}

record_migration() {
  local migration_name="$1"
  wrangler_json "
    INSERT OR IGNORE INTO d1_migrations(name) VALUES ('$migration_name');
  " >/dev/null
  echo "Reconciled production migration ledger entry: $migration_name"
}

wrangler_json "
  CREATE TABLE IF NOT EXISTS d1_migrations(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
  );
" >/dev/null

if ! migration_recorded "20261005_direct_message_remote_semantics.sql"; then
  ensure_column direct_messages reply_to_message_id \
    "ALTER TABLE direct_messages ADD COLUMN reply_to_message_id INTEGER REFERENCES direct_messages(id) ON DELETE SET NULL;"
  ensure_column direct_messages attachments_json \
    "ALTER TABLE direct_messages ADD COLUMN attachments_json TEXT NOT NULL DEFAULT '[]';"
  wrangler_json "
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
  " >/dev/null
  require_schema_effects "20261005_direct_message_remote_semantics.sql" "
    EXISTS(SELECT 1 FROM pragma_table_info('direct_messages') WHERE name='reply_to_message_id')
    AND EXISTS(SELECT 1 FROM pragma_table_info('direct_messages') WHERE name='attachments_json')
    AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='index' AND name='idx_direct_messages_reply_to')
    AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='table' AND name='direct_message_resources')
    AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='index' AND name='idx_direct_message_resources_owner_created')
    AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='table' AND name='direct_message_reactions')
    AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='index' AND name='idx_direct_message_reactions_message')
  "
  record_migration "20261005_direct_message_remote_semantics.sql"
fi

if ! migration_recorded "20261006_human_calls.sql"; then
  wrangler_json "
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
  " >/dev/null
  require_schema_effects "20261006_human_calls.sql" "
    EXISTS(SELECT 1 FROM sqlite_master WHERE type='table' AND name='human_calls')
    AND EXISTS(SELECT 1 FROM pragma_table_info('human_calls') WHERE name='event_seq')
    AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='table' AND name='human_call_events')
    AND EXISTS(SELECT 1 FROM pragma_table_info('human_call_events') WHERE name='client_event_id')
    AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='index' AND name='idx_human_calls_creator_updated')
    AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='index' AND name='idx_human_calls_peer_updated')
    AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='index' AND name='idx_human_call_events_replay')
  "
  record_migration "20261006_human_calls.sql"
fi

if ! migration_recorded "20261009_direct_message_scheduling.sql"; then
  ensure_column direct_messages silent \
    "ALTER TABLE direct_messages ADD COLUMN silent INTEGER NOT NULL DEFAULT 0 CHECK (silent IN (0, 1));"
  ensure_column direct_messages scheduled_at_ms \
    "ALTER TABLE direct_messages ADD COLUMN scheduled_at_ms INTEGER CHECK (scheduled_at_ms IS NULL OR scheduled_at_ms > 0);"
  ensure_column direct_messages delivery_state \
    "ALTER TABLE direct_messages ADD COLUMN delivery_state TEXT NOT NULL DEFAULT 'delivered' CHECK (delivery_state IN ('scheduled', 'delivered'));"
  ensure_column direct_messages delivered_at \
    "ALTER TABLE direct_messages ADD COLUMN delivered_at TEXT;"
  wrangler_json "
    UPDATE direct_messages
      SET delivery_state='delivered',
          delivered_at=COALESCE(delivered_at, created_at)
      WHERE delivery_state='delivered';
    CREATE INDEX IF NOT EXISTS idx_direct_messages_due_schedule
      ON direct_messages(delivery_state, scheduled_at_ms)
      WHERE delivery_state='scheduled';
    CREATE INDEX IF NOT EXISTS idx_direct_messages_recipient_delivery
      ON direct_messages(recipient_user_id, sender_user_id, delivery_state, created_at DESC);
  " >/dev/null
  require_schema_effects "20261009_direct_message_scheduling.sql" "
    EXISTS(SELECT 1 FROM pragma_table_info('direct_messages') WHERE name='silent')
    AND EXISTS(SELECT 1 FROM pragma_table_info('direct_messages') WHERE name='scheduled_at_ms')
    AND EXISTS(SELECT 1 FROM pragma_table_info('direct_messages') WHERE name='delivery_state')
    AND EXISTS(SELECT 1 FROM pragma_table_info('direct_messages') WHERE name='delivered_at')
    AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='index' AND name='idx_direct_messages_due_schedule')
    AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='index' AND name='idx_direct_messages_recipient_delivery')
  "
  record_migration "20261009_direct_message_scheduling.sql"
fi

if ! migration_recorded "20261009_human_call_voip_push.sql"; then
  wrangler_json "
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
  " >/dev/null
  require_schema_effects "20261009_human_call_voip_push.sql" "
    EXISTS(SELECT 1 FROM sqlite_master WHERE type='table' AND name='human_call_voip_devices')
    AND EXISTS(SELECT 1 FROM pragma_table_info('human_call_voip_devices') WHERE name='voip_token')
    AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='table' AND name='human_call_push_deliveries')
    AND EXISTS(SELECT 1 FROM pragma_table_info('human_call_push_deliveries') WHERE name='attempt_count')
    AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='index' AND name='idx_human_call_voip_token_unique')
    AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='index' AND name='idx_human_call_push_retry')
  "
  record_migration "20261009_human_call_voip_push.sql"
fi

if ! migration_recorded "20261012_direct_message_destination.sql"; then
  ensure_column direct_messages destination_json \
    "ALTER TABLE direct_messages ADD COLUMN destination_json TEXT CHECK (destination_json IS NULL OR json_valid(destination_json));"
  require_schema_effects "20261012_direct_message_destination.sql" "
    EXISTS(SELECT 1 FROM pragma_table_info('direct_messages') WHERE name='destination_json')
  "
  record_migration "20261012_direct_message_destination.sql"
fi

echo "Historical production D1 schema and migration ledger are reconciled."
