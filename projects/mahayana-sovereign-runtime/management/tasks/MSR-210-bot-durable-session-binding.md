# MSR-210 — canonical Bot identity -> one durable Mahayana session

- **Project ID / Key:** `FAB-P0005 / MSR`
- **Task ID:** `MSR-210`
- **Program:** `FAB-ARCH-P0-20260904`
- **Status:** `BLOCKED`
- **Owner:** Execution project group
- **Hard dependency:** `MSR-201` is complete for MSR-210 only after: contract acceptance; independent code review `REVIEW-PASS`; protected canonical-main merge; every required CI check for that accepted lineage; and installable/packaged E2E plus Release evidence tied to the exact accepted canonical-main SHA. `REVIEW-PASS` or source presence alone is not sufficient.
- **Current dependency fact:** canonical `MSR-201` is `in-progress` on `feat/msr-native-runtime-parity`; commit/PR/CI are pending, so the full dependency gate is not satisfied.
- **MSR-202 relation:** MSR-202 is not a hard dependency for the session-binding implementation defined here. If any implementation change crosses into approval/policy/capability semantics owned by MSR-202/MSR-211, stop and add MSR-202 as a hard prerequisite with the same complete closure gate before editing that scope.
- **Parallel/prework:** while blocked, source reading, public API design and test-vector drafting are contract-only; runtime integration code may not be submitted, accepted, or claimed complete until the full MSR-201 delivery lineage is recorded.

## Objective
Provide one authoritative, idempotent mapping from canonical Bot identity to exactly one durable Mahayana session, reusing fully delivered MSR recovery semantics rather than creating a second registry/runtime.

## Exact implementation scope
- `third_party/mahayana/mahayana-rs/mahayana-native-engine/src/lib.rs`: existing session state/engine ownership and create/open/resume path.
- `third_party/mahayana/mahayana-rs/mahayana-kernel/src/lib.rs`: public session identity/snapshot contracts only if the mapping must be exposed provider-neutrally.
- `third_party/mahayana/mahayana-rs/mahayana-kernel/src/supervisor.rs`: fully delivered recovery/suspension semantics only; do not duplicate MSR-201.
- `third_party/mahayana/mahayana-rs/mahayana-agent-kernel-bridge/src/lib.rs`: Bot/agent bridge consumer if current canonical path requires mapping exposure.
- integration consumers are `native/mahayana-messaging/src/bot.rs` and `desktop/src/miniapp-bot-projection.ts`; cross-project changes belong to their TFI tasks unless a reviewed interface patch is explicitly necessary.
- focused MSR native-engine/kernel conformance tests.
If implementation needs a new MSR source file, update this task with that exact path **before editing** and include it in code review; this task does not authorize a parallel database/registry.

## Implementation steps
1. Wait for and record the full MSR-201 lineage: accepted contract/review head, protected canonical-main SHA, required CI and exact-main installable/package E2E plus Release evidence.
2. Trace current session open/snapshot/restore/reclaim keys and define a stable canonical Bot identity key without vendor types.
3. Implement create-or-get/idempotent mapping using the existing durable session authority; restart/reopen returns the same session.
4. Direct chat/group/channel/topic attach context scopes to the same Bot session; two Bots remain isolated.
5. MiniApp install/reinstall/update reuses the mapping; delete/disable/uninstall lifecycle is explicit and cannot leave an executable hidden orphan.
6. Reuse fully delivered MSR-201 interruption/recovery; concurrent turns preserve correlation without duplicate user input.
7. Add conformance and cross-project integration tests.

## In scope
Bot identity/session mapping, lifecycle, restart/idempotency/context and integration contract.

## Out of scope
Capability discovery/policy (MSR-211), TFI renderer/projection implementation, GBF behavior, second session store, upstream adaptation unless separately provenanced, local build/test.

## Acceptance by category
- **Dependency gate:** MSR-201 has contract acceptance + independent `REVIEW-PASS` + protected canonical merge + required CI + exact accepted canonical-main installable/packaged E2E and Release evidence. Missing any item means MSR-210 remains BLOCKED.
- **Unit:** stable-key mapping, create-or-get idempotency, two-Bot isolation, lifecycle state transitions.
- **Contract:** one Bot -> one durable session across restart, two conversations/group/topic contexts, MiniApp update/reinstall and fully delivered MSR-201 recovery semantics.
- **Integration:** native engine/kernel bridge + TFI Bot identity consumer uses the same mapping; interrupted/reclaimed turn resumes without duplicate input.
- **E2E:** exact-main installable MiniApp install -> Bot visible/chat -> close/relaunch -> same Bot/session; direct/group context continuity where dependent TFI slice is available.
- **Security:** malformed/forged Bot identity cannot alias another Bot/account; disabled/uninstalled state cannot silently execute hidden session work.
- **Performance:** create-or-get/reopen must use durable local state without unbounded scan/network wait; record mapping/reopen timing and no startup regression in packaged evidence.

## Provenance gate
If implementation actually adapts Codex/Grok Build code, record exact upstream repo/file/revision/license/NOTICE/attribution/local destination/adaptation note here and in evidence. MSR-107 architecture pins alone are insufficient. Unclear rights => do not use.

## Required write-back and evidence
Record MSR-201 exact accepted contract/review head, protected-main SHA, required CI and exact-main package/E2E/Release evidence, then this task's branch/commit/PR/review/CI workflow-run-job/check/evidence/status/changelog and cross-update MSR/TFI dependency records. Planned is not passed.

This task's own closure additionally requires protected canonical merge, required CI and exact-main **installable** packaged evidence: SHA, app version, platform, workflow run/job, journey ID, timestamp, package artifact, full video, step screenshots, trace, HTML/native report, logs; pass+fail always-equivalent upload; 90-day target or recorded lower maximum. Missing prerequisite or own item blocks pass.

## Execution fields
Branch: `blocked`; Commit: `pending`; PR: `pending`; CI: `pending`; Evidence: `pending`; Review: `pending`; Canonical-main/package/release: `pending`.
