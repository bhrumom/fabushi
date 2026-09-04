# Source of Truth

## 权威项目基线
唯一长期项目基线：`bhrumom/fabushi` 的 `main:projects/grok-bot-fabushi-integration/`。GitHub live PR/CI/Release facts override stale project claims; chats/local copies are inputs only.

## 2026-09-04 clean-room boundary
Program `FAB-ARCH-P0-20260904` inspected `bhrum/grok-bot-0.18-reconstructed@107877b4e2134fd167d239411386f09e42eadd6d`. Root `LICENSE` is absent; `PROVENANCE.md` states no upstream source-code license is implied and independent rights review is required. Therefore it is **behavior/evidence reference only**.

Allowed: independently observe and record mention/privacy/session/tool-state UI behavior, visible state transitions, documented or observed IPC boundary shapes, screenshots/video/transcripts and resulting externally observable semantics.

Forbidden: copy, translate, mechanically port, derive implementation from, or vendor reconstructed implementation files. Every Grok-like behavior implemented by GBF-508 must cite an observable anchor ID/revision/evidence artifact. If an anchor or rights basis is missing, the behavior stays `UNMAPPED/EVIDENCE_ONLY` until resolved; it is not implemented from source.

## Cross-project authority and hard gates
GBF owns behavior and same-account device/App capability semantics; MSR owns execution/session/policy; TFI owns messaging projection/transport. No second Bot engine or direct provider->message path is allowed.

PR #2320 reviewed head `21ee56892db48925fe863320a1cd68b51c4596cd` remains `REVIEW-REJECTED` until fresh review of the latest repair head. Current canonical dependency facts: `GBF-409` = `IN_PROGRESS` with PR/required CI/exact-main packaged E2E/Release evidence pending; `GBF-411` = `IN_PROGRESS` with GitHub CI/E2E/deployment/release/live evidence pending; `MSR-201/202` = `in-progress`. Thus GBF-508 cannot close via “reuse existing”; it hard-gates accepted GBF-409, GBF-411, MSR-210 and MSR-211 contracts, then its own merge/CI/exact-main installable package evidence.

## Conflict rule
When source/project text conflicts with `main`/live GitHub facts, record the discrepancy and correct status without rewriting prior evidence. Planned/pending is never passed.
