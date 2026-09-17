# TFI M6 parent-stack main-safe architecture diagnosis — 2026-09-05

## Classification
`ARCHITECTURE-MERGE-BLOCKED / MAINSAFE-RECOVERY-PLANNED / EXECUTION-NOT-STARTED`

This record is architecture/governance only. It does not modify application/test/workflow/Cargo/dependency/version logic and does not claim any product code is merged.

## Canonical topology readback
- canonical `main`: `688465e94647d4c866f6b1d7b4884145b2f4a9da`.
- execution PR `#2323`: open/unmerged, head `1c314ef514f71e5a1320ddea0803078923a4858c`, real base `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`.
- `main -> base`: 12 commits, behind 0.
- `base -> #2323 head`: 22 commits.
- therefore `main -> #2323 head`: 34 commits, verified from ancestry rather than assumed.
- active ruleset: `main-merge-queue` / `15857448`, target `refs/heads/main`, `SQUASH + ALLGREEN`, required status `CI result`, no bypass actor.
- no PR with head `codex/tfi-m6-repair` exists. Commit-to-PR lookup for both `6160971...` and `9e88a2e...` resolves only to child PR #2323.

## Exact 12-commit parent stack, oldest -> newest
The sequence below is verified by each commit's real Git `parents[]` pointer, not by timestamp or message order:
1. `6160971cb3c477b809ae470d60f1e3c601606329` — `feat(tfi): add channel and topic management primitives`; direct parent is canonical `688465e...`. This is the large initial M6 product/test/record change.
2. `dea59a9120b1783764a8b75218341dccedbab54a` — `fix(tfi): harden channel state projections`.
3. `a5eb431375588068611a1b74a1ef2b2f6d215f23` — `fix(messaging): enforce community admission and legacy threads`.
4. `f9316f500d0ef4ee27937dfdb70051436f308986` — `fix(messaging): converge topic and journal projections`.
5. `2cbcb29edb391b709d08a2a748ae658c2127cd2b` — `docs(tfi): record M6 repair review state`; records-only checkpoint.
6. `e7b41cd70f06242175384055b24449abc372232b` — `fix(messaging): converge community membership events`.
7. `ff07289fad62ccc896cc372a491b174e37d6ab52` — `fix(messaging): project topic deltas for actors`.
8. `0bd0b6d5dcc8b42573cdeb6b7c17a7160a1aafba` — `docs(tfi): record topic projection repair`; records-only checkpoint.
9. `9916a77ed5941538c81e0cdb5884a3bee0b59ff5` — `fix(messaging): close projection compile blockers`.
10. `7a55bf366ad90b56d1af8ef1d4044f5e5aeac57d` — `docs(tfi): record compile blocker repair`; records-only checkpoint.
11. `af6fb35c30f9d64d6f731c8a0d1ebef959f95a73` — `fix(messaging): make community membership canonical`.
12. `9e88a2e9c030fe05147460dfa580366cf9aa433d` — `docs(tfi): record canonical membership batch`; records-only parent-stack head.

Exact Git chain:
`688465e... -> 6160971... -> dea59a9... -> a5eb431... -> f9316f5... -> 2cbcb29... -> e7b41cd... -> ff07289... -> 0bd0b6d... -> 9916a77... -> 7a55bf3... -> af6fb35... -> 9e88a2e...`.

The `main..base` changed-file set contains exactly two Electron product files (`desktop/src/messaging-shell-v2.tsx`, `desktop/src/selfhosted-messaging-client-v2.ts`), five Rust product files (`community.rs`, `conversation.rs`, `engine.rs`, `protocol.rs`, `service.rs`), one Rust M6 contract test, and TFI-only ADR/source/management records. It has no independent canonical-main code-review PR. `TFI-M6-CHANNELS-001` itself does not exist on canonical main and its parent-stack copy still says `IN_PROGRESS / PR pending / CI pending`; it cannot be treated as already accepted governance.

## Child stack evidence boundaries
`9e88a2... -> 1c314ef...` is 22 commits. Material product/validation boundaries are:
- `TFI-M6-P0-001` product repair through `726b4210ddd4d9a967778193a8d374b5f8bad206`, independently R3 reviewed only against base `9e88a2...`; review PR #2327 records `REVIEW-PASS` for that base-relative object, not for parent stack.
- temporary `.github/workflows/tfi-m6-p0-001-atomic-gate.yml` was added/edited in child history (`39cb159...`, `c00f3fc...`, `75b319...` lineage). It is historical execution evidence only and MUST NOT be replayed into the main-safe recovery chain.
- FMT-001 product formatter commit `d2f97c0c22411a49ef926c0bb9c049be18348b10`; independent scope review PASS via #2329, but only on stacked child.
- MOD-001 semantic test alignment is one-file test work in `native/mahayana-messaging/tests/m6_channels_topics_contract.rs`; historical execution/architecture records are preserved but do not make parent stack main-safe.
- UNREAD-001 product/test fixture commit `7d158e1742b2d9e56d101c90d3d81408dcd41947`; execution passed target tests but exposed later clippy failure.
- CLIPPY-001 product commits `90d337e8d04ce8c463c7228cac1053158f8268ed` + formatter-only `0899258257e2efb8c24bb7fa951f4ae6180bbb10`; independent review `REVIEW-PASS-CLIPPY-001` is explicitly limited to `373bc52... -> 1c314ef...`.
- test-release blocker is preserved in records-only PR #2334 head `b8acbb61292f05ab5addccb59d78ab8dd1d56631`; this architecture cites it and does not overwrite it.

## Strategy decision
### Adopted: canonical-main-based semantic reconstruction with immutable source provenance
Do NOT retarget #2323, merge it directly, force-push/rebase its history, or cherry-pick the 34 commits as a blind sequence.

Create fresh product branches from the then-current canonical main, one atomic business boundary at a time. Each execution task must reconstruct the required end-state from the immutable historical source commits, record source SHA/file/hunk provenance, and prove equivalence with `range-diff`, `patch-id`, or an equivalent file-level semantic comparison. Fresh commits are allowed because protected `main` uses squash merge; the audit invariant is immutable source-patch provenance + fresh acceptance evidence, not preservation of old commit IDs as main ancestors.

Before each task, compare the then-current canonical main against the intended source patch. If the semantic patch is already present/equivalent, STOP as `ALREADY-IN-MAIN` instead of reapplying it. No blind cherry-pick is authorized.

### Rejected alternatives
- **Retarget #2323 to main**: review scope would expand from the audited `9e88a2...`-relative child delta to the full 34-commit product delta.
- **Direct merge/bypass**: the ruleset has no bypass actor and this would admit unreviewed parent product code.
- **Blind cherry-pick of old commits**: intermediate commits are superseded, mix records/product, include latent red-CI states, and create duplicate-patch risk after squash merges.
- **Rebase/force-push existing #2323**: rewrites the evidence-bound reviewed object and invalidates exact-head review/Actions references.
- **Old-SHA stacked PR chain**: insufficient under `SQUASH`; accepted lower-layer old SHAs do not become canonical ancestors, so upper layers still need fresh main-based reconstruction/review.
- **Merge-base catch-all PR**: defeats atomic review/rollback and repeats the original scope-expansion failure.

## Open-source-first basis
Official sources used:
- GitHub Docs: changing a PR base changes the comparison object; stacked PRs require explicit dependency ordering; merge queue validates queued changes against the latest target branch and required checks.
- Git `git-cherry-pick`: applies changes introduced by commits but creates new commits and may require explicit conflict resolution.
- Git `git-patch-id`: provides a content-based patch identity useful to detect equivalent patches across history rewriting; it does not replace semantic review.
- Git `git-merge-base --is-ancestor` and ancestry-path reasoning: prove source ancestry and guard ordering/duplicate application.
- Gerrit official dependent-changes model: dependencies remain explicit and independently reviewed instead of being hidden in a catch-all change.

No upstream implementation code is copied and this architecture introduces no dependency. Any future task that adds external code/dependencies must stop for a separate license/supply-chain review.

## Recovery layers
1. `TFI-M6-MAINSAFE-001-RUST-CANONICAL` — bottom-of-stack Rust M6 canonical state machine + contract-test end-state, incorporating only the FMT/MOD/UNREAD/CLIPPY effects that belong inside its frozen Rust/test file set.
2. `TFI-M6-MAINSAFE-002-ELECTRON-PROJECTION` — Electron self-hosted consumer/projection layer, dependent on accepted canonical Rust layer.
3. `TFI-M6-MAINSAFE-003-P0-CREATE-JOIN` — P0-001 create/join ownership boundary and focused regressions, reconstructed on accepted canonical layers; temporary atomic workflow is excluded.

Each product task: one fresh execution-group chat, then one fresh independent code-review chat; required Actions must be green on the exact task head; only then protected merge queue and exact canonical-main readback. If a task needs any production/test file outside its frozen allowlist, any dependency/Cargo/workflow/version change, or exposes a new semantic/security failure, STOP with `SCOPE-EXPANSION-REQUIRED` or `ARCHITECTURE-MERGE-BLOCKED`.

## Test-release restart rule
Test-release may restart only after all three recovery layers have independently passed fresh review, required Actions, protected-main merge queue, and exact canonical-main readback, and after #2323 is proven patch-equivalent/obsolete or replaced by a main-based residual PR whose diff contains only still-unmerged reviewed semantics. No canonical packaged E2E/test release before that point.