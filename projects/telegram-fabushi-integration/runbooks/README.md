# Telegram Integration Runbooks

Operational runbooks for the canonical Fabushi self-hosted messaging stack.

## Current runbooks

- `messaging-server.md` — start/configure/health-triage the self-hosted messaging server.
- `sqlite-storage-migration.md` — migrate legacy JSON state to SQLite and verify no rollback overwrite.
- `rollback.md` — rollback rules for messaging/storage changes without violating protocol/data compatibility.
- `mainsafe-postmerge-blocker.md` — exact-main failure triage, evidence provenance, three-task release gate and protected rollback rules for MAINSAFE post-merge blockers.

## Evidence rule

A runbook command is guidance, not acceptance evidence by itself. Production/project acceptance must link the corresponding GitHub Actions run, deployment/release evidence, or verified runtime report. MAINSAFE acceptance additionally binds evidence to exact main SHA, run/job/platform and stable journey/test identity.

## Canonical boundaries

- Messaging Core: `native/mahayana-messaging/`
- Protocol: `native/mahayana-messaging/src/protocol.rs`
- Server: `native/mahayana-messaging/src/bin/messaging-server.rs`
- Desktop client: `desktop/`
- Product composition: Mahayana Feature Host
- Legacy Telegram runtime/provider paths are migration-only per ADR-0008.
