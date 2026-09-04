# CODE REVIEW — PR #2320 — R2 independent re-review

- Project: `FAB-P0005 / MSR`
- Program: `FAB-ARCH-P0-20260904`
- Review round: `R2`
- Verdict: **REVIEW-REJECTED**
- Reviewed PR: `#2320`
- Reviewed base: `main@688465e94647d4c866f6b1d7b4884145b2f4a9da`
- Reviewed head: `arch/p0-recovery-20260904@a5ce2e522cf124910c6627c72a646513b90960fa`
- Write-back branch: `review/pr-2320-r2-20260904-a5ce2e5`
- Local build/test: **not run**

## Independent result

The prior PR #2320 rejection is preserved unchanged. This R2 review independently read the latest real head and all 13 authoritative tasks plus canonical project/dependency truth.

### Blocking R2-01 — MSR downstream prerequisite closure is not task-locally strict enough

`MSR-201` and `MSR-202` remain `in-progress` with commit/PR/CI/delivery evidence incomplete. `MSR-210` currently hard-depends on `MSR-201 REVIEW-PASS/accepted contract`; `MSR-211` currently hard-depends on `MSR-202 REVIEW-PASS`, `MSR-210 REVIEW-PASS`, and `GBF-409/411 REVIEW-PASS/accepted contract`. Their own closure sections correctly require their own protected merge/CI/exact-main installable evidence, but the authoritative task-local dependency gate does not explicitly require each prerequisite's protected merge + required CI + exact accepted canonical-main installable/package E2E/Release evidence before dependent closure.

Repair `MSR-210` and `MSR-211` so the prerequisite closure gate is explicit and self-contained. Allowed design/test-vector prework may remain, but runtime integration submit/accept/close scope must remain `BLOCKED` until prerequisite delivery evidence is complete, unless a narrowly documented contract-only exception explicitly forbids downstream closure and names the later delivery owner.

### Cross-project blocking consistency

`TFI-M7-P0-001` consumes the MSR-211 capability plane but its semantic-to-Computer-Use fallback predicate is weaker than the reviewed `GBF-508` predicate: it omits current/not-stale/not-revoked `client`, explicit MiniApp/install-state permission, and explicit fallback-action audit/correlation. Because this is a consumer of the MSR policy plane, program closure remains rejected until the TFI consumer mirrors the full fail-closed policy preconditions.

## Verified MSR repairs

- `MSR-107` now has exact-file implementation-time provenance requirements for actual Codex/Grok Build adaptation: upstream repository/file/revision, license, NOTICE/attribution disposition, local destination, adaptation/reimplementation note and reviewer decision. Architecture-level pins cannot substitute.
- Reconstructed Grok implementation code is forbidden as an implementation upstream; observable clean-room anchors only; unclear rights remain do-not-use.
- `MSR-210` and `MSR-211` correctly show current dependency facts as blocked/pending and do not promote source presence to acceptance.
- Six acceptance categories and real execution evidence/write-back fields are present.

## CI observation

At reviewed PR head `a5ce2e5...`, general `CI` and `Project portfolio governance` completed successfully, while `GBF release candidate regression` run `33876067936` failed its canonical seven-gate job. This is recorded only to prevent an all-green claim; no runtime/package/release acceptance is inferred for this governance PR.

Return to the architecture project group for governance-only repair, then request a new real-diff review.