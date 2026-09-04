# Code review evidence — PR #2320

- Project: `FAB-P0004/GBF`
- Program: `FAB-ARCH-P0-20260904`
- Reviewed PR: `bhrumom/fabushi#2320`
- Reviewed architecture head: `21ee56892db48925fe863320a1cd68b51c4596cd`
- Canonical base: `688465e94647d4c866f6b1d7b4884145b2f4a9da`
- Review date: `2026-09-04 +08:00`
- Verdict: `REVIEW-REJECTED`

## Positive findings

- Project identity remains `FAB-P0004/GBF`; no duplicate project was created.
- The cross-project ownership model is consistent: GBF owns observable Bot behavior/device/App-MCP capability contracts; MSR owns execution/session/policy; TFI owns messaging/MiniApp projections.
- `bhrum/grok-bot-0.18-reconstructed@107877b4e2134fd167d239411386f09e42eadd6d` has `NOTICE.md` and `PROVENANCE.md` but no root `LICENSE`; its provenance explicitly states that no upstream source-code license is implied. The PR correctly selects observable-behavior clean-room use only and forbids implementation-source reuse.
- The packaged behavior-test handoff requires full video, step screenshots, trace, report, logs and preservation of failing evidence.

## Blocking findings

1. `GBF-508` is not a complete atomic execution contract. It has Task ID/status/dependency/parallel/goal/behavior/acceptance, but lacks exact implementation files/modules, detailed implementation steps, explicit in/out boundaries, a unit/contract/integration/E2E/security/performance acceptance matrix, and branch/commit/PR/CI/evidence/status/changelog write-back fields.
2. `GBF-508` says to reuse `GBF-409/411`, but both canonical tasks are still `IN_PROGRESS`; `GBF-409` has PR/required CI/exact-main packaged E2E/release evidence pending and `GBF-411` has GitHub CI/E2E/deployment/release/live evidence pending. These are not satisfied foundations and must be hard prerequisites wherever required.
3. `GBF-508` only declares `MSR-210 REVIEW-PASS` as a hard dependency and merely coordinates with `MSR-211`. Because its acceptance exercises approval deny/expire, revoked/stale device and MiniApp capability routing, require `MSR-211 REVIEW-PASS` explicitly before capability integration/closure.
4. The evidence handoff must carry the root `AGENTS.md` canonical identity/retention contract into the task: exact canonical-main SHA, app version, platform, workflow run/job, journey/test ID, timestamp, `always()`-equivalent pass/fail upload, and repository retention target/constraint.
5. Clean-room behavior evidence must cite observable anchors for every implemented Grok-like behavior. No reconstructed implementation code may be copied; uncertainty must remain unmapped/evidence-only until an anchor exists.

## Required repair before re-review

Normalize `GBF-508` into a self-contained atomic task; make `MSR-211` and unfinished GBF capability foundations explicit hard gates; add the complete post-main evidence identity/retention contract; and preserve the pinned clean-room behavior-anchor/provenance rule in implementation evidence. Do not claim group-Bot capability closure until the dependent real diffs and GitHub Actions evidence pass review.
