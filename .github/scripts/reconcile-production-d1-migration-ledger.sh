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

require_schema_effects() {
  local migration_name="$1"
  local predicate_sql="$2"
  local output

  output="$(wrangler_json "
    SELECT CASE WHEN ($predicate_sql) THEN 1 ELSE 0 END AS ok;
  ")"

  if ! jq -e '[.. | objects | select(has("ok")) | .ok] | any(. == 1 or . == true)' <<<"$output" >/dev/null; then
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
  jq -e '[.. | objects | select(has("recorded")) | .recorded] | any(. == 1 or . == true)' <<<"$output" >/dev/null
}

record_migration() {
  local migration_name="$1"
  wrangler_json "
    INSERT OR IGNORE INTO d1_migrations(name) VALUES ('$migration_name');
  " >/dev/null
  echo "Reconciled production migration ledger entry: $migration_name"
}

# Wrangler's migration runner owns this bookkeeping table. Creating the exact
# compatible shape is safe and does not claim any application migration ran.
wrangler_json "
  CREATE TABLE IF NOT EXISTS d1_migrations(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT UNIQUE,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
  );
" >/dev/null

reconcile_if_present() {
  local migration_name="$1"
  local predicate_sql="$2"
  if migration_recorded "$migration_name"; then
    echo "Migration already recorded: $migration_name"
    return
  fi
  require_schema_effects "$migration_name" "$predicate_sql"
  record_migration "$migration_name"
}

reconcile_if_present "20261005_direct_message_remote_semantics.sql" "
  EXISTS(SELECT 1 FROM pragma_table_info('direct_messages') WHERE name='reply_to_message_id')
  AND EXISTS(SELECT 1 FROM pragma_table_info('direct_messages') WHERE name='attachments_json')
  AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='index' AND name='idx_direct_messages_reply_to')
  AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='table' AND name='direct_message_resources')
  AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='index' AND name='idx_direct_message_resources_owner_created')
  AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='table' AND name='direct_message_reactions')
  AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='index' AND name='idx_direct_message_reactions_message')
"

reconcile_if_present "20261006_human_calls.sql" "
  EXISTS(SELECT 1 FROM sqlite_master WHERE type='table' AND name='human_calls')
  AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='table' AND name='human_call_events')
  AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='index' AND name='idx_human_calls_creator_updated')
  AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='index' AND name='idx_human_calls_peer_updated')
  AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='index' AND name='idx_human_call_events_replay')
"

reconcile_if_present "20261009_direct_message_scheduling.sql" "
  EXISTS(SELECT 1 FROM pragma_table_info('direct_messages') WHERE name='silent')
  AND EXISTS(SELECT 1 FROM pragma_table_info('direct_messages') WHERE name='scheduled_at_ms')
  AND EXISTS(SELECT 1 FROM pragma_table_info('direct_messages') WHERE name='delivery_state')
  AND EXISTS(SELECT 1 FROM pragma_table_info('direct_messages') WHERE name='delivered_at')
  AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='index' AND name='idx_direct_messages_due_schedule')
  AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='index' AND name='idx_direct_messages_recipient_delivery')
"

reconcile_if_present "20261009_human_call_voip_push.sql" "
  EXISTS(SELECT 1 FROM sqlite_master WHERE type='table' AND name='human_call_voip_devices')
  AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='table' AND name='human_call_push_deliveries')
  AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='index' AND name='idx_human_call_voip_token_unique')
  AND EXISTS(SELECT 1 FROM sqlite_master WHERE type='index' AND name='idx_human_call_push_retry')
"

reconcile_if_present "20261012_direct_message_destination.sql" "
  EXISTS(SELECT 1 FROM pragma_table_info('direct_messages') WHERE name='destination_json')
"

echo "Historical production D1 migration ledger is consistent with observed schema effects."
