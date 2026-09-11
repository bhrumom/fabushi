# CODE REVIEW — PR #2320 — R2 independent re-review

- Project: `FAB-P0004 / GBF`
- Program: `FAB-ARCH-P0-20260904`
- Review round: `R2`
- Verdict: **REVIEW-REJECTED**
- Reviewed PR: `#2320`
- Reviewed base: `main@688465e94647d4c866f6b1d7b4884145b2f4a9da`
- Reviewed head: `arch/p0-recovery-20260904@a5ce2e522cf124910c6627c72a646513b90960fa`
- Write-back branch: `review/pr-2320-r2-20260904-a5ce2e5`
- Local build/test: **not run**

## Independent result

The prior PR #2320 rejection remains immutable. R2 reviewed the latest real diff, canonical project records, dependency tasks and all 13 authoritative P0 atomic tasks.

### Blocking R2-01 — GBF-508 prerequisite closure is not task-locally strict enough

Canonical `GBF-409` and `GBF-411` remain `IN_PROGRESS`; MSR-210/211 are also blocked by unfinished MSR-201/202 and GBF dependencies. `GBF-508` correctly records these facts and blocks integration code, but its hard dependency line is expressed as `MSR-210 REVIEW-PASS`, `MSR-211 REVIEW-PASS`, and `GBF-409/411 REVIEW-PASS/accepted contract`. Its later protected merge/CI/exact-main installable package/E2E/Release closure text applies to GBF-508 itself.

Repair GBF-508 so each true prerequisite must have REVIEW-PASS plus protected merge, required CI, and exact accepted canonical-main installable/package E2E/Release evidence before GBF-508 can close. If any dependency is intentionally contract-only at an earlier phase, document the narrow exception in this authoritative task, explicitly forbid downstream closure until the later delivery owner completes that evidence, and keep the state `BLOCKED`.

### Blocking R2-02 — downstream TFI consumer weakens the accepted fallback predicate

GBF-508's own semantic-to-Computer-Use gate is correct and complete: semantic/App/MiniApp must be genuinely unavailable rather than denied; same-account device paired; control enabled; target/session/client/generation current and not revoked/stale; approval granted/unexpired; MiniApp/install state permits the action; action audited/correlated; deny/expire/revoke/stale/unsafe-unavailable/available-but-denied all fail closed.

However, `TFI-M7-P0-001`, which consumes this contract, omits current `client`, explicit MiniApp/install permission, and explicit fallback-action audit/correlation from its authorization predicate. Program closure is therefore still unsafe even though GBF-508 itself is repaired.

## Verified GBF repairs

- Reconstructed Grok Bot is strictly a clean-room observable behavior/UI/IPC reference. The task forbids copying, translating, porting or templating from implementation source and requires observable anchor evidence; unresolved rights stay `UNMAPPED/EVIDENCE_ONLY`/do-not-use.
- GBF-508 explicitly hard-depends on MSR-211 and correctly keeps device/App-MCP integration blocked while dependencies are unfinished.
- Six acceptance categories, real branch/commit/PR/review/CI/evidence write-back, and exact-main installable evidence identity are present.

## CI observation

At reviewed head `a5ce2e5...`, `GBF release candidate regression` run `33876067936` failed the `Canonical seven-gate regression` job while general CI/governance runs succeeded. This review does not treat the docs-only PR as runtime accepted and does not claim all checks are green.

Return to architecture project group for governance-only repair and fresh real-diff review.