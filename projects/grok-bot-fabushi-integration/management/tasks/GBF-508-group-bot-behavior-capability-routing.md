# GBF-508 — Grok-like group Bot behavior and same-account capability routing

- **Project ID / Key:** `FAB-P0004 / GBF`
- **Task ID:** `GBF-508`
- **Program:** `FAB-ARCH-P0-20260904`
- **Status:** `BLOCKED`
- **Owner:** Execution project group; security reviewer required for device/Computer Use paths
- **Hard dependencies:** `MSR-210 REVIEW-PASS`, `MSR-211 REVIEW-PASS`, `GBF-409 REVIEW-PASS/accepted contract`, `GBF-411 REVIEW-PASS/accepted contract`.
- **Current dependency facts:** MSR-210 is blocked by `MSR-201 in-progress`; MSR-211 is blocked by `MSR-202 in-progress` plus `GBF-409/411 IN_PROGRESS`; GBF-409/411 still lack required final GitHub CI/E2E/exact-main delivery evidence.
- **Parallel/prework:** clean-room behavior observation, anchor ledger, product contract and test-vector drafting may proceed while blocked. Device/App-MCP/MSR capability integration code may not be submitted or accepted until all hard dependencies are recorded as accepted.

## Objective
Implement Fabushi-owned clean-room group Bot behavior and the Bot-facing routing seam for same-account device/MiniApp capabilities, while MSR remains the only runtime/session/policy authority.

## Exact implementation scope
- `desktop/src/messaging-shell-v2.tsx`: user-visible directed group Bot/tool-state projection only where GBF owns behavior presentation; TFI-M7 owns final messaging transport semantics.
- `desktop/src/mahayana-agent-workbench.tsx`: existing typed run/progress/tool/approval presentation patterns reused where appropriate, not a second runtime.
- `desktop/electron/host-process.cjs` and `desktop/electron/native-capability-handlers.cjs`: capability bridge consumer only through accepted GBF-409/411/MSR-211 interfaces.
- `third_party/mahayana/mahayana-rs/mahayana-computer/src/lib.rs`: existing authorized Computer Use executor used only behind MSR-211; do not move policy into this executor.
- accepted GBF-409 same-account device/control and GBF-411 App/WebMCP public interfaces; accepted MSR-210 session and MSR-211 policy/result contracts.
- project-owned clean-room behavior evidence/fixtures under `projects/grok-bot-fabushi-integration/evidence/GBF-508/**` plus focused product tests.
If an accepted dependency exposes a different canonical integration file after merge, update this task with the exact accepted path **before editing**; no speculative duplicate adapter is authorized.

## Clean-room provenance boundary
Behavior reference: `bhrum/grok-bot-0.18-reconstructed@107877b4e2134fd167d239411386f09e42eadd6d`. Root LICENSE absent and provenance does not grant implementation-source rights. **No reconstructed implementation source may be copied, translated, ported or used as a code template.**

For every Grok-like behavior implemented, create an observable anchor entry containing: anchor ID; reference revision/source; observed UI/behavior/IPC outcome; screenshot/video/transcript or other observable evidence; Fabushi-owned expected behavior; and an explicit statement that no implementation source was copied. If no observable/right-cleared anchor exists, mark the behavior `UNMAPPED/EVIDENCE_ONLY` and do not implement it from that source.

## Implementation steps
1. While blocked, finish the clean-room anchor ledger and behavior/test vectors for mention/reply/command/privacy/tool-state semantics.
2. After dependencies pass, record their exact reviewed heads/PRs/public interfaces in this task.
3. Implement privacy-mode directed triggers: explicit mention, reply-to-Bot, registered command/slash or other approved directed trigger; ambient messages must not invoke.
4. Preserve one Bot/one MSR-210 durable session across direct/group/topic contexts; two Bots remain isolated.
5. Render thinking/progress/tool request/approval pending/result/error/final states using stable invocation IDs from MSR-211; no direct provider->message side channel.
6. Route device/MiniApp discovery/action only through MSR-211 filtering/approval/audit. Same-account login alone is never control authorization.
7. Prefer semantic App/WebMCP/MiniApp capability. Computer Use fallback only after proving semantic capability unavailable and validating device/policy/approval preconditions.
8. Add positive/negative and packaged simulated-user evidence; hand final transport contract to TFI-M7.

## In scope
Clean-room group Bot behavior, capability-routing seam, visible tool-state behavior, same-account/device/MiniApp policy integration and fallback contract.

## Out of scope
Implementing or replacing GBF-409/411, MSR session/policy runtime, TFI protocol/transport, copying reconstructed source, bypassing OS/device permissions, local build/test.

## Acceptance by category
- **Unit:** directed-trigger/privacy classifier, tool-state reducer, capability route decision and fallback predicate units.
- **Contract:** mention/reply/command positives; ambient ignore; one-session context; typed invocation states; no provider->message bypass; every Grok-like behavior has a clean-room observable anchor.
- **Integration:** accepted GBF-409/411 device/App surfaces -> MSR-211 policy/result -> GBF behavior seam -> TFI-M7 consumer, with stable IDs and no duplicate runtime.
- **E2E:** exact-main installable multi-user group journey proves directed invocation and deliberate non-invocation, two-group context, tool progress/result and semantic capability use.
- **Security:** mandatory approval deny/expire, revoked/stale device/generation, account mismatch/control disabled, MiniApp unavailable/uninstalled all fail closed; sensitive output redacted.
- **Performance:** semantic route is preferred and bounded; capability fallback does not poll/retry indefinitely or duplicate mutations; record invocation/routing overhead in packaged evidence.

## Semantic -> Computer Use hard gate
Fallback is permitted only when all are true: (1) `MSR-211 REVIEW-PASS` accepted policy plane; (2) GBF-409 same-account device is paired and control enabled; (3) target/session/client/generation are current and not revoked/stale; (4) semantic/App/MiniApp capability is genuinely unavailable, not merely denied; (5) required approval is granted and unexpired; (6) MiniApp/install state allows the requested fallback semantics; (7) resulting action is audited/correlated. Deny, expire, revoke, stale, unavailable-without-safe-fallback or available-but-denied semantic capability must fail closed.

## Required write-back and evidence
Record every hard dependency exact accepted head/PR/evidence, clean-room anchor ledger, actual branch/commit/PR/review head+verdict/CI workflow-run-job/check/evidence/status/changelog in this file and GBF/MSR/TFI dependency records. Planned is not passed.

Closure requires GBF-508's own protected merge, CI and exact-main **installable** package/E2E/Release evidence: exact main SHA, app version, platform, workflow run/job, journey/test ID, timestamp, package identity, complete video, step-labelled screenshots, trace, HTML/native report and logs. Upload pass and fail on an `always()`-equivalent path; target 90-day retention or record the maximum lower limit. Missing any field/artifact blocks pass; source-only results are insufficient.

## Execution fields
Branch: `blocked`; Commit: `pending`; PR: `pending`; CI: `pending`; Evidence: `pending`; Clean-room anchors: `pending`; Review: `pending`; Canonical-main/package/release: `pending`.
