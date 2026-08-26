# GBF-805 — Grok Bot 0.18 observable parity closure

- Project ID: `FAB-P0004`
- Task ID: `GBF-805`
- Status: `IN_PROGRESS`
- Opened: `2026-08-26`
- Tracking issue: `#2155`
- Reference baseline: `bhrum/grok-bot-0.18-reconstructed@a9f633e09d49a85829b8236331b9e21f7e612634`
- Canonical implementation: `bhrumom/fabushi`

## Objective

Close the remaining product gap between the current Fabushi Messenger/Bot experience and the observable Grok Bot 0.18 reconstructed baseline. Completion is defined by what an installed user can observe and operate in packaged builds, not by the existence of isolated implementation files.

The sole execution runtime remains Mahayana. This task does not create a second agent loop.

## Required closure

### 1. Account, logout and unlimited entitlement

- General settings exposes a visible `退出登录` action for every authenticated desktop session.
- Logout uses the canonical Host boundary, clears account-scoped projection/draft/conversation/run caches and native mirrors, and allows browser reauthentication to rebuild the workspace.
- Stable account identity `22` and the authenticated profile are authoritative for the `bhrum108` entitlement. Web, Rust platform, AI backend, provider router and usage/billing surfaces agree on `super-admin + unlimited`.
- No Mahayana/provider path may reject this entitled account with `本月 AI token 额度已不足`.

### 2. True multi-step Agent transcript

A Bot reply is a real Mahayana run and exposes the real runtime lifecycle in Messenger:

1. request accepted / planning / reasoning;
2. model/provider route;
3. ordered steps with status and timing;
4. tool/MCP calls and tool results;
5. approvals and denial/acceptance;
6. subagents/background/async tasks;
7. artifacts and generated outputs;
8. token/context usage;
9. interruption/error/retry/resume;
10. streaming and final answer.

The UI must not collapse the above into a normal assistant bubble or one coarse failure card.

### 3. Stable Bot identity and Grok-style motion

- Every Bot has a stable canonical cloud Bot ID.
- Conversation list, header, profile, message author and Workbench resolve the same Bot ID.
- Shape, color, eyes and motion choreography are deterministic from canonical identity and real runtime state.
- App restart, contact switching, sending messages and another client must not silently generate a different avatar for the same Bot.
- Transient `conversationId`, `requestId` or `operationId` must never become visual identity seeds.

### 4. Canonical cloud/Rust persistence

Canonical authoritative records cover at least:

- Bot and avatar metadata;
- Conversation and Message;
- Agent Run and Step;
- ToolResult;
- Approval;
- Artifact;
- correlation/idempotency metadata required for recovery.

Renderer local storage is a bounded cache/projection only. `GBF-601` and `GBF-602` must close with side-effect-safe restart/resume keyed by stable request/operation identifiers.

### 5. Observable visual parity

Use the pinned reconstructed baseline as an observable reference for Messenger typography, spacing, hierarchy, streaming transitions, run cards, steps, tools, approvals, errors, final results and Bot motion. Produce representative screenshots/video/trace for idle, thinking, tool-running, approval, error and result states.

Provenance stays explicit: reimplement observable behavior and architecture in Fabushi-owned source. Do not wholesale vendor an unlicensed production renderer, brand assets or unknown-license resources.

## Acceptance gates

- Existing selectors/assertions/security gates are not weakened to obtain green CI.
- Relevant TypeScript, Rust, unit, integration, architecture and security suites pass.
- Exact-main packaged journeys pass on macOS, Windows and Linux; Android/iOS gates pass when shared contracts or surfaces are affected.
- Release assets come from the exact tested main SHA and include updater-compatible metadata.
- An already-installed older macOS client is proven to discover the new release.
- Project records for `GBF-501/601/602/703/801/802/803/804/805` are updated from objective evidence.

## Completion rule

`GBF-805` may be marked `RELEASED` only after every required closure above has objective evidence on canonical `main` and the exact tested release. Missing visual, persistence, entitlement, packaged E2E, update-discovery or provenance evidence is a blocker, not a documentation exception.
