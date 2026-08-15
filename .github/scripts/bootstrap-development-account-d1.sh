#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 2 ]; then
  echo "usage: $0 <wrangler-config> <environment>" >&2
  exit 64
fi

config="$1"
environment="$2"
binding="DB"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
web_root="$repo_root/fabushi/web"
migrations_dir="$web_root/migrations"
schema_file="$web_root/schema_v2.sql"

baseline_migrations=(
  20260503_social_follow_privacy.sql
  20260506_co_practice_groups.sql
  20260508_users_free_trial_end_date.sql
  20260508_users_id_identity.sql
  20260508_users_payment_columns.sql
  20260509_external_numbers_randomized.sql
  20260509_user_no_group_no_layering.sql
  20260510_group_members_user_id.sql
  20260510_users_username_changed_at.sql
  20260519_owned_data_user_id.sql
  20260522_users_alipay_open_id.sql
  20260524_practice_books.sql
  20260713_friends_and_direct_messages.sql
  20260810_mcp_app_identity_schema.sql
)

post_schema_migrations=(
  20260509_user_no_group_no_layering.sql
  20260509_external_numbers_randomized.sql
  20260524_practice_books.sql
  20260713_friends_and_direct_messages.sql
  20260810_mcp_app_identity_schema.sql
)

for migration in "${baseline_migrations[@]}"; do
  test -f "$migrations_dir/$migration" || {
    echo "missing baseline migration: $migration" >&2
    exit 1
  }
done

test -f "$schema_file" || {
  echo "missing canonical schema: $schema_file" >&2
  exit 1
}

query_json="$(mktemp)"
cleanup_sql="$(mktemp)"
seed_sql="$(mktemp)"
trap 'rm -f "$query_json" "$cleanup_sql" "$seed_sql"' EXIT

npx --yes wrangler@latest d1 execute "$binding" \
  --config "$config" \
  --env "$environment" \
  --remote \
  --command "SELECT COUNT(*) AS found FROM sqlite_schema WHERE type = 'table' AND name = 'users';" \
  --json > "$query_json"

users_found="$(python3 - "$query_json" <<'PY'
import json
import sys

payload = json.load(open(sys.argv[1], encoding='utf-8'))

def walk(value):
    if isinstance(value, dict):
        if 'found' in value:
            return value['found']
        for child in value.values():
            result = walk(child)
            if result is not None:
                return result
    elif isinstance(value, list):
        for child in value:
            result = walk(child)
            if result is not None:
                return result
    return None

found = walk(payload)
if found is None:
    raise SystemExit('could not find users-table probe result in Wrangler JSON')
print(int(found))
PY
)"

if [ "$users_found" -gt 0 ]; then
  echo "Development account D1 already has a users table; bootstrap not required."
  exit 0
fi

echo "Development account D1 has no users table; bootstrapping current schema."

# A prior failed first-time migration can leave only these self-contained shells
# plus Wrangler's migration ledger. With no users table the database is not a
# usable application database, so reset only that incomplete bootstrap state.
cat > "$cleanup_sql" <<'SQL'
PRAGMA defer_foreign_keys = ON;
DROP TABLE IF EXISTS d1_migrations;
DROP TABLE IF EXISTS meditation_group_members;
DROP TABLE IF EXISTS meditation_groups;
DROP TABLE IF EXISTS user_practice_privacy;
DROP TABLE IF EXISTS user_follows;
SQL

npx --yes wrangler@latest d1 execute "$binding" \
  --config "$config" --env "$environment" --remote --yes --file "$cleanup_sql"

# schema_v2.sql is the canonical current account schema. Historical D1
# migrations predate a managed baseline and cannot be replayed from an empty DB.
npx --yes wrangler@latest d1 execute "$binding" \
  --config "$config" --env "$environment" --remote --yes --file "$schema_file"

# These migrations add structures intentionally newer than schema_v2.sql.
for migration in "${post_schema_migrations[@]}"; do
  echo "Applying bootstrap supplement: $migration"
  npx --yes wrangler@latest d1 execute "$binding" \
    --config "$config" --env "$environment" --remote --yes \
    --file "$migrations_dir/$migration"
done

cat > "$seed_sql" <<'SQL'
CREATE TABLE IF NOT EXISTS d1_migrations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT UNIQUE,
  applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);
SQL
for migration in "${baseline_migrations[@]}"; do
  printf "INSERT OR IGNORE INTO d1_migrations (name) VALUES ('%s');\n" "$migration" >> "$seed_sql"
done

npx --yes wrangler@latest d1 execute "$binding" \
  --config "$config" --env "$environment" --remote --yes --file "$seed_sql"

# Fail closed if any critical current-schema table is absent after bootstrap.
npx --yes wrangler@latest d1 execute "$binding" \
  --config "$config" \
  --env "$environment" \
  --remote \
  --command "SELECT CASE WHEN COUNT(*) = 6 THEN 1 ELSE json_extract('invalid bootstrap', '$') END AS ok FROM sqlite_schema WHERE type = 'table' AND name IN ('users','practice_books','friend_requests','direct_messages','mcp_app_identity','meditation_groups');"

echo "Development account D1 bootstrap completed."
