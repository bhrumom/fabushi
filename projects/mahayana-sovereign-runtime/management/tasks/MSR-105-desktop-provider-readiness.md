# MSR-105 — Desktop provider readiness and managed workspace bootstrap

- **Project ID:** FAB-P0005
- **Project Key:** MSR
- **Task ID:** MSR-105
- **Status:** in-progress
- **Started:** 2026-08-24T08:11:00+08:00
- **Updated:** 2026-09-18T10:36:00+08:00
- **Completed:** null

## Objective
Eliminate first-turn cold-start failures **and first-turn provider/session startup latency** by making product-owned runtime prerequisites explicit and deterministic before the provider is allowed to serve requests. The original 2026-08-24 slice fixed the missing managed workspace; the 2026-09-18 continuation requires the real Mahayana provider session to be started during authenticated Host readiness rather than by the user's first `chat.send`.

## Reference implementation review
Cloudflare OS was reviewed as an architecture reference. Its AI backend centralizes model/provider routing behind typed handles and keeps routing/auth details out of callers. Fabushi should adopt the same class of boundary: initialize and validate runtime-owned prerequisites once at the host boundary, keep provider internals behind product-owned contracts, and surface deterministic failures instead of raw operating-system errors. Cloudflare OS is service/Workers oriented, so its implementation is a design reference rather than a literal Electron sidecar template.

## Root cause
The desktop app host configures the native runtime data directory under `feature-host/runtime`. When no explicit workspace is selected, `mahayana-host` derives the product-owned fallback workspace as `feature-host/runtime/workspace`. The first native Agent session canonicalizes that path. A fresh app-data directory did not create the fallback workspace before the first message, so path canonicalization returned OS error 2 and the error propagated through the Agent/provider layers to the conversation UI.

## In scope
- Create the product-owned desktop fallback workspace before `UnifiedAppHost` initialization.
- Never create arbitrary user-selected workspace paths implicitly.
- Add a deterministic regression test for the managed runtime layout.
- Verify the exact branch through CI before merge.
- Record PR, CI, merge and canonical-main evidence before task closure.

## Out of scope
- Retrying filesystem/configuration errors as if they were transient provider failures.
- Silently falling back to a test backend.
- Creating missing user-selected workspaces.
- Changing model credentials or provider routing.

## Acceptance criteria
1. A fresh desktop app-data directory creates `feature-host/runtime/workspace` before the native host starts.
2. The first native Agent session no longer fails because the product-owned fallback workspace is absent.
3. User-selected workspaces remain explicit inputs and are not auto-created by this bootstrap.
4. Regression coverage runs in CI.
5. The change is merged only after required checks pass and canonical `main` is verified.

## Verification
`cargo test -p mahayana-app-host-desktop --profile ci` plus repository fast checks on the exact PR head. Release/E2E packaging remains governed by the repository merge-to-main pipeline.

## Branch / commit / PR
Branch: `fix/msr-105-desktop-provider-readiness`
Initial implementation commit: `4936c3c65869be9cbfc4411368115a0e06cddfaf`
PR: #2081

## Implementation summary
Desktop startup now explicitly creates the runtime-owned fallback workspace before constructing `UnifiedAppHost`. The bootstrap is intentionally limited to the application-owned runtime path. This moves filesystem readiness to the lifecycle boundary instead of allowing an OS-level `ENOENT` to escape during the user's first chat request.

## Evidence
PR #2081 is open and mergeable. Exact-head CI had not yet appeared at the first post-PR status read; merge remains blocked until required checks complete.

## Next action
Run required CI on the exact #2081 head, inspect any failures, and merge only after the branch is green.


## 2026-09-18 continuation — real first-turn readiness

### Source
- `projects/mahayana-sovereign-runtime/source/2026-09-18-msr-105-first-turn-readiness.md`
- User-visible symptom: after launch the Messenger can be visible, but the first submitted Mahayana message waits while the underlying Agent provider/session starts.

### Verified root cause
The current Rust runtime constructs the Host and provider registry eagerly, but `KernelConversationProvider::session_id()` calls `EngineBackend::open_session()` lazily from `send_message()`. For the compatibility bridge, `LegacyAgentKernelBridge::open_session()` calls the backend's real `start_thread()`. Therefore the first user turn can pay provider process/thread/session cold-start cost even though the UI has already rendered.

The desktop composer already disables `messenger-send` while `hostReady=false`; the defect is that Host readiness did not include this provider-session boundary.

### Open-source-first decision
- OpenAI Codex `7498521d288b9b3b96ffba4eedf089d8d6e06a84`: session startup parallelizes independent initialization to reduce startup latency.
- xAI Grok Build `a28ee2b2063426e8816e380ccea528b9de95e5da`: documented Agent lifecycle explicitly initializes and creates the session before sending prompts.
- Decision: adapt the lifecycle, not code. Mahayana adds an idempotent provider-neutral warmup contract and keeps the implementation inside Fabushi-owned Rust boundaries.

### Implementation in this continuation
Branch: `fix/msr-105-first-turn-readiness`

- `mahayana-conversation::ConversationProvider` gains a default idempotent `warmup(conversation_id)` contract.
- `KernelConversationProvider` implements warmup by opening/reusing the exact same session used by `send_message`; no prompt is submitted and no transcript row is created.
- `MahayanaRuntime::warmup_conversation` and `MahayanaHost::warmup_conversation` expose the readiness boundary without introducing a second executor.
- `FeatureHostController::ensure_account_boundary` warms the real Mahayana assistant session whenever a production account is authenticated. This covers restored sessions plus fresh password, browser and OAuth login because all of those paths converge on the same account-boundary method.
- Because authenticated Host creation/login does not return until warmup succeeds, the existing renderer `hostReady`/send-button gate now represents real provider-session readiness rather than process-only readiness.
- Added a Rust regression proving repeated warmup opens exactly one Agent thread and the first visible message reuses it.

Implementation commits so far:
- `0140d7d01f3374d85c27bcfdf3981146cad23fe2`
- `4b1437677bdfc4a56eaeed1066f578d612041420`
- `cf43d87938654be37107e64d297cab4ad300a4c0`
- `f058c6c3697e6e7fe6e7250dce40aa36b3c7efbe`
- `2f14f90a8b1bde442cb0423afbfe73c624f62377`
- `6e966e26e4e176bb874090db8ab0a9ad4083a0f7`
- `77ea970a44b090879683b1eb54dfece2e8c7b689`

### Acceptance for this continuation
1. Authenticated Host readiness opens the actual Mahayana assistant provider session before the first `chat.send`.
2. Fresh login and restored-session startup use the same readiness path.
3. Warmup sends no model prompt and creates no visible transcript content.
4. Repeated readiness checks are idempotent and do not create duplicate Agent threads.
5. The first user message reuses the warmed session.
6. Required non-behavioral compile/quality checks must pass on the exact PR head before protected merge.
7. No behavioral/E2E test is implied by this change unless explicitly requested by the user under the current repository test policy.

### Current state
Implementation is staged on the branch; exact-head GitHub CI, PR review/protected merge and canonical-main readback are pending. The task remains `in-progress` and must not be reported as completed before those gates close.
