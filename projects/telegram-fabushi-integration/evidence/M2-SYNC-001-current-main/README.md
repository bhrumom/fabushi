# M2-SYNC-001 canonical-main evidence

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task**: `M2-SYNC-001`
- **Status**: `TESTED / LANDED`
- **PR**: #2002
- **Merge**: `d4611f9433eb4d6cbfa934c574cec1da96210edb`

## Runtime evidence

- `native/mahayana-messaging/src/store.rs`: SQLite schema v2 journal, transactional snapshot+journal, cursor-group pagination/pruning.
- `native/mahayana-messaging/src/service.rs`: stable-message idempotency, ACK/Delivered/Read, authorized delta replay/fallback.
- `native/mahayana-messaging/tests/delta_sync_contract.rs`: restart, second-device, outsider isolation, idempotency, delivery/read and migration-floor contracts.

## Current-main compatibility reconciliation

Current stable rustfmt required reformatting. Historical code also referenced removed `Message.client_message_id`; the final implementation retained current `Message` schema and relies on deterministic `stable_message_id(actor_id, client_message_id)` plus legacy local-key lookup. All payload-conflict checks remain.

## Final-head GitHub Actions

| Gate | Run | Result |
|---|---:|---|
| Messaging Product Gate | `32575120937` | SUCCESS |
| Mahayana fast checks | `32575120857` | SUCCESS |
| Fabushi self-hosted messaging | `32575120877` | SUCCESS |
| Repository CI | `32575120874` | SUCCESS |
| Project portfolio governance | `32575120961` | SUCCESS |
| Explicit automerge | `32575120853` | SUCCESS |

## Canonical-main verification

After protected landing, `main` head `d4611f9433eb4d6cbfa934c574cec1da96210edb` was re-read. It contains corrected stable-message idempotency and all durable-sync artifacts.

## Result

M2.T05-T09 satisfy their stage acceptance gate at `TESTED`. See `../M2-ACCEPT-001/README.md` for full M2 closure.
