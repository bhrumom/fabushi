# TFI-M7-P0-001 — group Bot mention/privacy/session/tool-result transport

- **Project ID / Key:** `FAB-P0001 / TFI`
- **Task ID:** `TFI-M7-P0-001`
- **Program:** `FAB-ARCH-P0-20260904`
- **Status:** `BLOCKED`
- **Owner:** Execution project group
- **Hard dependencies:** `TFI-M6-P0-005 REVIEW-PASS`, `MSR-210 REVIEW-PASS`, `MSR-211 REVIEW-PASS`, `GBF-508 REVIEW-PASS`.
- **Current upstream blockers:** `MSR-201` and `MSR-202` are `in-progress`; `GBF-409` and `GBF-411` are `IN_PROGRESS`; therefore MSR-210/211 and GBF-508 cannot yet satisfy this closure gate.
- **Parallel/prework:** transport fixtures/message schemas may be drafted against project specs while blocked, but no integrated capability behavior may be submitted/accepted until exact dependent contracts are review-passed.

## Objective
Implement the TFI transport/projection half of Grok-like group Bot behavior using the accepted clean-room GBF behavior contract and the single MSR runtime/policy plane.

## Exact implementation scope
- `native/mahayana-messaging/src/bot.rs`: Bot invocation/execution/result transport identity.
- `native/mahayana-messaging/src/service.rs`: group message -> directed Bot invocation projection, privacy trigger filtering only per accepted GBF-508 contract.
- `native/mahayana-messaging/src/protocol.rs`: typed invocation/tool approval/progress/result/error envelope only as accepted by M6-005/MSR-211.
- `desktop/src/messaging-shell-v2.tsx`: visible group Bot/tool-result projection.
- `frontend/apps/web/src/lib/mahayana-host/contracts.ts` and `electron-transport.ts`: Host reader/bridge only for accepted typed events.
- accepted external contracts: MSR-210 session, MSR-211 capability policy/result, GBF-508 behavior; no duplicated engine/policy implementation in TFI.

## Implementation steps
1. Record exact accepted dependency heads/PRs and re-read their public contracts.
2. Implement directed triggers only: explicit mention, reply-to-Bot, registered command/slash or GBF-approved directed signal; privacy-mode ambient group message must not invoke.
3. Preserve one Bot/one MSR session; group/conversation/topic are context scopes inside it.
4. Transport tool request/approval/progress/result/error with stable invocation/request correlation and visible provenance; no provider writes messages directly.
5. Enforce member/Bot permission decisions from MSR-211 fail closed.
6. Prove group/topic/restart positive+negative paths and all capability policy preconditions.

## In scope
Group Bot message trigger/projection/typed result transport and UI visibility using accepted MSR/GBF contracts.

## Out of scope
Implementing session registry (MSR-210), capability policy (MSR-211), device/App MCP (GBF-409/411), clean-room behavior source (GBF-508), local build/test.

## Acceptance by category
- **Unit:** mention/reply/command/ambient trigger classifier and typed result rendering helpers.
- **Contract:** privacy-mode ambient ignore; directed positives; same Bot session context; stable invocation/result correlation; no direct provider->message bypass.
- **Integration:** messaging service -> MSR-210 session -> MSR-211 policy/result -> GBF-508 behavior -> TFI projection with accepted versions/IDs.
- **E2E:** exact-main installable multi-user group/topic journey proves invocation and deliberate non-invocation, restart continuity and visible tool progress/result.
- **Security:** **mandatory** approval deny/expire, revoked/stale device, MiniApp unavailable and unauthorized capability all fail closed; no ambient privacy leak.
- **Performance:** directed-trigger classification and typed projection add bounded local work; semantic capability path is preferred and fallback must not introduce retry storms or message duplication.

### Capability fallback hard gate
Semantic-to-Computer-Use fallback may be exercised **only** when `MSR-211 REVIEW-PASS` and `GBF-508 REVIEW-PASS` prove: semantic/App/MiniApp capability is genuinely unavailable; device is same-account and paired; control is enabled; target/session/generation are current; required approval is granted and unexpired; revoked/stale/deny/expire fails closed. Computer Use is never a bypass for an available-but-denied semantic capability.

## Required write-back and evidence
Record every accepted dependency head/contract, branch/commit/PR/review/CI workflow-run-job/check/evidence/status/changelog in this file and cross-project records. Planned is not passed.

Closure requires this task's own protected merge + CI + exact-main installable package/E2E/Release evidence. Record exact main SHA/app version/platform/run+job/journey/timestamp/package/full video/step screenshots/trace/HTML-native report/logs; upload pass/fail on always-equivalent path; target 90 days or record lower maximum. Missing any item blocks pass.

## Execution fields
Branch: `blocked`; Commit: `pending`; PR: `pending`; CI: `pending`; Evidence: `pending`; Review: `pending`; Canonical-main/package/release: `pending`.
