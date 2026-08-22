# M2-ACCEPT-001 — M2 realtime messaging stage closure

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M2-ACCEPT-001`
- **Stage**: `M2 自建实时网络 + 1:1 文本消息`
- **Status**: `TESTED`
- **Completed**: `2026-08-22`

## Result

M2.T01-T09 are accepted at `TESTED` on canonical `main`.

## Landed product evidence

- PR #2001 — self-hosted WebSocket/Auth/Heartbeat; merge `2a4124a7b4b769be1320f88621e4eb3ad7f1a3f6`.
- PR #2002 — durable reconnect/idempotent delta sync; merge `d4611f9433eb4d6cbfa934c574cec1da96210edb`.
- Canonical main was re-read after both merges and contains the gateway, WebSocket contracts, SQLite v2 journal, current-schema idempotency logic and delta-sync contracts.

## Final #2002 current-head gates

| Gate | Run | Result |
|---|---:|---|
| Messaging Product Gate | `32575120937` | SUCCESS |
| Mahayana fast checks | `32575120857` | SUCCESS |
| Fabushi self-hosted messaging | `32575120877` | SUCCESS |
| Repository CI | `32575120874` | SUCCESS |
| Project portfolio governance | `32575120961` | SUCCESS |
| Explicit automerge | `32575120853` | SUCCESS |

Messaging Product Gate proved current rustfmt, all-target messaging tests, Clippy, Feature Host bridge/contact projection and Electron Messenger contract. Mahayana fast proved direct Host, feature adapters and embedded FFI boundary.

## Acceptance coverage

- real WebSocket Protocol v2 execution;
- actor/device/session token isolation;
- Ping/Pong heartbeat and bounded frames;
- reconnect/restart recovery through durable cursor journal;
- idempotent send/ACK and conflicting-ID rejection;
- durable server cursor/checkpoint semantics;
- audience-scoped delta replay and outsider isolation;
- safe full-sync fallback when journal coverage is incomplete;
- `Sent -> Delivered -> Read` recipient state transitions.

## Scope boundary

This closes realtime transport and 1:1 synchronization semantics. Desktop interaction completeness remains M3; media, communities, Bot/Agent, Mini Apps, payment, calls, mobile, advanced IM, E2EE and legacy removal remain M4-M14.

## Evidence index

`../../evidence/M2-ACCEPT-001/README.md`
