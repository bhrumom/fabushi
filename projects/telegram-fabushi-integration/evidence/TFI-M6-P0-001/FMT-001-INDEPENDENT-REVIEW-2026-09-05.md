# TFI-M6-P0-001-FMT-001 independent review evidence — 2026-09-05

## Review identity
- Project: `FAB-P0001 / TFI`
- Review type: fresh independent code/record review; no implementation, merge, package, test release or formal release authority
- Execution PR: `#2323`
- Exact reviewed base: `9e88a2e9c030fe05147460dfa580366cf9aa433d`
- Exact reviewed head: `ecf79c8760b300c3853b74a64b6cf3f2d2db5e1d`
- Frozen architecture authority: PR `#2328` head `7b1964294f15ff9aba352116a166ceef5ae499ae`
- Frozen task: `projects/telegram-fabushi-integration/management/tasks/TFI-M6-P0-001-FMT-001-required-rustfmt-baseline-repair.md`
- Formatter implementation commit: `d2f97c0c22411a49ef926c0bb9c049be18348b10`
- Execution records handoff commit: `ecf79c8760b300c3853b74a64b6cf3f2d2db5e1d`
- Execution handoff comment: `5543960456`

## Sources independently read
The review re-read root `AGENTS.md`, `projects/telegram-fabushi-integration/SOURCE_OF_TRUTH.md`, `PROJECT.yaml`, the frozen FMT-001 architecture task at PR #2328 exact head, the execution evidence at the exact PR head, the PR body, all visible PR conversation/review history, the complete PR changed-file list/patch, the commit chain, and the exact FMT slice `c32a0bd80922a2be6e62c2722fbbd3b14a18a252..ecf79c8760b300c3853b74a64b6cf3f2d2db5e1d`.

Historical review continuity is preserved rather than rewritten:
- R1 review `5114738170`: `REVIEW-REJECTED` on historical head `73a46d3089c4f12dfb2f5659b232d51c674ed5a6`.
- R2 comment `5543006832`: `REVIEW-REJECTED` on historical head `1dc165489498889504a61b7e07d5164f25188cef`; B1/B2 closed, B3 remained record-truth blocker.
- R3 comment `5543442353`: `REVIEW-PASS` for code/records on historical head `c32a0bd80922a2be6e62c2722fbbd3b14a18a252`, while explicitly retaining `CI-BLOCKED / CLOSURE-BLOCKED`.
- Because FMT-001 changed Rust source after R3, none of those historical verdicts is reused as this verdict.

## FMT-001 scope audit
The frozen task authorizes only:
1. `native/mahayana-messaging/src/engine.rs`
2. `native/mahayana-messaging/src/service.rs`
3. `native/mahayana-messaging/tests/m6_channels_topics_contract.rs`
plus append-only TFI project/evidence records.

`d2f97c0c22411a49ef926c0bb9c049be18348b10` has parent `c32a0bd80922a2be6e62c2722fbbd3b14a18a252` and changes exactly those three Rust files: **59 insertions / 36 deletions** total. Independent patch inspection found only rustfmt/import-order/layout normalization: wrapping/unwrapping imports, `matches!` expressions, method chains, tuple/match arm formatting, struct/event literal layout, and brace placement. No boolean operator, branch condition, enum variant, identifier binding, literal value, event order, assertion operand, fixture value, test name, or test coverage meaning changes in this formatter commit.

`ecf79c8760b300c3853b74a64b6cf3f2d2db5e1d` is one records-only commit after `d2f97c0...`; it adds/updates exactly six `projects/telegram-fabushi-integration/**` execution records and no source/test/workflow/dependency/manifest/lock/root-governance file. The total FMT slice from `c32a0bd...` to `ecf79c...` is therefore exactly the three authorized Rust files plus six TFI records.

No FMT-001 change touches root `AGENTS.md`, `projects/PORTFOLIO.json`, `PROJECT.yaml` / Project ID (`FAB-P0001 / TFI` remains unchanged), `.github/workflows/**`, Cargo manifests/lockfiles, dependencies, another project, release metadata, or unrelated application code.

The whole PR still contains earlier P0-001 application/workflow/governance changes; those are historical parent-task changes and must not be misclassified as FMT-001 scope drift.

## Exact-head GitHub Actions truth
All results below are for exact head `ecf79c8760b300c3853b74a64b6cf3f2d2db5e1d` and exact PR base `9e88a2e9c030fe05147460dfa580366cf9aa433d`.

### Required Mahayana fast checks
- Run `33898670533`, job `101107312228`: **SUCCESS**.
- `Verify formatting before native package setup`: **SUCCESS**.
- All subsequent native/Rust steps in that job executed and succeeded through CLI compatibility, auth/secrets, product-client compile, kernel/supervision/legacy bridge, native engines, MCP, protocol/MiniApp, Harness, direct Host, deterministic/production Host adapters, and embedded FFI.

### Required Messaging Product Gate
- Run `33898670053`: **FAILURE** overall.
- Rust job `101107313643`: **FAILURE**.
- `Rustfmt self-hosted messaging`: **SUCCESS**.
- The next step, `Test messaging library and server binaries`: **FAILURE**.
- Required downstream Rust steps (`Clippy messaging library and server binaries`, deterministic media test/clippy, production Feature Host bridge/contacts verification) are **SKIPPED** because the test step failed.
- The durable execution evidence and final execution handoff identify the failing later-M6 regression as `slow_mode_and_moderation_are_enforced_by_the_rust_state_machine` at `tests/m6_channels_topics_contract.rs:632:5`, expecting `EngineError::CommunitySendRestricted(ConversationId::new("group:m6"))`. This review independently confirms from live Actions that the failure occurs only after formatter success in the full messaging test step; it does not infer a formatter failure.
- Electron job `101107313196`: **SUCCESS**. Electron PASS does not waive Product Rust failure.

### Task-specific atomic gate
- Run `33898670050`, job `101107311938`: **SUCCESS**.
- Contract test binary compilation succeeded and `Run TFI-M6-P0-001 regressions` succeeded.
- Atomic PASS is task-specific additive evidence only; it is not a substitute for the failed required Product Rust job.

## Security, license, maintainability, and drift review
- Security: no FMT-001 semantic code change; no new authorization, membership, admission, audit, replay, protocol or secret-handling behavior. No new security blocker found in the formatter delta.
- License/supply chain: no dependency, manifest, lockfile, workflow action, vendored source, generated dependency, or external-source implementation change. No new license or supply-chain issue introduced by FMT-001.
- Maintainability: formatter normalization is consistent with the required stable Rust/rustfmt gate and reduces format drift. The final PR body still contains historical/current-pointer text from the pre-FMT `c32a0bd...` round, but the newer exact-head execution record and comment `5543960456` explicitly supersede that pointer and make the chronology reconstructable. This is a non-blocking metadata-maintainability observation, not a formatter semantic defect.
- Scope drift: none found in the FMT slice. Do not use this review to authorize M6-P0-002+ semantic work.

## Findings and task boundary
### FMT-001-fixable findings
None. Both required formatter steps are green at the exact reviewed head, and the formatter source delta is scope-compliant and semantics-preserving.

### Separate semantic/CI finding
The required Product Rust job remains red after formatter success. That later-M6 moderation failure is outside the frozen format-only task and must not be repaired by changing assertions, weakening/skipping required checks, or smuggling semantic changes into FMT-001. It requires a separately architected/owned semantic repair and a fresh exact-head required-CI/review cycle.

## Independent verdict
**`REVIEW-PASS(FMT-001 scope) / CI-BLOCKED / CLOSURE-BLOCKED`**.

FMT-001 passes independent scope/semantic/record review, but the parent P0-001 closure does **not** pass because required Product Rust is still failing and downstream Rust checks are skipped. This verdict is not merge approval, protected-main acceptance, package/E2E approval, test-release approval, or formal-release approval.

Remaining gates include: resolve the separate required Product Rust semantic blocker without weakening gates; obtain fresh exact-head required CI with all mandatory Rust steps executed and green; preserve a fresh exact-head independent review; then separately complete protected canonical-main merge/readback, exact-main packaged/E2E evidence, test release, and formal release according to their own owners/contracts. `TFI-M6-P0-002` remains blocked until `FULL-CLOSE(TFI-M6-P0-001)`.
