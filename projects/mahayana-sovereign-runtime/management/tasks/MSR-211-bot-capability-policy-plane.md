# MSR-211 — unified Bot capability discovery/policy/result plane

- **Project ID / Key:** `FAB-P0005 / MSR`
- **Task ID:** `MSR-211`
- **Program:** `FAB-ARCH-P0-20260904`
- **Status:** `BLOCKED`
- **Owner:** Execution project group
- **Hard dependencies:** `MSR-202 REVIEW-PASS`, `MSR-210 REVIEW-PASS`, `GBF-409 REVIEW-PASS/accepted contract`, `GBF-411 REVIEW-PASS/accepted contract`.
- **Current dependency facts:** MSR-202 is `in-progress` with commit/PR/CI pending; MSR-210 is blocked on MSR-201; GBF-409 and GBF-411 are `IN_PROGRESS` with required GitHub CI/E2E/exact-main delivery evidence pending.
- **Parallel/prework:** descriptor schema, threat model and test vectors may be drafted while blocked; provider/device/App-MCP integration code may not be submitted/accepted until all exact dependency heads are recorded.

## Objective
Make every Bot discover/invoke allowed same-account device and installed MiniApp capabilities only through one MSR catalog/policy/approval/audit/result plane.

## Exact implementation scope
- `third_party/mahayana/mahayana-rs/mahayana-kernel/src/supervisor.rs`: approval, permission memory, loop/fail-closed policy primitives accepted from MSR-202.
- `third_party/mahayana/mahayana-rs/mahayana-native-engine/src/lib.rs`: capability catalog exposure, invocation correlation, result/progress/error envelope, model-facing filter.
- `third_party/mahayana/mahayana-rs/mahayana-computer/src/lib.rs`: authorized Computer Use executor; its own contract says caller is responsible for consent/auth/policy/audit, so MSR-211 must guard before invocation.
- existing Host/capability bridge consumers such as `desktop/electron/host-process.cjs`, `desktop/electron/native-capability-handlers.cjs`, and `frontend/apps/web/src/lib/mahayana-host/contracts.ts` only through accepted GBF-409/411 interfaces.
- focused kernel/native-engine policy/catalog/result tests.
No provider gets a direct message-posting or policy-bypass path.

## Implementation steps
1. Record exact accepted heads/contracts for MSR-202, MSR-210, GBF-409 and GBF-411.
2. Normalize MCP/WebMCP/App MCP/MiniApp CLI/native Computer Use descriptors into stable capability descriptors.
3. Filter model exposure by account, installed MiniApp, device pairing/control, current target/session/generation and policy state.
4. Route mutating/sensitive calls through accepted MSR-202 approval class; deny, expire, interruption or missing approval fails closed.
5. Emit stable invocation id/provider/tool/provenance with redacted progress/result/error; no provider directly posts chat messages.
6. Reject revoked/stale device/generation, unavailable/uninstalled MiniApp, duplicate/replayed invocation and secret leakage.
7. Prefer semantic capabilities. Use Computer Use fallback only when semantic capability is genuinely unavailable and all device/policy/approval checks independently pass.

## In scope
Capability normalization, discovery filter, MSR policy/approval gate, result envelope, semantic/fallback routing contract.

## Out of scope
Implementing GBF-409/411 themselves, Bot session mapping (MSR-210), TFI group transport/rendering, bypassing OS/device permissions, local build/test.

## Acceptance by category
- **Unit:** descriptor normalization/filter, stale/revoke/availability, invocation idempotency and redaction units.
- **Contract:** allowed/denied discovery; approval approve/deny/expire; revoked/stale device; unavailable/uninstalled MiniApp; duplicate invocation; provider failure; result correlation; no provider->message bypass.
- **Integration:** accepted GBF-409/411 catalog/device/App MCP -> MSR policy -> provider -> result envelope; TFI consumes typed result without provider side channel.
- **E2E:** exact-main installable Bot journey includes allowed semantic action and explicit denied/expired/revoked/stale/unavailable paths; fallback journey proves semantic unavailability before authorized Computer Use.
- **Security:** fail closed on missing/deny/expire approval, revoked/stale target, account mismatch, disabled control, unavailable MiniApp; secure inputs/secrets redacted; Computer Use never bypasses an available-but-denied semantic tool.
- **Performance:** capability filtering/routing is bounded and cached only with generation-safe invalidation; record catalog/invocation overhead and ensure fallback has no retry storm/duplicate mutation.

## Provenance gate
Any actual Codex/Grok Build adaptation records exact upstream repo/file/revision/license/NOTICE/attribution/local destination/adaptation note in this task/evidence. Architecture pin is insufficient. Reconstructed Grok Bot implementation code is forbidden; observable clean-room anchors only.

## Required write-back and evidence
Record each prerequisite's exact accepted head/PR/evidence, then actual branch/commit/PR/review/CI workflow-run-job/check/evidence/status/changelog here and cross-project records. Planned/pending is not passed.

Closure requires this task's own protected merge, CI and exact-main installable package/E2E/Release evidence: main SHA, app version, platform, run/job, journey ID, timestamp, package, complete video, step screenshots, trace, HTML/native report, logs; pass/fail always-equivalent upload; target 90 days or recorded lower maximum. Missing evidence blocks pass.

## Execution fields
Branch: `blocked`; Commit: `pending`; PR: `pending`; CI: `pending`; Evidence: `pending`; Review: `pending`; Canonical-main/package/release: `pending`.
