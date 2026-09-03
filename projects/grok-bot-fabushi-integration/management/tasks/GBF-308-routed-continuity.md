# GBF-308 — Routed transcript, MCP and usage continuity

- Project ID: `FAB-P0004`
- Project Key: `GBF`
- Task ID: `GBF-308`
- Status: `RELEASED`
- Started: `2026-08-24 18:28 +08:00`
- Updated: `2026-08-24 21:56 +08:00`
- Completed: `2026-08-24 21:56 +08:00`
- Branch: `codex/gbf-provider-router`
- Commit / PR: unified head `4d8d3a6a...` / [#2106](https://github.com/bhrumom/fabushi/pull/2106) / main `f81588d3...`

## Objective and scope

Preserve the assistant transcript, native tool-call/result context, MCP/approval boundary and per-provider usage when the user changes inference Provider. This task does not migrate arbitrary non-assistant chats or copy reconstructed persistence code.

Source: `GBR-003`, `GBR-013`, pinned reconstructed commit `a9f633e...`.

## Acceptance and verification

1. Runtime transcript survives Host/provider recreation and remains ordered — Rust runtime/kernel tests in GitHub Actions.
2. Native-to-native switching restores exact native session/tool history; a newer transcript supersedes a stale snapshot — native-engine tests.
3. Codex receives a one-time bounded provider-neutral bootstrap and cannot reinterpret it as system instructions — bridge tests.
4. Usage remains separated by Provider with request/input/output/cache/lifetime/last-used fields — Node contract + packaged settings E2E.
5. Exact-main packaged journey retains screenshots, video, trace and report before completion.

## Open-source survey and decision

The pinned reconstructed repository's Router/session behavior was inspected, but it grants no source license. Existing Mahayana session snapshots, kernel events and Host restart model were reused. A Fabushi-owned bounded transcript bridge was added instead of importing Cursor session/protobuf storage.

## Implementation

- Added private provider-neutral transcript persistence below the runtime data directory.
- Added exact native assistant-session snapshots and stale-snapshot resolution by transcript timestamp.
- Added one-time, 200-message/256-KiB Codex bootstrap labelled as context rather than instructions.
- Kept MCP, tool authorization and approval in the same Mahayana engine; only model wire transport changes.
- Added seven-day and lifetime usage aggregation by Provider without prompt logging.

## Evidence, risks and next action

Lightweight local inspection only; no application build/test ran locally. Canonical seven-gate `32731980249` passed on the unified head, protected-main merge produced `f81588d3...`, exact-main Electron `32733627050` and native mobile `32733627056` passed with retained user-journey evidence, and post-main delivery `32734915241` published `desktop-1.0.867`. Transcript files contain user content and rely on private app-data permissions rather than telemetry storage. No remaining task blocker.
