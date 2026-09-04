# TFI-M6-P0-005 — protocol v2 reader boundary and v3 negotiation

- Project ID: `FAB-P0001`
- Task ID: `TFI-M6-P0-005`
- Status: `BLOCKED`
- Owner: Execution project group
- Dependencies: `TFI-M6-P0-003 REVIEW-PASS`, `TFI-M6-P0-004 REVIEW-PASS`

## Objective

Introduce the minimum compatible protocol-v3 contract needed for admission, authoritative server time and request bridging without breaking existing v2 readers.

## Design constraints

- Document `supported_versions`/selected version at connection/request boundary; unsupported future versions fail explicitly.
- Preserve a fixture-backed v2 reader boundary: a negotiated v2 peer receives only v2-compatible fields/events.
- v3 may add admission outcome/context, authoritative `server_time_ms`, and request/response correlation needed by the desktop request bridge.
- Client `sent_at_ms` is diagnostic only; permission/invite expiry decisions use server time.
- Request bridge is exactly-once/idempotent by request ID where required and cannot double-apply a mutating command after reconnect/retry.
- Do not overload topic/thread legacy syntax; preserve fixture compatibility.

## Acceptance

Golden v2 fixtures decode; v2 negotiation works; v3 negotiation works; future version rejects; clock-skew tests prove server time authority; duplicate/replayed request tests prove no double mutation; Electron reader/bridge contract is covered. Update protocol docs and project record in the same PR.