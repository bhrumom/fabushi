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
1. `dea59a9120b1783764a8b75218341dccedbab54a` — Rust M6 channel/community semantics.
2. `a5eb431375588068611a1b74a1ef2b2f6d215f23` — private-channel admission and Community creation boundary.
3. `f9316f500d0ef4ee27937dfdb70051436f308986` — topic projection/journal canonicalization.
4. `e7b41cd70f06242175384055b24449abc372232b` — Community/Conversation member convergence.
5. `ff07289fad62ccc896cc372a491b174e37d6ab52` — actor-scoped projection / Electron topic projection continuity.
6. `9916a77ed5941538c81e0cdb5884a3bee0b59ff5` — project_event actor fix + Electron CommunityChanged mapping fix.
7. `0bd0b6d5dcc8b42573cdeb6b7c17a7160a1aafba` — intermediate M6 repair iteration superseded by later fixes but remains ancestry.
8. `7a55bf366ad90b56d1af8ef1d4044f5e5aeac57d` — Community/member projection repair iteration.
9. `2cbcb29edb391b709d08a2a748ae658c2127cd2b` — admission/projection/journal repair iteration.
10. `af6fb35c30f9d64d6f731c8a0d1ebef959f95a73` — P0.1 membership authority / participant mutation convergence; source of later moderation/clippy latent behavior.
11. `6160971cb3c477b809ae470d60f1e3c601606329` — additional M6 repair/record step; historical source of `CommunityAdminAction::PostMessages` selector later removed by CLIPPY-001.
12. `9e88a2e9c030fe05147460dfa580366cf9aa433d` — parent-stack record/index head; includes `TFI-M6-CHANNELS-001` task record and preserves `IN_PROGRESS / PR pending / CI pending` truth.

The parent stack mixes Rust product source, Electron product source, Rust contract tests and project records. It has no independent canonical-main code-review PR. `TFI-M6-CHANNELS-001` itself does not exist on canonical main and cannot be treated as already accepted governance.

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

Create fresh product branches from the then-current canonical main, one atomic business boundary at a time. Each execution task must reconstruct the required end-state from the immutable historical source commits, record source SHA/file/hunk provenance, and prove equivalence with a `range-diff`/patch comparison or equivalent file-level semantic diff. Fresh commits are allowed because protected `main` uses squash merge; the audit invariant is source-patch provenance + acceptance evidence, not preservation of old commit IDs as main ancestors.

This avoids duplicate semantic application: before each task, compare canonical main against the intended source patch; if the patch is already present/equivalent, STOP as `ALREADY-IN-MAIN` instead of reapplying it.

### Rejected alternatives
- **Retarget #2323 to main**: rejects because review scope expands from `9e88a2...`-relative child delta to the full 34-commit product delta.
- **Direct merge/bypass**: ruleset forbids bypass and would admit unreviewed parent product code.
- **Blind cherry-pick of old commits**: rejects because intermediate commits are superseded, mix records/product, include latent red-CI states, and create duplicate patch risk after squash merges.
- **Rebase/force-push existing #2323**: rejects because it rewrites the evidence-bound reviewed object and invalidates existing exact-head review/Actions references.
- **Old-style stacked PRs preserving existing SHA ancestry**: insufficient because the repository's squash merge means lower-layer commit SHAs do not become canonical ancestors; upper layers still need fresh main-based reconstruction and review after each accepted squash.
- **Merge-base catch-all PR**: rejects because a large `main...head` PR defeats atomic review/rollback and repeats the original scope-expansion failure.

## Open-source-first basis
Official sources used:
- GitHub Docs: changing PR base warns that changing the base can remove commits/comments and changes the comparison object; stacked PR docs require dependency ordering; merge queue docs validate queued changes against latest target branch and required checks.
- Git `git-cherry-pick`: applies changes introduced by existing commits but creates new commits; conflict/context must be resolved explicitly.
- Git `git-patch-id`: patch identity is independent of line numbers and is suitable as an aid for detecting equivalent patches after history rewriting; it is not a substitute for semantic review.
- Git `git-merge-base --is-ancestor` / ancestry-path reasoning: used to prove base/head ancestry and gate against duplicate/reordered application.
- Gerrit official dependent-changes model: dependencies should be explicit and reviewed independently rather than hidden inside a catch-all change.

No upstream implementation code is copied. Therefore no new third-party runtime/dependency/license/supply-chain surface is introduced by this architecture plan. Any future product task that introduces external code/dependencies must stop for a new supply-chain/license review.

## Recovery layers
1. `TFI-M6-MAINSAFE-001-RUST-CANONICAL` — bottom-of-stack Rust M6 canonical state machine + contract-test end-state, including only required FMT/MOD/UNREAD/CLIPPY effects that belong to those Rust files.
2. `TFI-M6-MAINSAFE-002-ELECTRON-PROJECTION` — Electron self-hosted consumer/projection layer, dependent on accepted canonical Rust layer.
3. `TFI-M6-MAINSAFE-003-P0-CREATE-JOIN` — P0-001 create/join ownership boundary and focused regressions, reconstructed on accepted canonical layers; temporary atomic workflow is excluded.

Each product task: one fresh execution-group chat, then one fresh independent code-review chat; required Actions must be green on exact task head; only then protected merge queue and canonical-main readback. If any task needs a third unplanned production file, new dependency/Cargo/workflow/version change, or exposes a new semantic/security failure, STOP with `SCOPE-EXPANSION-REQUIRED` or `ARCHITECTURE-MERGE-BLOCKED`.

## Test-release restart rule
Test-release may restart only after all three recovery layers have independently passed review, required Actions, protected-main merge queue, and exact canonical-main readback, and after #2323 is either proven patch-equivalent/obsolete or replaced by a main-based residual PR whose diff contains only still-unmerged reviewed semantics. No canonical packaged E2E/test release before that point.