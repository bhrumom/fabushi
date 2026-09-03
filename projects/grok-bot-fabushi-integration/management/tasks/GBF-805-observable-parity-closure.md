# GBF-805 — Grok Bot 0.18 observable parity closure

- Project ID: `FAB-P0004`
- Task ID: `GBF-805`
- Status: `IN_PROGRESS`
- Opened: `2026-08-26`
- Tracking issue: `#2155`
- Reference baseline: `bhrum/grok-bot-0.18-reconstructed@a9f633e09d49a85829b8236331b9e21f7e612634`
- Canonical implementation: `bhrumom/fabushi`
- Active implementation branch: `fix/gbf805-product-parity-20260903`

## Objective

Close the remaining product gap between the current Fabushi Messenger/Bot experience and the observable Grok Bot 0.18 reconstructed baseline. Completion is defined by what an installed user can observe and operate in packaged builds, not by the existence of isolated implementation files.

The sole execution runtime remains Mahayana. This task does not create a second agent loop.

## Manual execution rule

This closure is being implemented directly in the Fabushi source tree. `ChatGPT auto-confirm continuous runner` is not an implementation or acceptance source for GBF-805. The task-inbox auto-dispatch workflow was removed on the active branch so future inbox changes cannot start that runner. Normal repository CI, security, packaging and release workflows remain required product gates.

## Open-source/reference startup research

The pinned reconstructed baseline's `frontend/src/production/ProductionRenderer.tsx` was inspected before implementation. Observable patterns retained as reference include the explicit conversation transcript, outline/subagent surface, asynchronous task panel, approval actions, account menu/sign-out flow and avatar editor. The recovered/minified production renderer and unknown-license resources are **not** vendored or copied wholesale; Fabushi reimplements the observable behavior on its existing React + Mahayana + canonical native/Rust boundaries.

## Required closure

### 1. Account, logout and unlimited entitlement

- General settings exposes a visible `退出登录` action for every authenticated desktop session.
- Logout uses the canonical Host boundary, clears account-scoped projection/draft/conversation/run caches and native mirrors, and allows browser reauthentication to rebuild the workspace.
- Stable account identity `22` and the authenticated profile are authoritative for the `bhrum108` entitlement. Web, Rust platform, AI backend, provider router and usage/billing surfaces agree on `super-admin + unlimited`.
- No Mahayana/provider path may reject this entitled account with `本月 AI token 额度已不足`.

Current manual evidence:

- Existing desktop E2E already drives `data-testid="settings-logout"`, verifies visible `退出登录`, removes the workspace after logout and checks account-scoped renderer caches are cleared.
- The existing account-session reset event is now also wired to remove native mirrors for the Mahayana Workbench, conversation journal and self-hosted invocation idempotency journal.
- Web helpers and the AI backend independently recognize both stable account id `22` and username `bhrum108` as unlimited super-admin; existing unit tests cover username and stable-id fallbacks. End-to-end provider invocation remains an acceptance gate rather than a documentation assumption.

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

Current manual evidence:

- `mahayana-agent-workbench.tsx` already projects the real Mahayana request/operation/conversation/agent ids, provider/model route, ordered steps, streaming assistant output, tool/MCP results, approvals, artifacts, subagents/background tasks, usage, interruption/retry/resume and final answer.
- `selfhosted-mahayana-invocation-bridge.ts` already converts the Rust `botInvocationRequested` event into the single canonical Mahayana Agent runtime while preserving the self-hosted Bot identity in Workbench projection context.
- The active branch makes Workbench and conversation projections restart-safe through native client persistence; packaged interaction proof is still pending.

### 3. Stable Bot identity and Grok-style motion

- Every Bot has a stable canonical cloud Bot ID.
- Conversation list, header, profile, message author and Workbench resolve the same Bot ID.
- Shape, color, eyes and motion choreography are deterministic from canonical identity and real runtime state.
- App restart, contact switching, sending messages and another client must not silently generate a different avatar for the same Bot.
- Transient `conversationId`, `requestId` or `operationId` must never become visual identity seeds.

Current manual implementation:

- `BotMark` now separates surface ids from canonical visual identity and reactively resolves aliases to one stable `bot:<botId>` seed before shape/color/animation-engine hashing.
- Runtime Bot metadata (`bot.listed`, `bot.changed`, native `syncBatch`, `botChanged`, `botInvocationRequested`) establishes authoritative aliases for legacy conversation rows, self-hosted peers and Workbench cards.
- Existing `data-bot-id` remains unchanged for compatibility while `data-canonical-bot-id` records the resolved identity for diagnostics and visual tests.
- The existing Grok-style state machine remains driven by real Agent activity; identity normalization does not own or fake runtime state.

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

Current manual implementation:

- Native messaging already owns Bot profiles, Bot executions, conversations and messages and emits stable Bot/invocation identifiers.
- The active branch mirrors Workbench run/step/tool/approval/artifact projections, conversation recovery journal and self-hosted invocation idempotency claims through the existing native `readClientPersistence` / `writeClientPersistence` / `removeClientPersistence` boundary.
- Desktop bootstrap restores native projections before React constructs the Workbench/transport state; localStorage therefore remains a first-frame cache rather than the restart authority.
- Writes are content-deduplicated; failed native writes stay retryable; account reset deletes both renderer and native copies.
- Exact crash/restart/replay and duplicate-side-effect evidence is still required before `GBF-601/602` can be closed from this task.

### 5. Observable visual parity

Use the pinned reconstructed baseline as an observable reference for Messenger typography, spacing, hierarchy, streaming transitions, run cards, steps, tools, approvals, errors, final results and Bot motion. Produce representative screenshots/video/trace for idle, thinking, tool-running, approval, error and result states.

Provenance stays explicit: reimplement observable behavior and architecture in Fabushi-owned source. Do not wholesale vendor an unlicensed production renderer, brand assets or unknown-license resources.

### 6. Efficient long-running Agent execution policy

A later operating-guidance review added an efficiency requirement that maps directly onto existing Mahayana primitives without introducing another runtime.

- Prefer event triggers over cron/polling whenever a reliable event source can wake the task.
- Prefer connected Connector/MCP/API tools over browser/computer UI automation when they can perform the same action.
- When the agent is stalled or cannot make further useful progress, surface the blocker immediately and request the exact human input/action needed instead of silently burning more turns.
- Keep event filters narrow and preserve existing approvals for destructive/external/publish/send/delete/purchase/production-changing actions.
- The rule is provider-neutral and injected through the existing `modeStatement` path for every Mahayana chat turn.

Current implementation on `feat/gbf-efficient-agent-runs`:

- `frontend/apps/web/src/lib/fabushi-runtime/agent-utils.ts` defines `EFFICIENT_AGENT_RUN_POLICY` and appends it to `buildModeTransitionNote`.
- Existing `host-client.tsx` already sends `buildModeTransitionNote(...)` in every `chat.send`, so the policy reaches the canonical Mahayana runtime without a second tool router.
- Existing event/schedule automation, connector discovery, MCP and approval contracts are retained rather than duplicated.
- `frontend/apps/web/scripts/check-efficient-agent-policy.mjs` guards the four policy statements, mode-statement injection, event/schedule trigger availability and connector discovery.
- Source analysis/provenance: `source/2026-08-27-efficient-agent-run-policy.md`.
- PR/required CI/protected-main/post-main packaged evidence remains required before this slice is accepted as released.

## Manual changes in the active branch

- Removed `.github/workflows/chatgpt-auto-confirm-task-dispatch.yml`.
- Added canonical Bot visual-identity resolution to `frontend/apps/web/src/app/host/bot-mark.tsx`.
- Added runtime identity alias projection in `desktop/src/agent-identity-aliases.ts`.
- Added native durable Agent projection mirroring/restoration in `desktop/src/durable-agent-state.ts`.
- Updated `desktop/src/main.tsx` to restore durable state before rendering and install the identity/durability bridges.
- Extended the existing `assert-bot-mark-motion.py` gate to reject regressions that drop canonical identity or native restart/account-boundary persistence.

## Direct test evidence

The implementation is being exercised only by normal product/CI workflows, not by the forbidden auto-confirm runner.

- The canonical merge queue is enabled only for the manually implemented branch; the preceding GitHub Actions startup failures are infrastructure results, not accepted product evidence, so the normal required checks are being retriggered rather than bypassed.
- Messaging Product Gate on head `9e2b2e8f96158cadc385cc12a132525aa354203e`: `Rust self-hosted product` passed, including rustfmt, library/server tests, clippy, media queue tests and production Feature Host bridge checks.
- The same gate's `Electron Messenger contract` passed, including desktop dependency install, Feature Host architecture verification, self-hosted call-signaling policy, Native Edge parity and Messenger V2 TypeScript typecheck.
- GBF security closure on the same head passed.
- An earlier Electron gate exposed a real TypeScript narrowing problem in the new async bootstrap; it was fixed directly in source by passing the validated `HTMLDivElement` into the async bootstrap rather than suppressing the compiler.
- Full exact-main packaged desktop/mobile/release/update evidence is still pending and remains blocking.

## Acceptance gates

- Existing selectors/assertions/security gates are not weakened to obtain green CI.
- Relevant TypeScript, Rust, unit, integration, architecture and security suites pass.
- Exact-main packaged journeys pass on macOS, Windows and Linux; Android/iOS gates pass when shared contracts or surfaces are affected.
- Release assets come from the exact tested main SHA and include updater-compatible metadata.
- An already-installed older macOS client is proven to discover the new release.
- Project records for `GBF-501/601/602/703/801/802/803/804/805` are updated from objective evidence.

## Completion rule

`GBF-805` may be marked `RELEASED` only after every required closure above has objective evidence on canonical `main` and the exact tested release. Missing visual, persistence, entitlement, packaged E2E, update-discovery or provenance evidence is a blocker, not a documentation exception.


## 2026-09-03 parity round — session, true streaming, generated Mini App, energy

This continuation is sourced from `source/2026-09-03-session-streaming-miniapp-energy.md`. Completion now additionally requires all five reported user-visible failures to be closed in packaged builds:

1. mobile full-process relaunch restores the authenticated session through AAC-004's Keychain/Keystore-backed encrypted Rust store;
2. desktop avatar/profile navigation exposes `退出登录` directly and exercises the same canonical logout/cache-clear boundary;
3. OpenAI Responses, OpenAI-compatible Chat Completions and Anthropic providers request/consume SSE and emit multiple real `chat.delta` events before terminal completion rather than converting one completed body into a fake single delta;
4. Agent-produced self-contained Mini Apps become structured `miniApp` transcript artifacts, render an `打开小程序` action and reuse Fabushi's isolated Mini App surface across desktop/iOS/Android instead of exposing the final HTML as a JSON/code `<pre>`;
5. MSR-106 verifies current-main avatar motion is one shared 30 FPS scheduler with shared focus/visibility lifecycle and target-Mac packaged energy evidence.

Targeted unit/source/E2E regressions are part of this branch, but this task remains `IN_PROGRESS` until GitHub Actions, protected main, exact-main packaged/mobile/visual/energy evidence and Release are all green.
