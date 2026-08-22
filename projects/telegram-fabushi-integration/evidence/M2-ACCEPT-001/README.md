# M2-ACCEPT-001 evidence index

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Stage**: `M2`
- **Status**: `TESTED`

## Network layer

PR #2001 landed `MessagingWebSocketGateway` and real localhost WebSocket contracts on canonical main as `2a4124a7b4b769be1320f88621e4eb3ad7f1a3f6`.

Verified artifacts:
- `native/mahayana-messaging/src/gateway.rs`
- `native/mahayana-messaging/src/server.rs`
- `native/mahayana-messaging/tests/websocket_gateway_contract.rs`

## Durable sync layer

PR #2002 landed schema-v2 durable event journaling, idempotent send/ACK, cursor delta replay, restart recovery and Sent/Delivered/Read on canonical main as `d4611f9433eb4d6cbfa934c574cec1da96210edb`.

Verified artifacts:
- `native/mahayana-messaging/src/store.rs`
- `native/mahayana-messaging/src/service.rs`
- `native/mahayana-messaging/tests/delta_sync_contract.rs`

## Current-head gates for final M2 landing

- Messaging Product Gate `32575120937` — SUCCESS.
- Mahayana fast checks `32575120857` — SUCCESS.
- Fabushi self-hosted messaging `32575120877` — SUCCESS.
- Repository CI `32575120874` — SUCCESS.
- Project portfolio governance `32575120961` — SUCCESS.
- Explicit automerge `32575120853` — SUCCESS.

## Compatibility evidence

The clean final landing intentionally preserved the current canonical `Message` schema. Historical code's obsolete `Message.client_message_id` check was removed because deterministic `stable_message_id(actor_id, client_message_id)` already binds replay identity; all current Rust tests and Clippy passed after the reconciliation.

## Canonical-main result

`main` head `d4611f9433eb4d6cbfa934c574cec1da96210edb` was re-read and contains the corrected deterministic-idempotency code and all M2 runtime/test artifacts. M2.T01-T09 therefore satisfy the stage completion gate at `TESTED`.
