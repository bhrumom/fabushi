# M2-NET-001 Evidence — Self-hosted WebSocket gateway

## Scope

Covers M2.T01 gateway, M2.T03 WebSocket connection and M2.T04 heartbeat using the same canonical Fabushi Messaging Core and Protocol v2.

## Code evidence

- `native/mahayana-messaging/src/gateway.rs`
- `native/mahayana-messaging/src/server.rs`
- `native/mahayana-messaging/src/lib.rs`
- `native/mahayana-messaging/tests/websocket_gateway_contract.rs`
- PR #1993
- Verified implementation head `c31943c34b0fbf1b1378f39855cb6e2150d2a33e`

## Real network contracts

The integration tests use a real localhost TCP listener and RFC 6455 WebSocket handshake; they do not mock the transport. Coverage includes:

- authenticated Messaging Protocol v2 `Sync` over WebSocket;
- actor/device/session token mismatch -> unauthorized;
- server Ping and client automatic Pong followed by a successful messaging command;
- application payload limit -> `frame_too_large`;
- binary application frame -> `unsupported_binary`.

## GitHub Actions evidence

| Gate | Run | Result |
|---|---:|---|
| Messaging Product Gate | 32560118577 | SUCCESS |
| Mahayana fast checks | 32560118567 | SUCCESS |
| Explicit automerge | 32560118574 | SUCCESS |

Messaging Product Gate also preserves Feature Host/contact projection and Electron Messenger contract compatibility.

## Architecture evidence

TCP and WebSocket transports call one shared authenticated executor and one `MessagingService<SqliteStateStore>`. No parallel chat state machine was introduced. Telegram API/MTProto is not used as a network dependency.

## Landing status

`TESTED` on the stacked branch. #1990 must land first; #1993 will then be retargeted directly to `main`, revalidated, merged through the protected queue, and verified on canonical main.
