# M2-NET-001 canonical-main evidence

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task**: `M2-NET-001`
- **Status**: `TESTED / LANDED`
- **PR**: #2001
- **Merge**: `2a4124a7b4b769be1320f88621e4eb3ad7f1a3f6`

## Verified runtime

- `native/mahayana-messaging/src/gateway.rs`
- `native/mahayana-messaging/src/server.rs`
- `native/mahayana-messaging/tests/websocket_gateway_contract.rs`
- shared `MessagingService<SqliteStateStore>` and shared authenticated executor
- real localhost handshake/auth/heartbeat/frame contracts

## Final-head acceptance

Final clean head `1030a489a5b4ed12f93464c95325e5d6d2ca7535` passed Messaging Product Gate, Mahayana fast checks, self-hosted messaging, repository CI, project portfolio governance and Explicit automerge before protected merge.

## Canonical-main verification

After merge, `main` was re-read and confirmed the WebSocket gateway and contract tests are present. Historical #1993 was closed as superseded landing provenance.

## Result

M2.T01-T04 satisfy their stage acceptance gate at `TESTED`. See `../M2-ACCEPT-001/README.md` for full M2 closure.
