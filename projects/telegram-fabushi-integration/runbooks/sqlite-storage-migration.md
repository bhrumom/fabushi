# SQLite Storage Migration Runbook

## Goal

Move an existing Fabushi messaging JSON snapshot into the canonical SQLite store without losing cursor/state or allowing stale JSON to overwrite newer SQLite state.

## Preconditions

- M1.T06 SQLite schema support is present in the deployed binary.
- M1.T02 production SQLite adoption is present before relying on automatic import.
- The legacy JSON file is backed up/readable.
- The target SQLite path is known and has not been replaced by an incompatible newer schema.

## Automatic migration behavior

1. Server opens/initializes the SQLite schema.
2. If SQLite already contains a messaging snapshot, migration is skipped.
3. If SQLite is empty and the configured legacy JSON snapshot exists, that snapshot is loaded and validated.
4. The validated snapshot is written transactionally into SQLite.
5. Subsequent starts use SQLite state and do not re-import stale JSON.

## Verification

- Compare snapshot cursor before/after migration.
- Verify representative conversations/messages and saved state through the canonical messaging API.
- Run the Messaging Product Gate for the deployed source revision.
- Preserve the JSON backup until post-migration verification is complete.

## Failure handling

- Unsupported JSON snapshot schema: do not coerce or edit the file manually; use a compatible binary/migration path.
- Unsupported SQLite schema: do not downgrade in place.
- Partial startup failure: keep both files, repair the binary/configuration, and retry only after confirming whether SQLite already contains state.

## Retirement

Legacy JSON import remains a compatibility path only. Once all supported installations have migrated and M14 removal criteria include storage migration closure, remove the legacy path with explicit evidence.
