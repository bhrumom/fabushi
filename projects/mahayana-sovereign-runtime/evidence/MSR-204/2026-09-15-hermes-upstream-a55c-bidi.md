# MSR-204 — Hermes upstream refresh and bidirectional gateway delta

Date: 2026-09-15
Project: FAB-P0005 / MSR
Canonical implementation: PR #2620, `feat/msr-204-hermes-gateway-transcript`

## Upstream identity

The original MSR-204 audit pinned `NousResearch/hermes-agent` at `4d55ca91656ac5f83e1506679b7f81e0238e5e16`.

Before continuing implementation on 2026-09-15, upstream `main` was re-read and found at:

- `a55c972e09177e4db3934915e329993858b247d6`
- 35 commits ahead of the prior `4d55ca...` audit point
- license remains MIT / Nous Research

The upstream refresh is treated as an incremental audit. Existing Mahayana code is not replaced with the Hermes Python runtime.

## MSR-204-relevant upstream delta

The new Hermes revision strengthens the same architecture MSR-204 is targeting:

- explicit server -> client JSON-RPC request contracts and generated OpenRPC surface;
- Desktop server-request rendering/response handling;
- request-id ownership for `clarify`, `approval`, `sudo`, `secret`, `vault.*`, `terminal.read`, `preview.read`, `window.read`, `preview.act`, and `tour`;
- one `request.cancel` notification contract for interrupt/timeout/withdrawal;
- reconnect replay of still-open server requests;
- batch clarification answer locking so already-submitted answers remain immutable across replay;
- additional context preservation around sudo and MCP OAuth flows;
- gateway streaming/silence fixes.

Other upstream changes in the same 35-commit window (Gemini support, group-chat fixes, doctor/profile work and unrelated UI fixes) belong to the broader Hermes capability matrix and are not represented as completed by MSR-204.

## Mahayana implementation added in this round

`mahayana-gateway-peer` is a first-party Rust implementation of the transport-state semantics above. It adds:

- `srq-*` Rust-owned server-request ids;
- a registry of open requests, keyed by request id and session;
- JSON-RPC `result` / `error` resolution;
- the current server-request method vocabulary as a contract allowlist;
- shared `request.cancel` notifications;
- reconnect replay of still-open requests;
- batch-clarify per-question answer locking;
- export/import of pending state so a canonical Rust store can persist it later;
- focused unit tests for request identity, response matching, cancellation, replay, locking and state round-trip.

The stdio `mahayana-gateway` now uses this peer state for the one server-request capability the native Mahayana Runtime already exposes today: approval. A native `ApprovalRequested` event opens a peer JSON-RPC request carrying the same Runtime request id; a client response is translated back to the existing `ApprovalDecision` and resolved through the Runtime. The legacy `approval.respond` method remains compatible and closes the corresponding peer lock.

## Deliberate non-claims

This round does **not** fabricate Runtime abilities that do not exist yet. Native `RuntimeEvent` currently exposes approval but not the full clarify/sudo/secret/vault/terminal/preview/tour request family. Those methods are represented in the peer contract and registry, but each becomes product-capable only when the corresponding Mahayana runtime/tool-policy producer and secure renderer are implemented and accepted.

The peer registry exposes state export/import, but it is not yet wired to a canonical durable Mahayana conversation/run store. Process-restart replay therefore remains incomplete.

WebSocket/App-Host transport still needs to share this same peer/dispatcher state; stdio is the first concrete transport. No WebSocket-parity claim is made yet.
