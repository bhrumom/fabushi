# 80 — TFI-M6-MAINSAFE-001 VERSION-GUARD 阻塞重规划状态与验收 — 2026-09-05

- Project: `FAB-P0001 / TFI`
- Canonical baseline: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Architecture PR: `#2340`
- Blocked product PR: `#2341@2241c856fb3da498ac99ade89007fe01dd335183`
- Execution blocker: #2341 comment `5547296411`
- Architecture state: `ARCHITECTURE-VERSION-GUARD-BLOCKER-DIAGNOSED / ATOMIC-TASKS-REPLANNED`
- Downstream: execution not started by this architecture round; code review / merge / test release / stable release PAUSED.

## Root-cause status

**CI/GOVERNANCE GATE TOPOLOGY GAP.**

The historical `VERSION-CONTRACT-001` product patch itself is not demonstrated failing. Its one semantic change matches the frozen allowlist. The blocker is that the required acceptance evidence did not exist:

- protected ruleset `15857448` requires only `CI result`;
- `CI result` has no canonical version-contract child job;
- `Canonical architecture guardrails` is only a retired Flutter/Tauri/Capacitor workflow-command check;
- Native mobile PR success is a fast path with heavy iOS/Android steps skipped;
- Electron desktop contains the authoritative script execution but did not trigger for `mobile/ios/project.yml` and is not the protected required aggregate.

Therefore all existing #2341 workflow PASS results remain valid for what they actually ran, but **none is version-guard PASS**.

## Replanned tasks

### 1. TFI-M6-MAINSAFE-001-VERSION-GUARD-CI-001

- Requirement: `M6-PM-VG-R01`
- Acceptance: `M6-PM-VG-A01`
- State: `FROZEN / NOT_STARTED`
- Exact future allowlist: `.github/workflows/ci.yml` only, plus TFI records.
- Goal: execute existing `.github/scripts/assert-native-electron-canonical.sh` as a diff-selected CI child gate and make `CI result` depend on it.
- Stop if any other workflow/ruleset/script must change.

### 2. TFI-M6-MAINSAFE-001-VERSION-CONTRACT-002

- Requirement: `M6-PM-VR-R02`
- Acceptance: `M6-PM-VR-A02`
- State: `FROZEN / BLOCKED-BY-VERSION-GUARD-CI-001`
- Exact future product allowlist: `mobile/ios/project.yml` only, `CURRENT_PROJECT_VERSION 28 -> 29`.
- Must start from the newly read-back canonical main after VERSION-GUARD-CI-001 protected merge.
- Must automatically run the repaired canonical version child job and same-head `CI result`.

## Old task / PR disposition

`TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001` is now:

`BLOCKED / IMPLEMENTATION-EXISTS-UNREVIEWED / REQUIRED-VERSION-GUARD-NOT-RUN`.

PR #2341 remains OPEN / UNMERGED. Architecture does not close, rebase, retarget, force-push, review or merge it. It is durable evidence that the one-line implementation was attempted before the required-gate topology existed.

Once VERSION-GUARD-CI-001 is on canonical main and VERSION-CONTRACT-002 creates a fresh replacement product PR, the appropriate owner may close #2341 as superseded. It must never be merged to avoid the new guard.

## Downstream gates

No code-review session is authorized because there is no accepted implementation head for the new first task yet. No test-release or stable-release session is authorized because no replacement version repair has passed the repaired protected gate, and the separately frozen iOS fixture/evidence tasks remain unresolved.

The only next execution session authorized by this replanning is `TFI-M6-MAINSAFE-001-VERSION-GUARD-CI-001`.
