# TFI-M7-P0-001 — group Bot mention/privacy/session/tool-result transport

- **Project ID / Key:** `FAB-P0001 / TFI`
- **Task ID:** `TFI-M7-P0-001`
- **Program:** `FAB-ARCH-P0-20260904`
- **Status:** `BLOCKED`
- **Owner:** Execution project group; TFI security reviewer required for fallback/security acceptance
- **Hard dependencies:** `TFI-M6-P0-005`, `MSR-210`, `MSR-211`, and `GBF-508` must **each** complete contract acceptance, independent code review `REVIEW-PASS`, protected canonical-main merge, every required CI check, and installable/packaged E2E plus Release evidence bound to that dependency's exact accepted canonical-main SHA. TFI-M7 does not inherit closure from GBF-508 prose and no dependency is satisfied by a review pass alone.
- **Current upstream blockers:** `MSR-201` and `MSR-202` are `in-progress`; `GBF-409` and `GBF-411` are `IN_PROGRESS`. Because this task explicitly depends on the resulting MSR/GBF contracts, those transitive foundations must also have their own complete contract acceptance + independent `REVIEW-PASS` + protected merge + required CI + exact accepted canonical-main packaged E2E/Release closure before MSR-210/MSR-211/GBF-508 can close. Pending states stay pending.
- **Parallel/prework:** transport fixtures/message schemas may be drafted while blocked only as `contract-only`; no integrated capability behavior, fallback path, or implementation closure may be submitted/accepted until every direct and required transitive dependency lineage above is complete.

## Objective
Implement the TFI transport/projection half of Grok-like group Bot behavior using the fully delivered clean-room GBF behavior contract and the single MSR runtime/policy plane.

## Exact implementation scope
- `native/mahayana-messaging/src/bot.rs`: Bot invocation/execution/result transport identity.
- `native/mahayana-messaging/src/service.rs`: group message -> directed Bot invocation projection, privacy trigger filtering only per the fully delivered GBF-508 contract.
- `native/mahayana-messaging/src/protocol.rs`: typed invocation/tool approval/progress/result/error envelope only as accepted by fully delivered M6-005/MSR-211.
- `desktop/src/messaging-shell-v2.tsx`: visible group Bot/tool-result projection.
- `frontend/apps/web/src/lib/mahayana-host/contracts.ts` and `electron-transport.ts`: Host reader/bridge only for accepted typed events.
- accepted external contracts: MSR-210 session, MSR-211 capability policy/result, GBF-508 behavior; no duplicated engine/policy implementation in TFI.

## Implementation steps
1. Record every direct dependency's exact accepted contract/review head, protected-main SHA, required CI and exact-main package/E2E/Release evidence; also record the completed MSR-201/MSR-202/GBF-409/GBF-411 foundation lineages that allowed MSR-210/MSR-211/GBF-508 to close.
2. Implement directed triggers only: explicit mention, reply-to-Bot, registered command/slash or GBF-approved directed signal; privacy-mode ambient group message must not invoke.
3. Preserve one Bot/one MSR session; group/conversation/topic are context scopes inside it.
4. Transport tool request/approval/progress/result/error with stable invocation/request correlation and visible provenance; no provider writes messages directly.
5. Enforce member/Bot permission decisions from MSR-211 fail closed.
6. Implement semantic -> Computer Use fallback only under the full predicate below; never downgrade an available-but-denied semantic action.
7. Prove group/topic/restart positive+negative paths and all capability/fallback policy preconditions.

## In scope
Group Bot message trigger/projection/typed result transport and UI visibility using fully delivered MSR/GBF contracts.

## Out of scope
Implementing session registry (MSR-210), capability policy (MSR-211), device/App MCP (GBF-409/411), clean-room behavior source (GBF-508), local build/test.

## Acceptance by category
- **Dependency gate:** M6-005, MSR-210, MSR-211 and GBF-508 each have accepted contract + independent `REVIEW-PASS` + protected canonical merge + required CI + exact-accepted-main installable/packaged E2E and Release evidence. Their unfinished foundations MSR-201/MSR-202/GBF-409/GBF-411 cannot be skipped. Missing any item leaves TFI-M7 BLOCKED.
- **Unit:** mention/reply/command/ambient trigger classifier, typed result rendering helpers, and fallback predicate covering semantic availability/denial, pairing/control, target/session/client/generation freshness, approval, install state and audit correlation.
- **Contract:** privacy-mode ambient ignore; directed positives; same Bot session context; stable invocation/result correlation; no direct provider->message bypass; fallback only when every predicate below is true.
- **Integration:** messaging service -> MSR-210 session -> MSR-211 policy/result -> GBF-508 behavior -> TFI projection with accepted versions/IDs; fallback carries stable invocation/request/audit correlation through the entire path.
- **E2E:** exact-main installable multi-user group/topic journey proves invocation and deliberate non-invocation, restart continuity, visible tool progress/result, semantic success, genuinely-unavailable semantic fallback success, and all mandatory fallback denial journeys.
- **Security:** approval deny/expire; account mismatch; unpaired/control-disabled device; target/session/client/generation stale or revoked; MiniApp unavailable/uninstalled or install state disallowing the fallback; semantic capability available-but-denied; missing audit/correlation — all fail closed. No ambient privacy leak and no Computer Use bypass.
- **Performance:** directed-trigger classification and typed projection add bounded local work; semantic path is preferred and fallback must not introduce retry storms, stale-target loops or message duplication.

### Capability fallback hard gate
Semantic/App/MiniApp -> Computer Use fallback is authorized **only if all conditions are simultaneously true**:
1. the semantic/App/MiniApp capability is **genuinely unavailable**, not merely present-but-denied by policy, permission, approval, account, install or provider state;
2. the target device belongs to the same account and is explicitly paired;
3. remote/local control for that paired device is enabled;
4. the device target, Mahayana/Bot session, client identity and capability generation are all current and none is stale or revoked;
5. every required approval is granted and unexpired for the correlated invocation/action;
6. the current MiniApp/install/enablement state explicitly permits the requested fallback semantics; unavailable/uninstalled/disabled state is not itself permission to use Computer Use;
7. the resulting fallback action is audited and correlated end-to-end with stable invocation/request/session/target/client/generation identities and visible provenance.

Approval denial/expiry, any stale/revoked device/target/session/client/generation, account mismatch, unpaired/control-disabled state, MiniApp/install state that does not allow the action, missing audit/correlation, or a semantic capability that is available-but-denied must **fail closed**. No fallback retry may reinterpret denial as unavailability.

## Test and Release handoff
- **Execution owner:** implements only after the full dependency closure gate; records branch/commit/PR and exact public contract versions.
- **Code review owner:** independently reviews the pushed real diff, including all fallback fail-closed branches; execution cannot self-award `REVIEW-PASS`.
- **Test/release owner:** on the exact accepted canonical-main SHA, runs required CI and installable packaged journeys for ambient-ignore, directed invocation, approval approve/deny/expire, semantic available+allowed, semantic available-but-denied, genuinely unavailable semantic fallback, account/pairing/control negatives, target/session/client/generation stale/revoked, MiniApp/install allow/disallow, audit/correlation and restart continuity. Release evidence must bind to the same exact SHA/package lineage.
- Any missing dependency or fallback evidence keeps this task BLOCKED; contract-only prework cannot be promoted to completion.

## Required write-back and evidence
Record every direct/transitive dependency lineage, branch/commit/PR/review/CI workflow-run-job/check/evidence/status/changelog in this file and cross-project records. Planned is not passed.

This task's own closure requires protected merge + required CI + exact-main installable package/E2E/Release evidence. Record exact main SHA/app version/platform/run+job/journey/timestamp/package/full video/step screenshots/trace/HTML-native report/logs; upload pass/fail on always-equivalent path; target 90 days or record lower maximum. Missing any prerequisite or own item blocks pass.

## Execution fields
Branch: `blocked`; Commit: `pending`; PR: `pending`; CI: `pending`; Evidence: `pending`; Review: `pending`; Canonical-main/package/release: `pending`.
