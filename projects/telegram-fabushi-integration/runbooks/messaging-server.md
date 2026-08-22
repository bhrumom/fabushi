# Messaging Server Runbook

## Purpose

Operate the Fabushi-owned self-hosted messaging server without falling back to Telegram infrastructure.

## Runtime configuration

- `FABUSHI_MESSAGING_BIND`: listen address; default `127.0.0.1:9400`.
- `FABUSHI_MESSAGING_DATABASE`: SQLite state database; target default `fabushi-messaging.sqlite3` once M1.T02 lands.
- `FABUSHI_MESSAGING_ACCESS_REGISTRY`: scoped account/device access-token registry.
- `FABUSHI_MESSAGING_SNAPSHOT`: legacy JSON snapshot location, migration source only after M1.T02.

## Startup checks

1. Confirm the deployed binary corresponds to a commit on protected `main`.
2. Confirm protocol/schema versions are supported before opening the service.
3. Confirm the database and access-registry parent directories are writable by the service account.
4. Start the server using the deployment supervisor; do not expose the development loopback default directly to the public Internet.
5. Confirm clients can authenticate with scoped account/device credentials and that unauthorized frames are rejected.

## Triage

- `InvalidConfig`: inspect bind/database/access-registry settings; do not replace with unsafe defaults.
- `UnsupportedSqliteSchema`: stop rollout and use the rollback runbook; never downgrade a newer database in place.
- `UnsupportedSchema`: client/server snapshot schema mismatch; stop the incompatible rollout.
- `unauthorized`: validate account/device/session binding and required access scope.
- repeated reconnect/message problems: preserve the database and logs, then run messaging/sync acceptance before changing state manually.

## Safety boundaries

- Never point the canonical server at Telegram API/MTProto as a fallback.
- Never delete state files as a first-response recovery action.
- Never bypass access-token validation to restore connectivity.
