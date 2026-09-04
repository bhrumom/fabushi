# Architecture repair evidence — PR #2320

- Project: `FAB-P0004/GBF`
- Program: `FAB-ARCH-P0-20260904`
- PR: `bhrumom/fabushi#2320`
- Canonical base verified before repair: `main@688465e94647d4c866f6b1d7b4884145b2f4a9da`
- Original reviewed head: `21ee56892db48925fe863320a1cd68b51c4596cd`
- Original verdict: `REVIEW-REJECTED`
- Review-writeback head used as repair parent: `a0333f32a5d0edc04723c49fc53a5997a3b0fe1e`
- Scope: `projects/**` governance only; no local build/test and no application/CI/workflow edits.

Repair makes GBF-409/411 live `IN_PROGRESS` state explicit, hard-gates GBF-508 on accepted GBF-409/411 and MSR-210/211, specifies policy/fallback negatives, and makes every Grok-like implementation require a clean-room observable anchor while forbidding reconstructed source copying. Full canonical-main packaged evidence identity/retention is repeated in task/handoff records.

This is a repair submission, not acceptance. Code review must re-read the latest PR head containing this file. CI, merge, packaged E2E and Release remain unclaimed.
