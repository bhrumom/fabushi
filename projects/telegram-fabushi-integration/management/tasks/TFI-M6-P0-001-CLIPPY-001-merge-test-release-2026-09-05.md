# TFI-M6-P0-001-CLIPPY-001 — merge / test-release gate record — 2026-09-05

## Identity
- Project: `FAB-P0001 / TFI`.
- Atomic task: `TFI-M6-P0-001-CLIPPY-001`.
- Session owner: test-release group.
- This record is records-only and is based directly on canonical `main@688465e94647d4c866f6b1d7b4884145b2f4a9da`.
- Final state of this round: `MERGE-BLOCKED / TEST-RELEASE-NOT-STARTED / FORMAL-RELEASE-NOT-STARTED`.

## Independently verified review gate
- Execution PR `#2323` is open/unmerged at exact head `1c314ef514f71e5a1320ddea0803078923a4858c`.
- Independent review handoff comment `#2323#issuecomment-5545425734` records `REVIEW-PASS-CLIPPY-001` for exact execution head `1c314ef514f71e5a1320ddea0803078923a4858c` and audited base `9e88a2e9c030fe05147460dfa580366cf9aa433d`.
- Reviewer PR `#2333@3311731b56b5effb347fbb37392550ee238356a0` is open/unmerged and records-only. Its base is the execution branch at exact SHA `1c314ef514f71e5a1320ddea0803078923a4858c`; it is not based on canonical `main`.
- Architecture PR `#2332@abf740153ef6ee5962c6da24f67b68a8b7f26f63` is open/unmerged and records-only. Its base is the execution branch at `373bc52ad1cc2052c32acd81be4606c0a18dd89b`; it is not based on canonical `main`.

## Protected-main facts
- Canonical GitHub `main` readback before any merge action: `688465e94647d4c866f6b1d7b4884145b2f4a9da`.
- Active ruleset: `main-merge-queue` (`15857448`), target `refs/heads/main`, enforcement `active`.
- Merge queue method: `SQUASH`; grouping strategy `ALLGREEN`; one entry built/merged at a time; 60-minute check-response timeout.
- Required status context: exactly `CI result`.
- Bypass actors: none; current user bypass: `never`.

## Deterministic merge-topology blocker
`#2323` does not target `main`. Its real PR base is `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`.

Canonical `main@688465e... -> 9e88a2e...` compare is `ahead_by=12`, `behind_by=0`. Those 12 commits are not records-only: they contain product changes including Electron messaging files and large Rust messaging changes. Representative exact compare facts include:
- `desktop/src/messaging-shell-v2.tsx`: `+90/-0`;
- `desktop/src/selfhosted-messaging-client-v2.ts`: `+94/-0`;
- `native/mahayana-messaging/src/community.rs`: `+169/-1`;
- `native/mahayana-messaging/src/engine.rs`: `+885/-27` at the parent-base comparison;
- `native/mahayana-messaging/src/service.rs`: `+597/-31` at the parent-base comparison;
- `native/mahayana-messaging/tests/m6_channels_topics_contract.rs`: newly added `+650` at the parent-base comparison.

Canonical `main@688465e... -> #2323@1c314ef...` is `ahead_by=34`, `behind_by=0`. It includes the parent 12-commit product delta plus the 22 commits between `9e88a2e...` and `1c314ef...`.

The fresh `REVIEW-PASS-CLIPPY-001` did **not** independently review this full 34-commit canonical-main delta. Its explicit review scope is the CLIPPY execution delta `373bc52ad1cc2052c32acd81be4606c0a18dd89b..1c314ef514f71e5a1320ddea0803078923a4858c`, exactly 4 commits / 6 files.

GitHub PR search finds no PR whose head is `codex/tfi-m6-repair` and whose purpose would carry that parent branch into canonical `main`. Therefore there is no verified bottom-of-stack protected-main merge path for `#2323` in the current topology.

## Stop decision
The test-release group did **not**:
- retarget `#2323` from `codex/tfi-m6-repair` to `main`, because that would silently expand the reviewed diff by the unreviewed parent/base product delta;
- invoke direct REST merge, force-push, update `main`, or use any ruleset bypass;
- merge `#2332` or `#2333` into their current execution-branch bases and misreport that as canonical-main acceptance;
- retarget stacked `#2332/#2333` to `main`, because that would likewise inherit the unreviewed execution/base stack;
- start packaged build, simulated-user E2E, evidence capture, test version tagging, prerelease publication, App Store/Play submission, or formal release.

Because the implementation PR cannot enter the `main` merge queue without changing the reviewed topology or first landing an unreviewed parent product stack, the mandatory MERGE gate is blocked before a `merge_group` or required `CI result` can legitimately run.

## Required next owner/action
Return to architecture + code-review governance. Establish a protected-main-safe bottom-of-stack topology for the 12-commit parent branch, and independently review every product delta that would become newly included in a PR targeting canonical `main`. Only after that reviewed parent path is accepted may `#2323` be re-evaluated for the active merge queue. Preserve exact heads and append-only review history; do not rewrite a pass onto an expanded diff.

After a real canonical-main merge succeeds and the exact accepted main SHA is read back, the test-release group may resume AGENTS.md §1D/§1E packaged build, canonical simulated-user E2E, complete video/screenshots/trace/report/log evidence, and test/prerelease work. Until then, all post-main/test-release artifacts are `N/A — gate not reached`, not skipped-as-pass.
