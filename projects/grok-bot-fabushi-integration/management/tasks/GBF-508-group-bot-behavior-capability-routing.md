# GBF-508 — Grok-like group Bot behavior and same-account capability routing

- **Project ID / Key:** `FAB-P0004 / GBF`
- **Task ID:** `GBF-508`
- **Program:** `FAB-ARCH-P0-20260904`
- **Status:** `BLOCKED`
- **Owner:** Execution project group; security reviewer required for device/Computer Use paths
- **Hard dependencies:** `MSR-210`, `MSR-211`, `GBF-409`, and `GBF-411` must **each** independently complete: contract acceptance; independent code review `REVIEW-PASS`; protected canonical-main merge; every required CI check; and installable/packaged E2E plus Release evidence bound to that dependency's exact accepted canonical-main SHA. No review pass, “accepted contract”, source presence, downstream closure, or “reuse existing” wording alone satisfies a dependency.
- **Current dependency facts:** `MSR-210` remains blocked by `MSR-201 in-progress`; `MSR-211` remains blocked by `MSR-202 in-progress` plus `GBF-409/411 IN_PROGRESS`; GBF-409/411 still lack required final GitHub CI/E2E/exact-main delivery evidence. Pending remains pending.
- **Transitive foundation truth:** MSR-201 and MSR-202 must complete their own contract/review/protected-merge/required-CI/exact-main packaged E2E/Release lineages before MSR-210/MSR-211 can count as satisfied dependencies. GBF-409/411 must likewise complete their own lineages; GBF-508 cannot use its own downstream evidence to backfill an unfinished prerequisite.
- **Parallel/prework:** clean-room behavior observation, anchor ledger, product contract and test-vector drafting may proceed while blocked only as `contract-only`. Device/App-MCP/MSR capability integration code may not be submitted, accepted, or claimed complete until all hard dependency lineages are complete.

## Objective
Implement Fabushi-owned clean-room group Bot behavior and the Bot-facing routing seam for same-account device/MiniApp capabilities, while MSR remains the only runtime/session/policy authority.

## Exact implementation scope
- `desktop/src/messaging-shell-v2.tsx`: user-visible directed group Bot/tool-state projection only where GBF owns behavior presentation; TFI-M7 owns final messaging transport semantics.
- `desktop/src/mahayana-agent-workbench.tsx`: existing typed run/progress/tool/approval presentation patterns reused where appropriate, not a second runtime.
- `desktop/electron/host-process.cjs` and `desktop/electron/native-capability-handlers.cjs`: capability bridge consumer only through fully delivered GBF-409/411/MSR-211 interfaces.
- `third_party/mahayana/mahayana-rs/mahayana-computer/src/lib.rs`: existing authorized Computer Use executor used only behind fully delivered MSR-211; do not move policy into this executor.
- fully delivered GBF-409 same-account device/control and GBF-411 App/WebMCP public interfaces; fully delivered MSR-210 session and MSR-211 policy/result contracts.
- project-owned clean-room behavior evidence/fixtures under `projects/grok-bot-fabushi-integration/evidence/GBF-508/**` plus focused product tests.
If a fully delivered dependency exposes a different canonical integration file after merge, update this task with the exact accepted path **before editing**; no speculative duplicate adapter is authorized.

## Clean-room provenance boundary
Behavior reference: `bhrum/grok-bot-0.18-reconstructed@107877b4e2134fd167d239411386f09e42eadd6d`. Root LICENSE absent and provenance does not grant implementation-source rights. **No reconstructed implementation source may be copied, translated, ported or used as a code template.**

For every Grok-like behavior implemented, create an observable anchor entry containing: anchor ID; reference revision/source; observed UI/behavior/IPC outcome; screenshot/video/transcript or other observable evidence; Fabushi-owned expected behavior; and an explicit statement that no implementation source was copied. If no observable/right-cleared anchor exists, mark the behavior `UNMAPPED/EVIDENCE_ONLY` and do not implement it from that source.

## Implementation steps
1. While blocked, finish the clean-room anchor ledger and behavior/test vectors for mention/reply/command/privacy/tool-state semantics as contract-only work.
2. After dependencies fully close, record their exact accepted contract/review heads, protected-main SHAs, required CI and exact-main package/E2E/Release evidence in this task.
3. Implement privacy-mode directed triggers: explicit mention, reply-to-Bot, registered command/slash or other approved directed trigger; ambient messages must not invoke.
4. Preserve one Bot/one fully delivered MSR-210 durable session across direct/group/topic contexts; two Bots remain isolated.
5. Render thinking/progress/tool request/approval pending/result/error/final states using stable invocation IDs from fully delivered MSR-211; no direct provider->message side channel.
6. Route device/MiniApp discovery/action only through MSR-211 filtering/approval/audit. Same-account login alone is never control authorization.
7. Prefer semantic App/WebMCP/MiniApp capability. Computer Use fallback only under the complete predicate below.
8. Add positive/negative and packaged simulated-user evidence; hand final transport contract to TFI-M7 only after GBF-508 itself completes its own closure.

## In scope
Clean-room group Bot behavior, capability-routing seam, visible tool-state behavior, same-account/device/MiniApp policy integration and fallback contract.

## Out of scope
Implementing or replacing GBF-409/411, MSR session/policy runtime, TFI protocol/transport, copying reconstructed source, bypassing OS/device permissions, local build/test.

## Acceptance by category
- **Dependency gate:** MSR-210, MSR-211, GBF-409 and GBF-411 each have accepted contract + independent `REVIEW-PASS` + protected canonical merge + required CI + exact accepted canonical-main installable/packaged E2E and Release evidence. MSR-201/202 foundation lineages behind MSR-210/211 must also be complete. Missing any item leaves GBF-508 BLOCKED.
- **Unit:** directed-trigger/privacy classifier, tool-state reducer, capability route decision and fallback predicate units.
- **Contract:** mention/reply/command positives; ambient ignore; one-session context; typed invocation states; no provider->message bypass; every Grok-like behavior has a clean-room observable anchor; fallback only when every predicate below is true.
- **Integration:** fully delivered GBF-409/411 device/App surfaces -> fully delivered MSR-211 policy/result -> GBF behavior seam -> TFI-M7 consumer, with stable IDs and no duplicate runtime.
- **E2E:** exact-main installable multi-user group journey proves directed invocation and deliberate non-invocation, two-group context, tool progress/result, semantic capability use, genuinely-unavailable semantic fallback success, and every mandatory denial path.
- **Security:** mandatory approval deny/expire, account mismatch, unpaired/control-disabled device, target/session/client/generation stale or revoked, MiniApp unavailable/uninstalled or install state disallowing fallback, available-but-denied semantic capability and missing audit/correlation all fail closed; sensitive output redacted.
- **Performance:** semantic route is preferred and bounded; capability fallback does not poll/retry indefinitely, reinterpret denial as unavailability, or duplicate mutations; record invocation/routing overhead in packaged evidence.

## Semantic -> Computer Use hard gate
Fallback is permitted only when **all** are true: (1) semantic/App/MiniApp capability is genuinely unavailable, not merely available-but-denied; (2) the same-account device is explicitly paired; (3) control is enabled; (4) target, Mahayana/Bot session, client identity and capability generation are current and not revoked/stale; (5) required approval is granted and unexpired; (6) current MiniApp/install/enablement state explicitly allows the requested fallback semantics; and (7) the resulting action is audited and correlated end-to-end with stable invocation/request/session/target/client/generation identities and visible provenance. Approval deny/expire, account mismatch, unpaired/control-disabled state, any stale/revoked target/session/client/generation, MiniApp/install disallow, missing audit/correlation, unavailable-without-safe-fallback, or available-but-denied semantic capability must fail closed. A denial may never be retried/reclassified as unavailability.

## Test and Release handoff
- Execution owner may integrate capability paths only after all prerequisite lineages above are complete.
- Independent code review must inspect the real pushed diff and all fallback fail-closed branches; execution cannot self-award `REVIEW-PASS`.
- Test/release owner must run required CI and exact accepted canonical-main installable journeys for semantic allow, semantic available-but-denied, genuine unavailability fallback, approval approve/deny/expire, account/pairing/control negatives, target/session/client/generation stale/revoked, MiniApp/install allow/disallow, audit/correlation and restart continuity. Release evidence must bind to the same accepted SHA/package lineage.

## Required write-back and evidence
Record every hard dependency's exact accepted contract/review head, protected-main SHA, required CI and exact-main package/E2E/Release evidence, clean-room anchor ledger, then this task's actual branch/commit/PR/review head+verdict/CI workflow-run-job/check/evidence/status/changelog in GBF/MSR/TFI records. Planned is not passed.

This task's own closure requires protected canonical merge, required CI and exact-main **installable** package/E2E/Release evidence: exact main SHA, app version, platform, workflow run/job, journey/test ID, timestamp, package identity, complete video, step-labelled screenshots, trace, HTML/native report and logs. Upload pass and fail on an `always()`-equivalent path; target 90-day retention or record the maximum lower limit. Missing any prerequisite or own field/artifact blocks pass; source-only results are insufficient.

## Execution fields
Branch: `blocked`; Commit: `pending`; PR: `pending`; CI: `pending`; Evidence: `pending`; Clean-room anchors: `pending`; Review: `pending`; Canonical-main/package/release: `pending`.
