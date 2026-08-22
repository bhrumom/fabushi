# Messaging Rollback Runbook

## Principle

Rollback application code without corrupting or silently downgrading protocol/database state.

## Before rollback

1. Identify the last known-good protected `main` commit and its protocol/snapshot/SQLite schema versions.
2. Stop write traffic or place the affected service in a controlled maintenance state.
3. Preserve the current database, access registry, logs and deployment metadata.
4. Confirm the target binary can read the existing on-disk schema. If it cannot, do not run it against that database.

## Rollback paths

### Code-only regression with compatible schema

- Deploy the last known-good binary.
- Reuse the existing SQLite database only when schema compatibility is explicit.
- Run authentication, sync and send/read smoke checks before restoring full traffic.

### Incompatible storage/protocol migration

- Do not force the older binary to open a newer schema.
- Restore a matched application+data backup pair or deploy a forward fix.
- Record the chosen path in project evidence and incident/change logs.

### Legacy JSON migration issue

- If SQLite is empty and migration failed, keep the JSON backup and fix the importer/configuration.
- If SQLite already contains newer state, never overwrite it with older JSON as a rollback shortcut.

## Prohibited rollback shortcuts

- re-enabling Telegram network/runtime as a hidden fallback;
- deleting SQLite to make startup succeed;
- disabling account/device access checks;
- manually editing message state to bypass schema validation.

## Completion evidence

Rollback is complete only after the running revision, data/schema compatibility, smoke validation and follow-up action are recorded in the project evidence.
