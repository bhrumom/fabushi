# FCM-010.13.11 independent exact-head review — PR #2561

- Repository: `bhrumom/fabushi`
- Project/task: `FAB-P0003 / FCM-010.13.11`
- Product PR: `#2561` — `fix(fcm): restore production assistant unread transition`
- Reviewed exact product head: `2e65a0a6de736d11774895938989232b376c6ed6`
- Reviewed authoritative protected-main integration context: `4c107bfcd1336972d72a51f909c6d21c4eb68d42`
- Product/main merge base observed during review: `b8fb73466899adc912db67823a8e429987070a6b`
- Review date: `2026-09-12`
- Disposition: **REVIEW-PASS**
- Blocking counts: **P0=0 / P1=0 / P2=0 / other-blocking=0**

This is an independent records-only review. It does not modify the product PR head, product/test/workflow/dependency/version code, mark the product PR ready, merge anything, create a Release, dispatch production E2E, or rerun already-green PR-side CI. Any change to the reviewed product head, the authoritative main integration context, or a relevant task/spec contract invalidates this verdict and requires a fresh review.

## 1. GitHub truth and exact-head CI readback

At writeback, PR #2561 was still `open`, `draft=true`, `merged=false`, `mergeable=true`, with exact head `2e65a0a6de736d11774895938989232b376c6ed6`. Authoritative `main` was reread as exact `4c107bfcd1336972d72a51f909c6d21c4eb68d42`.

The product branch is 14 commits ahead and 4 commits behind current main from merge base `b8fb73466899adc912db67823a8e429987070a6b`; therefore this review separately checked the PR implementation and its integration against all current main-only movement.

Existing PR-side workflows were read only and were not rerun. The exact head has ten completed/success runs: Project portfolio governance `34699501409`, CI `34699501410`, Explicit automerge `34699501445`, Delivery governance contract `34699501427`, CI latency observability `34699501494`, Mahayana Vendor Isolation `34699501442`, Host fast E2E `34699501397`, Mahayana fast checks `34699501551`, Global Dharma Rust `34699501525`, and Electron desktop quality gate `34699501388`. Electron desktop quality gate built the native Host and passed its real Linux Rust-Host pre-package user journey; main-only packaged delivery steps remained skipped on the PR path and are not treated as production acceptance.

## 2. Production unread/read-boundary ownership

`KernelConversationProvider` now owns unread/read-boundary state through `ConversationState { history, read_through }`.

- Persisted history starts read because `ConversationState::new` initializes `read_through = history.len()`.
- `Conversation::unread_count` counts only assistant-role messages after `read_through` for the Mahayana assistant conversation.
- A visible user send is appended to transcript history but does not increase unread.
- A visible assistant completion is recorded before the runtime completion event is emitted, is persisted, and increases unread until the explicit read boundary.
- `SendMessageRequest.hidden` is propagated into `RuntimeKernelEventBridge`. Hidden assistant completions still emit `RuntimeEvent::MessageCompleted` for their owning FeatureHost path, but `record_assistant_completion(..., hidden=true)` returns without appending to `ConversationState.history`; hidden prompts are also not appended. Consequently hidden completions do not enter the provider-visible transcript, are not persisted by this provider, and cannot increment `Conversation.unread_count`.
- `reset_session` resets the backend/session, clears visible history, marks the empty state read, and persists that reset.

FeatureHost additionally routes tracked group/background deltas/completions to `Group*` / `AgentBackground*` events instead of ordinary chat events. The prior P2 finding was specifically that hidden completions polluted `KernelConversationProvider` history/persistence/unread despite those caller-specific events; the exact head closes that defect at the production state owner rather than only in a mock.

## 3. Explicit-open 200 versus background-clamped 500 compatibility shim

The compatibility shim was validated against the current production call chain, not just comments/tests:

- FeatureHost production `conversation.open` executes `RuntimeCommand::ConversationHistory { limit: Some(200) }`.
- FeatureHost background conversation indexing executes `ConversationHistory { limit: Some(2_000) }`.
- Current `MahayanaRuntime` clamps every history request with `limit.unwrap_or(50).clamp(1, 500)`, so the background index reaches the provider as `500`, while explicit open remains `200`.
- `KernelConversationProvider::history` marks read only when the provider-visible limit equals `200`; `500` does not mark read.
- None of the current main-only commits changes FeatureHost conversation history callers, Runtime history clamping, or the kernel provider contract.

This remains a deliberately narrow compatibility shim. A new caller that can also reach the provider with `200`, or a change to the current `2000 -> clamp 500` background contract, is relevant spec movement and invalidates this review.

## 4. Electron authoritative list refresh and lifecycle/race review

The exact-head Electron transport refreshes authoritative `conversation.list` after:

1. an accepted non-Mini-App `conversation.open`; and
2. an assistant `chat.message` completion.

The ordering is safe under the current production transport:

- explicit open performs its synchronous Runtime history read/read-ack in FeatureHost before the accepted response returns, then Electron schedules the list refresh;
- the provider records/persists a visible assistant completion before emitting its runtime completion, so the assistant-triggered list refresh observes incremented unread state;
- renderer IPC can issue multiple promises, but all `feature.execute` calls are written to one `MahayanaHostProcess` stdin, and the desktop Rust app-host consumes `stdin.lock().lines()` and dispatches requests sequentially. This prevents concurrent Host execution from returning an older list snapshot after a newer one;
- transport close unsubscribes runtime/command/reset observers and gates refresh on `closed`;
- account identity changes call Runtime `reset_session()` before replacing account-owned FeatureHost state; Runtime resets providers, clears operation/approval tracking and drains queued runtime events, while the renderer account-reset path discards/clears its conversation journal. This prevents queued old-account replies from repopulating new-account state;
- operation/request mappings preserve conversation identity for assistant messages, and repeated renderer delivery can cause an extra refresh but cannot double-increment provider unread because unread is changed at the single kernel completion state transition, not by renderer refresh.

No deadlock, mutex reentrancy, stale account persistence, or late-completion authorization issue was found in the reviewed path.

## 5. Regression fidelity

The Rust regressions exercise the production `ConversationState` helper used by `RuntimeKernelEventBridge`, including persisted-history-starts-read, user-message non-unread behavior, visible assistant unread increments, hidden assistant completion isolation, and `200` read / `500` no-read behavior.

The TypeScript regression instantiates the real `ElectronMahayanaHostTransport`, installs its real command/runtime observer path on an `EventTarget`, executes real transport `conversation.open` and `chat.send` commands through the bridge contract, injects the runtime `chat.message` through the subscribed observer, and asserts both authoritative list refreshes. It mocks only the native invocation boundary; it does not replace transport observer/mapping logic with a separate test implementation.

Cross-layer confidence is provided by the exact-head Electron quality gate and Mahayana fast gate: production FeatureHost adapters/direct Host tests pass, the native Host is built, and a real Linux Rust-Host user journey passes. These PR checks are not substituted for post-merge packaged production acceptance.

## 6. Open-source-first blocker closure

`projects/fabushi-cicd-merge-governance/evidence/2026-09-12-fcm-010-13-11-unread-open-source-survey.md` closes the prior P1 finding. It surveys Matrix Rust SDK, Signal Desktop, and Mattermost across architecture, API/data model, testing, operational edge cases, security/privacy, maintenance, license/provenance, compatibility, and reuse/adapt/reject decisions. It explicitly documents why upstream concepts are adapted rather than copied and why the numeric `200/500` distinction is a local compatibility shim, not a generalized architecture.

## 7. Current-main integration review

Current main is four commits ahead of the product branch merge base:

- `7ccd77fe6ba320706a28db95fb292243acc1660a` — records the fresh exact-main unread production failure;
- `9785d8e1b71e0d61cf31541af28b910d5be58bd9` — Chrome screenshot/Web Store delivery hardening;
- `75d9105549a8cd99fb5b691bb36b5817d04e5579` — Chrome screenshot surface fallback;
- `4c107bfcd1336972d72a51f909c6d21c4eb68d42` — CWA-007 same-account official Chrome browser agent/device-gateway integration.

No main-only commit overlaps the #2561 product implementation paths. The Web Store/post-main delivery change is additive and retains exact-source/provenance validation rather than weakening FCM Release lineage.

CWA-007 adds a separate authenticated `/browser-agent` WebSocket route and Chrome devices registered as `chrome-<uuid>` / platform `chrome-extension`. The production FCM controller still computes and selects only the exact App-owned device `gha-<run>-<attempt>-macos-app`, using exact device-id equality for every remote call. The normal `/agent` path remains, and the shared lease change falls back to the prior max for sockets without a browser-specific override. Therefore the added Chrome device population cannot satisfy or replace the FCM exact App-owned-device gate and does not change the reviewed production journey/evidence/control semantics.

## 8. Fail-closed FCM gates preserved

The PR does not modify the production controller, Release/version/workflows, remote MCP/device contract, or acceptance evidence gates. Project records continue to require all of the following after protected merge: `fabushi.app.find limit<=100`; stale-generation semantic re-resolution; exact semantic identity/name; immutable same-source Release; exact fresh App-owned device; all 27 categories; nonzero real remote actions; `READY_FOR_LOGOUT PASS -> ci_session_finish -> fresh App snapshot -> exact settings-logout`; truthful evidence; playable whole-session video; trace/screenshots/logs; artifact digest and source lineage.

The latest canonical failure record also remains fail-closed: target `34696426684/1` is not reusable acceptance evidence, and `FCM-010.13.11` / `FCM-010.13` remain incomplete until a newly merged canonical SHA produces a new immutable Release and a new controller-dispatched frozen-source production target that passes all downstream gates.

## Non-blocking record note

Some task-record prose on the product branch still conservatively says exact-head CI was pending at the time that prose was written. GitHub now proves the unchanged exact head has all ten PR-side workflows completed/success. The stale wording does not authorize merge, claim task completion, or weaken a gate; this independent record is the current review evidence. It is therefore recorded as non-blocking rather than silently treated as current CI truth.

## Verdict

**REVIEW-PASS** — `P0=0 / P1=0 / P2=0 / other-blocking=0` for repository `bhrumom/fabushi`, PR `#2561`, task `FAB-P0003 / FCM-010.13.11`, exact product head `2e65a0a6de736d11774895938989232b376c6ed6`, reviewed against authoritative protected-main integration context `4c107bfcd1336972d72a51f909c6d21c4eb68d42`.

This verdict authorizes only the next protected merge-governance decision for this exact binding. It does not itself ready/merge/release/dispatch the product PR and does not satisfy post-merge production acceptance. Any relevant head/main/spec movement invalidates it.