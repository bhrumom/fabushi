# TFI-M6-P0-001-FMT-001 — required rustfmt baseline repair

## Identity
- Project: `FAB-P0001 / TFI`
- Parent: `TFI-M6-P0-001`
- Type: atomic execution task
- Priority: P0 closure blocker
- Status: `READY_FOR_EXECUTION / NOT_IMPLEMENTED`
- Input PR: `#2323`
- Planning head diagnosed: `c32a0bd80922a2be6e62c2722fbbd3b14a18a252`

## Goal
Close the current required Rust formatter blocker without altering intended runtime behavior, test meaning, workflow policy, or any M6-P0-002+ semantics.

## Preconditions
1. Start from the exact current #2323 execution branch/head or its verified successor; record the exact starting SHA.
2. Re-read the current required formatter logs before editing and stop if the implicated file set has changed materially.
3. Preserve R3 code-review facts from reviewer PR #2327 as historical evidence only; because source will change, request a fresh independent review after this task.

## Allowed source/test scope
Only these three files are authorized for format-only normalization unless a fresh required formatter run proves an additional file is necessary:
- `native/mahayana-messaging/src/engine.rs`
- `native/mahayana-messaging/src/service.rs`
- `native/mahayana-messaging/tests/m6_channels_topics_contract.rs`

Project/evidence write-back under `projects/telegram-fabushi-integration/**` is allowed.

## Forbidden scope
- no `.github/workflows/**` edits;
- no Cargo manifest/lock changes unless formatter itself demonstrably changes them (not expected; otherwise STOP and re-architect);
- no runtime logic, branch condition, authorization, audit, membership, admission, replay, protocol, renderer, MiniApp, Bot, MSR or GBF behavior change;
- no test assertion/fixture/coverage meaning change other than whitespace/layout imposed by formatter;
- no deleting/skipping/weakening/renaming required gates;
- no M6-P0-002/003/004/005 work;
- no opportunistic cleanup.

## Required implementation method
1. Use the formatter semantics of the required CI job. The observed gate resolves stable Rust to `1.98.1` and runs `cargo fmt` checks. Formatting output should be produced with the matching stable toolchain/component or a CI-equivalent environment.
2. Apply formatter-only changes to the authorized files.
3. Review the exact diff and prove it is syntactic layout/import ordering only. Any AST/semantic change is a task failure and must be reverted or split into a new architecture task.
4. Commit the smallest format-only change to the #2323 execution line; update evidence with before/after exact SHAs.

## Acceptance
All are mandatory:
- diff contains only the three authorized Rust files plus TFI project/evidence records;
- application/test semantic diff review finds no behavioral change;
- task-specific Atomic Gate compiles and all three P0-001 regressions pass again;
- Mahayana required formatter step passes and subsequent Rust/native steps actually run and succeed;
- Messaging Product Gate Rust formatter passes and subsequent tests/clippy/media/bridge steps actually run and succeed;
- Electron product job remains green;
- every other required check for the new exact head is green;
- a fresh independent reviewer evaluates the **new exact head** and returns `REVIEW-PASS` before merge progression.

## Evidence required
Record under `projects/telegram-fabushi-integration/evidence/TFI-M6-P0-001/` or a child directory:
- start SHA, formatter repair commit SHA, final PR head SHA;
- exact changed filenames and diff-stat;
- formatter toolchain/version evidence from Actions;
- run/job IDs and final conclusions for Atomic, Mahayana, Product Rust, Product Electron and all required checks;
- proof that previously skipped Rust steps executed;
- fresh reviewer PR/comment/review IDs and verdict;
- explicit statement that no workflow weakening occurred.

## Rollback / risk
- If formatting creates semantic changes, revert those hunks and do not claim completion.
- If required rustfmt still reports files outside the authorized set, stop and return `BLOCKED: formatter scope expanded` with the exact log; architecture must decide whether the baseline task scope changes.
- If a later Rust step fails after formatter becomes green, this task becomes `CI-BLOCKED` on that newly exposed failure; do not hide it behind formatter completion.

## Handoff
On full acceptance, hand to `TFI-M6-P0-001-MERGE-001`. Do not start `TFI-M6-P0-002`.
