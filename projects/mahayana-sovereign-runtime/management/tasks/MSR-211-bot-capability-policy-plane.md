# MSR-211 — unified Bot capability discovery/policy/result plane

- **Project ID / Key:** `FAB-P0005 / MSR`
- **Task ID:** `MSR-211`
- **Program:** `FAB-ARCH-P0-20260904`
- **Status:** `BLOCKED`
- **Owner:** Execution project group; security reviewer required for policy/approval/fallback paths
- **Hard dependencies:** `MSR-202`, `MSR-210`, `GBF-409`, and `GBF-411` must **each** independently complete all of the following before MSR-211 integration or acceptance: (1) contract acceptance, (2) independent code review `REVIEW-PASS`, (3) protected canonical-main merge, (4) every required CI check for that accepted lineage, and (5) installable/packaged E2E plus Release evidence bound to the exact accepted canonical-main SHA. Review acceptance, source presence, a downstream pass, or prose saying “reuse existing” is never sufficient.
- **Current dependency facts:** `MSR-202` is `in-progress` with commit/PR/CI pending; `MSR-210` remains BLOCKED until `MSR-201` completes its own full delivery lineage; `GBF-409` and `GBF-411` are `IN_PROGRESS` with required GitHub CI/E2E/exact-main delivery evidence pending. Therefore MSR-211 remains BLOCKED.
- **Transitive foundation truth:** because MSR-210 cannot close before MSR-201, the MSR-201 contract/review/protected-merge/required-CI/exact-main packaged E2E/Release lineage must also be recorded before MSR-210 can count as a satisfied MSR-211 dependency.
- **Parallel/prework:** descriptor schema, threat model and test vectors may be drafted only as `contract-only` work while blocked; provider/device/App-MCP integration code may not be submitted, accepted, or claimed complete until every direct dependency's complete lineage is recorded.

## Objective
Make every Bot discover/invoke allowed same-account device and installed MiniApp capabilities only through one MSR catalog/policy/approval/audit/result plane.

## Exact implementation scope
- `third_party/mahayana/mahayana-rs/mahayana-kernel/src/supervisor.rs`: approval, permission memory, loop/fail-closed policy primitives from the fully delivered MSR-202 lineage.
- `third_party/mahayana/mahayana-rs/mahayana-native-engine/src/lib.rs`: capability catalog exposure, invocation correlation, result/progress/error envelope, model-facing filter.
- `third_party/mahayana/mahayana-rs/mahayana-computer/src/lib.rs`: authorized Computer Use executor; its own contract says caller is responsible for consent/auth/policy/audit, so MSR-211 must guard before invocation.
- existing Host/capability bridge consumers such as `desktop/electron/host-process.cjs`, `desktop/electron/native-capability-handlers.cjs`, and `frontend/apps/web/src/lib/mahayana-host/contracts.ts` only through fully delivered GBF-409/411 interfaces.
- focused kernel/native-engine policy/catalog/result tests.
No provider gets a direct message-posting or policy-bypass path.

## Implementation steps
1. Record for MSR-202, MSR-210, GBF-409 and GBF-411 the exact accepted contract/review head, protected canonical-main SHA, required CI run/checks and exact-main installable/package E2E plus Release evidence; also record MSR-201's completed lineage behind MSR-210.
2. Normalize MCP/WebMCP/App MCP/MiniApp CLI/native Computer Use descriptors into stable capability descriptors.
3. Filter model exposure by account, installed MiniApp, device pairing/control, current target/session/client/generation and policy state.
4. Route mutating/sensitive calls through the fully delivered MSR-202 approval class; deny, expire, interruption or missing approval fails closed.
5. Emit stable invocation id/provider/tool/provenance with redacted progress/result/error; no provider directly posts chat messages.
6. Reject revoked/stale device/target/session/client/generation, unavailable/uninstalled MiniApp, duplicate/replayed invocation and secret leakage.
7. Prefer semantic capabilities. Use Computer Use fallback only when semantic capability is genuinely unavailable—not merely denied—and all account/pairing/control/target/session/client/generation/install/approval/audit checks independently pass.

## In scope
Capability normalization, discovery filter, MSR policy/approval gate, result envelope, semantic/fallback routing contract.

## Out of scope
Implementing GBF-409/411 themselves, Bot session mapping (MSR-210), TFI group transport/rendering, bypassing OS/device permissions, local build/test.

## Acceptance by category
- **Dependency gate:** MSR-202, MSR-210, GBF-409 and GBF-411 each have accepted contract + independent `REVIEW-PASS` + protected canonical merge + required CI + exact accepted canonical-main installable/packaged E2E and Release evidence; MSR-201 has the same full closure before MSR-210. Missing any item leaves MSR-211 BLOCKED.
- **Unit:** descriptor normalization/filter, stale/revoke/availability, invocation idempotency, fallback predicate and redaction units.
- **Contract:** allowed/denied discovery; approval approve/deny/expire; revoked/stale device/target/session/client/generation; unavailable/uninstalled MiniApp; duplicate invocation; provider failure; result correlation; no provider->message bypass; available-but-denied semantic capability never becomes fallback-eligible.
- **Integration:** fully delivered GBF-409/411 catalog/device/App MCP -> MSR policy -> provider -> result envelope; TFI consumes typed result without provider side channel.
- **E2E:** exact-main installable Bot journey includes allowed semantic action and explicit denied/expired/revoked/stale/unavailable paths; fallback journey proves genuine semantic unavailability, current allowed MiniApp/install state, current target/session/client/generation and correlated audit before authorized Computer Use.
- **Security:** fail closed on missing/deny/expire approval, account mismatch, unpaired/control-disabled device, revoked/stale target/session/client/generation, MiniApp/install state that disallows action, missing audit/correlation, or semantic capability available-but-denied; secure inputs/secrets redacted.
- **Performance:** capability filtering/routing is bounded and cached only with generation-safe invalidation; record catalog/invocation overhead and ensure fallback has no retry storm/duplicate mutation.

## Provenance gate
Any actual Codex/Grok Build adaptation records exact upstream repo/file/revision/license/NOTICE/attribution/local destination/adaptation note in this task/evidence. Architecture pin is insufficient. Reconstructed Grok Bot implementation code is forbidden; observable clean-room anchors only.

## Required write-back and evidence
Record each prerequisite's exact accepted contract/review head, protected-main SHA, required CI and exact-main package/E2E/Release evidence, then this task's actual branch/commit/PR/review/CI workflow-run-job/check/evidence/status/changelog here and cross-project records. Planned/pending is not passed.

This task's own closure requires protected canonical merge, required CI and exact-main installable package/E2E/Release evidence: main SHA, app version, platform, run/job, journey ID, timestamp, package, complete video, step screenshots, trace, HTML/native report, logs; pass/fail always-equivalent upload; target 90 days or recorded lower maximum. Missing any prerequisite or own item blocks pass.

## Execution fields
Branch: `blocked`; Commit: `pending`; PR: `pending`; CI: `pending`; Evidence: `pending`; Review: `pending`; Canonical-main/package/release: `pending`.
