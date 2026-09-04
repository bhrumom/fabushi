# TFI-M6-P0-001 formatter closeout diagnosis evidence — 2026-09-05

## Scope and truth boundary
This is architecture/diagnostic evidence only. It does not claim formatter repair, required CI success, merge, packaged E2E, or Release.

- Execution PR: #2323, open/unmerged at diagnosis.
- Exact base: `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`.
- Exact diagnosed head: `c32a0bd80922a2be6e62c2722fbbd3b14a18a252`.
- R3 reviewer PR: #2327; verdict `REVIEW-PASS` for exact c32 code/records, not for CI/merge/E2E/Release.

## Required gate evidence
- Atomic: run `33893624154`, job `101090979544` = `SUCCESS`; full M6 contract test binary compiled and three P0-001 regressions passed.
- Mahayana fast: run `33893624176`, job `101090979748` = `FAILURE` at formatter; later Rust/native steps skipped.
- Messaging Product Gate: run `33893624204`; Rust job `101090979954` = `FAILURE` at rustfmt with later tests/clippy/media/bridge skipped; Electron job `101090980317` = `SUCCESS`.

## Formatter execution facts
Mahayana:
- checkout merge ref `3a46a4976c06939c76f4221b795240d0892bd06d`, logged as merge of c32 head into 9e88 base;
- repository workspace `/home/runner/work/fabushi/fabushi`;
- workflow working directory `third_party/mahayana/mahayana-rs`;
- `dtolnay/rust-toolchain@stable` action resolved stable Rust to `rustc 1.98.1 (48a229cea 2026-09-01)` with rustfmt component;
- command `cargo fmt --all -- --check`;
- exit 1.

Messaging Product Gate Rust:
- repository workspace `/home/runner/work/fabushi/fabushi`;
- stable Rust resolved to 1.98.1 with rustfmt/clippy;
- command `cargo fmt --manifest-path native/mahayana-messaging/Cargo.toml -- --check`;
- exit 1.

Neither job printed a standalone `rustfmt --version`; no standalone rustfmt version string is asserted here.

## Files reported by required rustfmt
- `native/mahayana-messaging/src/engine.rs` — reports around 2, 811, 840, 863, 1726, 1736, 1743, 1912, 2000, 2188.
- `native/mahayana-messaging/src/service.rs` — reports around 5, 663, 680, 1124, 1851, 2061.
- `native/mahayana-messaging/tests/m6_channels_topics_contract.rs` — reports around 676, 906.

## Base/head attribution discipline
No associated PR workflow run was returned for exact base `9e88a2e...`; therefore this evidence does not label exact base CI as passing or failing under Rust 1.98.1.

The exact compare plus the formatter diff establishes only the **current normalization scope**:
- service formatter reports are in lines unchanged by #2323;
- P0-001 test formatter reports are inside the block introduced by #2323;
- engine reports include both unchanged regions and a region intersecting the P0-001 `RespondCommunityJoin` edit.

Conclusion: **mixed current formatting drift: base-carried unchanged formatting + P0-001-introduced formatting**. This is not an “inherited failure” claim.

## Architecture decision
Repair classification is primarily `(b) dedicated formatter-baseline repair`, with a bounded `(a) P0-001 intersection`. Records/environment-only handling `(c)` cannot clear the required gate. No workflow deletion, skip, weakening, required-status change, or synthetic green result is allowed.

## Open-source / supply-chain note
No upstream code is copied. The plan reuses the repository's existing rustfmt gate semantics and records official/community patterns only as references. Existing `dtolnay/rust-toolchain` is MIT; existing `Swatinem/rust-cache` carries LGPL-3.0. Toolchain/action pinning is a separate reproducibility/supply-chain hardening topic and is not mixed into the formatter unblock.

## Planned task chain
1. `TFI-M6-P0-001-FMT-001`
2. fresh independent review of the new exact source head + all required Actions green
3. `TFI-M6-P0-001-MERGE-001`
4. `TFI-M6-P0-001-E2E-001`
5. independent review of complete packaged video/evidence
6. `TFI-M6-P0-001-RELEASE-001`
7. only then `FULL-CLOSE(TFI-M6-P0-001)` and eligibility to start M6-P0-002 implementation.
