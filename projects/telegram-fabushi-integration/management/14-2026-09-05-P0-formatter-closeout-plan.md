# TFI-M6-P0-001 required formatter closeout plan — 2026-09-05

- Project: `FAB-P0001 / TFI`
- Parent task: `TFI-M6-P0-001`
- Diagnosed execution PR: `#2323`
- Diagnosed exact base: `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`
- Diagnosed exact head: `c32a0bd80922a2be6e62c2722fbbd3b14a18a252`
- R3 reviewer PR: `#2327`, verdict `REVIEW-PASS` for the exact code/record head only
- Current delivery state: `REVIEW-PASS(c32) / CI-BLOCKED / CLOSURE-BLOCKED`
- Planning state: `ARCHITECTURE-PLAN-READY`; this is **not** task implementation, merge, E2E, or Release completion.

## 1. Verified current gate facts

| Gate | Run / job | Verified result |
|---|---|---|
| TFI-M6-P0-001 Atomic Gate | `33893624154` / `101090979544` | `SUCCESS`: full contract test binary compiled and the three P0-001 regressions passed |
| Mahayana fast checks | `33893624176` / `101090979748` | `FAILURE`: formatter failed; later Rust/native steps were skipped |
| Messaging Product Gate — Rust | `33893624204` / `101090979954` | `FAILURE`: rustfmt failed; later tests/clippy/media/bridge steps were skipped |
| Messaging Product Gate — Electron | `33893624204` / `101090980317` | `SUCCESS` |

Both failing jobs checked out PR merge ref `3a46a4976c06939c76f4221b795240d0892bd06d`, recorded by Actions as merge of head `c32a0bd...` into base `9e88a2e...`.

### Mahayana formatter execution
- Runner: Ubuntu 24.04.4, `ubuntu-24.04` image `20260831.293.1`.
- Repository workspace: `/home/runner/work/fabushi/fabushi`.
- Workflow working directory: `third_party/mahayana/mahayana-rs`.
- Toolchain action: `dtolnay/rust-toolchain@stable`, action SHA `6bed0761d98439e5a578e2877258200ad565ba87`, component `rustfmt`.
- Resolved toolchain: `rustc 1.98.1 (48a229cea 2026-09-01)`, installed from stable update dated 2026-09-03. The job did **not** print a standalone `rustfmt --version`; therefore the exact standalone rustfmt version string is not claimed.
- Command: `cargo fmt --all -- --check`.
- Exit: `1` with rustfmt diffs.

### Messaging Product Gate formatter execution
- Repository working directory: `/home/runner/work/fabushi/fabushi`.
- Resolved Rust stable toolchain: `1.98.1`, with rustfmt/clippy components.
- Command: `cargo fmt --manifest-path native/mahayana-messaging/Cargo.toml -- --check`.
- Exit: `1` with the same three files implicated.

### Exact files/ranges printed by required rustfmt
- `native/mahayana-messaging/src/engine.rs`: lines reported around `2`, `811`, `840`, `863`, `1726`, `1736`, `1743`, `1912`, `2000`, `2188`.
- `native/mahayana-messaging/src/service.rs`: lines reported around `5`, `663`, `680`, `1124`, `1851`, `2061`.
- `native/mahayana-messaging/tests/m6_channels_topics_contract.rs`: lines reported around `676`, `906`.

The log also prints repeated warnings that `imports_granularity = Item` is unstable on stable Rust. No repository `rustfmt.toml` / `.rustfmt.toml` was found at the repository root, `third_party/mahayana/mahayana-rs`, or the native messaging crate during this diagnosis. Those warnings are therefore recorded as a non-blocking environment/configuration uncertainty; the direct failing condition is the formatting diff and exit code 1, not the warning.

## 2. Base/head comparison and provenance discipline

There is no associated PR workflow run returned for exact base commit `9e88a2e9c030fe05147460dfa580366cf9aa433d`. Therefore this plan does **not** claim that exact base CI passed or failed under Rust 1.98.1.

The exact `9e88...c32...` compare plus the current formatter diff is sufficient to classify the *current normalization scope* without fabricating historical CI provenance:

- `service.rs`: #2323 changes the create-conversation boundary around the later service command mapping; the formatter-reported regions at imports, `663`, `680`, `1124`, `1851`, and `2061` are unchanged by #2323. These are base-carried lines in the current merge input.
- `m6_channels_topics_contract.rs`: #2323 adds the P0-001 regression block after base line 648; rustfmt reports lines `676` and `906` inside that new block. These are PR-head formatting mismatches.
- `engine.rs`: multiple formatter-reported regions are outside #2323's changed hunks, while the formatter-reported region around `2188` intersects the PR-modified `RespondCommunityJoin` participant-event construction. The current engine normalization is therefore mixed as well.

**Architecture conclusion:** the required formatter change set is **mixed: base-carried unchanged formatting plus P0-001-introduced formatting**. This is deliberately narrower than saying the failure is “inherited”: no historical base run establishes such an origin claim.

## 3. Repair classification

Primary classification: **(b) dedicated formatter-baseline repair**, with a bounded **(a) P0-001 intersection**.

Why:
1. A P0-001-only new-line formatting patch cannot satisfy a whole-crate/workspace `cargo fmt --check`, because required rustfmt also identifies unchanged base-carried lines.
2. A workflow/toolchain change is not required to make the current source conform to the gate and would broaden this repair without evidence.
3. The P0-001 test block and one engine region are themselves unformatted, so the repair is not a pure unrelated baseline issue either.
4. Category (c) cannot close the required gate: records/environment handling alone does not make required rustfmt pass.

The execution repair is therefore a **separate atomic format-only source/test task**. This architecture session does not implement it.

## 4. Open-source-first / official pattern review

No external code is copied, translated, or adapted by this plan.

| Source / pattern | Decision | License / supply-chain effect |
|---|---|---|
| Official `rust-lang/rustfmt` guidance: `cargo fmt` and CI `cargo fmt --all -- --check`; `--check` exits nonzero when formatting would change input | **REUSE principle and existing repo commands** | rustfmt is MIT OR Apache-2.0; no new dependency or copied code |
| Official rustup versioned toolchain syntax (`major.minor.patch`) | **REUSE as reproducibility reference only** | official Rust distribution; no dependency change in this plan |
| Apache DataFusion `rust-toolchain.toml` pins Rust `1.97.0` with `rustfmt`/`clippy` components | **REFERENCE pattern; do not copy** | Apache-2.0 example; pattern/reference only, no code incorporation |
| Existing `dtolnay/rust-toolchain` | **KEEP for current unblock; do not change required workflow here** | MIT action already used by repository; current floating `@stable` is a reproducibility risk, not proven failure cause |
| Existing `Swatinem/rust-cache@v2` | **KEEP as performance-only cache; never treat cache as provenance/gate truth** | LGPL-3.0 action already used by repository; this plan introduces no new use/dependency |
| GitHub secure-use guidance to pin actions to full commit SHA | **DEFER to a separate CI hardening decision after P0-001 closure** | improves immutability/supply-chain posture; changing required workflows is intentionally out of this blocker repair |

Rust 1.98.1's official release note identifies a rustc vtable miscompilation fix. It does not establish a rustfmt behavior change, so the observed stable update from runner Rust 1.98.0 to 1.98.1 is recorded only as a reproducibility signal, not as the cause of this formatting failure.

Existing workflow pattern worth preserving:
- Mahayana fast checks performs formatter validation before expensive Rust/native checks; fast failure is appropriate.
- Messaging Product Gate uses Rust cache as a build acceleration step but rustfmt remains an independent source check; cache cannot waive or synthesize formatter success.
- Task-local Atomic Gate is additive compile/regression evidence only and never substitutes for required product gates.

## 5. Atomic closeout chain

### Stage A — required formatter repair
`TFI-M6-P0-001-FMT-001`  
Task file: `management/tasks/TFI-M6-P0-001-FMT-001-required-rustfmt-baseline-repair.md`

Purpose: normalize only the three currently identified Rust source/test files using the required formatter semantics, with zero intentional semantic/test-contract/workflow change.

### Stage B — protected merge and canonical-main readback
`TFI-M6-P0-001-MERGE-001`  
Task file: `management/tasks/TFI-M6-P0-001-MERGE-001-protected-merge-and-canonical-readback.md`

Purpose: after a fresh independent review on the formatter-repair head and every required check passes, perform the protected integration path and prove the accepted content exists on canonical `main`. PR #2323 targets `codex/tfi-m6-repair`, so a successful merge of #2323 alone is not canonical-main closure; the protected consolidation path to `main` and exact main SHA readback are mandatory.

### Stage C — canonical-main packaged simulated-user journey
`TFI-M6-P0-001-E2E-001`  
Task file: `management/tasks/TFI-M6-P0-001-E2E-001-canonical-main-packaged-journey-evidence.md`

Purpose: Test/Release group builds/installs the packaged app from the exact accepted canonical-main SHA and runs the project-recorded full simulated-user journey. Evidence includes step screenshots, complete video, trace, HTML/native report, platform logs, package/build identity and workflow IDs. Retention target is 90 days; if GitHub policy enforces a lower maximum, record the actual maximum. The complete video/evidence is then handed to the code-review group for evidence review.

### Stage D — formal release / FULL-CLOSE
`TFI-M6-P0-001-RELEASE-001`  
Task file: `management/tasks/TFI-M6-P0-001-RELEASE-001-formal-release-and-full-close.md`

Purpose: only after packaged E2E passes and the code-review group accepts the evidence/video may the formal release group publish. FULL-CLOSE is recorded only after release lineage is bound to the exact accepted canonical-main SHA.

## 6. Hard gate sequence

`FMT-001 -> fresh independent R4 on the new exact source head -> all required Actions PASS with formerly skipped Rust steps actually executed -> MERGE-001 -> canonical-main readback -> E2E-001 -> evidence/video code review PASS -> RELEASE-001 -> FULL-CLOSE(TFI-M6-P0-001)`.

Until that full chain completes:
- `TFI-M6-P0-001` stays `CI-BLOCKED / CLOSURE-BLOCKED`.
- `TFI-M6-P0-002` implementation **must not start**.
- Atomic Gate PASS and Electron PASS remain useful evidence but do not waive the failed required Rust gates.
- No required check may be deleted, skipped, weakened, converted to non-required, or represented as green without a real successful run.

## 7. Governance PR decision

Architecture PR #2320 remains a historical/broad governance PR spanning TFI/MSR/GBF and an older execution snapshot. It is **not** extended for this c32 formatter closeout because doing so would mix a current task-specific handoff with a stale multi-project governance diff.

This plan reuses the existing project `FAB-P0001 / TFI` and existing parent task `TFI-M6-P0-001`; no duplicate Project ID or competing implementation plan is created. The records-only architecture branch for this addendum is based on exact #2323 head `c32a0bd...` so the architecture PR can remain TFI-records-only when targeted at the #2323 head branch.

## 8. Deferred hardening (non-blocking for this repair)

After P0-001 is fully closed, architecture/CI governance should separately assess whether repository Rust toolchains and third-party Actions should be pinned to explicit Rust versions and full action SHAs. This must not be smuggled into `FMT-001`: it changes reproducibility/supply-chain policy and requires its own evidence. The current P0-001 unblock remains source normalization under the already-required gate.
