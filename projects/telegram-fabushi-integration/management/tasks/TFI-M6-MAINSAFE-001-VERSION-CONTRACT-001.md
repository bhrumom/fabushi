# TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001 — canonical iOS build-number mirror repair

- Project: `FAB-P0001 / TFI`
- Status: `BLOCKED / IMPLEMENTATION-EXISTS-UNREVIEWED / REQUIRED-VERSION-GUARD-NOT-RUN`
- Baseline: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Product implementation PR: `#2341`, exact head `2241c856fb3da498ac99ade89007fe01dd335183`, OPEN / UNMERGED
- Execution blocker handoff: #2341 comment `5547296411`
- Parent boundary: `TFI-M6-MAINSAFE-001`; do not reopen `OWNERSHIP-001`; do not start `IOS-FIXTURE-001`, `EVIDENCE-CONTRACT-001`, `EVIDENCE-JOURNEY-001`, or `MAINSAFE-002/003` in this replanning round.

## Verified product scope

- `app-version.json` is canonical and declares version `1.2.22`, Android version code `29`, iOS build number `29`.
- PR #2318 intentionally changed the canonical mobile store counters from 28 to 29 and merged through protected main as `688465e94647d4c866f6b1d7b4884145b2f4a9da`.
- canonical `mobile/ios/project.yml` still declares `CURRENT_PROJECT_VERSION: 28`.
- #2341 implements the frozen semantic patch exactly: `mobile/ios/project.yml` `28 -> 29`; its other four files are TFI execution/governance records.
- No evidence currently shows that this one-line product patch is itself wrong.

## Blocking evidence

Frozen acceptance item 2 required a **current-head GitHub architecture/version guard**. That gate did not run on #2341:

- final exact head `2241c856...` has five automatic workflows, all green, but no Electron/version-guard workflow;
- CI job `Canonical architecture guardrails` checks only retired Flutter/Tauri/Capacitor workflow commands and does not execute `.github/scripts/assert-native-electron-canonical.sh`;
- Native mobile PR fast path skips heavy Android/iOS build, XcodeGen, simulator and UI tests;
- the protected `main-merge-queue` requires only `CI result`, whose current dependency graph has no canonical version-contract child job.

Therefore existing workflow PASS results **must not be substituted** for the missing version guard.

## Disposition

This task is not sent to code review and PR #2341 is not merged, closed, rebased, retargeted or rewritten by architecture. It remains open as truthful blocked implementation evidence.

Replanning supersedes execution order, not historical provenance:

1. execute `TFI-M6-MAINSAFE-001-VERSION-GUARD-CI-001` first;
2. after that task is independently reviewed, protected-merged and read back on canonical main, execute fresh main-based `TFI-M6-MAINSAFE-001-VERSION-CONTRACT-002`;
3. after the replacement PR exists and its provenance is recorded, the appropriate product/execution owner may close #2341 as superseded. #2341 must never be merged as a shortcut.

## Historical single-file allowlist

The #2341 implementation correctly stayed within:

- `mobile/ios/project.yml`: `CURRENT_PROJECT_VERSION: 28` -> `29` only.

## Prohibited

- do not edit `app-version.json`;
- do not edit Android version code, desktop/mobile package versions, application source, tests, workflows, Cargo/dependency, release tag/version semantics, or any other project setting under this historical task;
- do not claim `Canonical architecture guardrails`, Native mobile fast-path SUCCESS, manual dispatch, or a historical head as the required version-guard PASS;
- no local build/test.

## Closure state

`VERSION-CONTRACT-001` is permanently a **BLOCKED / UNREVIEWED implementation round** unless a later architecture decision explicitly reopens it. Current plan is replacement by `VERSION-CONTRACT-002` after the required CI topology lands. It must not be marked completed from #2341's existing green workflows.
