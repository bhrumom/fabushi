# TFI-M6-P0-001 execution evidence

- Project: `FAB-P0001 / TFI`
- Task: `TFI-M6-P0-001`
- Architecture program: `FAB-ARCH-P0-20260904`
- Audited implementation base: `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`
- Governance contract: PR #2320 head `e2207ee0e59cf9d8c6ef26acf7ffbdd96c60078f`; independent R3 verdict `REVIEW-PASS`.
- Branch: `fix/tfi-m6-p0-001-community-create-boundary`
- Implementation commit: `30c6104ec1808941bcdf50f226a308c0c737d806`
- PR: #2323, base `codex/tfi-m6-repair`, open/unmerged.

## Changed implementation
1. `native/mahayana-messaging/src/engine.rs` — explicit optional participant event for `RespondCommunityJoin`.
2. `native/mahayana-messaging/src/service.rs` — existing Community-backed generic create becomes idempotent no-op; Community update remains metadata-only.
3. `native/mahayana-messaging/tests/m6_channels_topics_contract.rs` — focused approval/rejection, authority-boundary, ordinary-create, and `CommunityNotFound` regressions.
4. `.github/workflows/tfi-m6-p0-001-atomic-gate.yml` — minimal PR-only compile/test gate required because inherited base rustfmt drift prevents required workflows from reaching compilation. It does not replace required repository gates.

## Open-source-first/provenance
Official TDLib `tdlib/td@d1085f9cebc5a62379991ae1652673954f229c1f` was inspected. License: Boost Software License 1.0 (`LICENSE_1_0.txt`). Candidate adopted only as an architectural boundary reference: TDLib exposes creation and join-request processing as separate requests. No implementation code was copied or adapted. No Codex/Grok/reconstructed-Grok source was used.

## Verification facts
- Local heavy verification: **not run**, per repository/task policy.
- Local `git diff --check`: PASS before implementation commit.
- Initial PR #2323 Actions on `30c6104e...`:
  - Mahayana fast checks run `33884739411`, job `101061648277`: FAIL at `Verify formatting before native package setup` / `cargo fmt --all -- --check`; compile/tests were skipped.
  - Messaging Product Gate run `33884739286`, Rust self-hosted job `101061648207`: FAIL at `Rustfmt self-hosted messaging`; compile/tests were skipped. Electron Messenger job `101061648632`: SUCCESS.
- The rustfmt diff includes many pre-existing lines from audited `9e88a2e...` outside this atomic task. Those unrelated semantics are not reformatted here. The task-specific Actions gate is additive evidence only; it cannot waive these required failures.

## Current verdict
`IMPLEMENTED / CI-BLOCKED / REVIEW-PENDING / CLOSURE-BLOCKED`.

No protected-main merge, exact accepted-main packaged E2E, Release, or task-specific independent code `REVIEW-PASS` exists yet. Do not mark this task completed.
