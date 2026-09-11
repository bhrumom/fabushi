# TFI-USERSCRIPT-RECOVERY-004 — 热更新工作区交接与持续目标恢复

- Project ID: `FAB-P0001`
- Project Key: `TFI`
- Task ID: `TFI-USERSCRIPT-RECOVERY-004`
- Status: `IN_PROGRESS`
- Started: `2026-09-11T23:00:00+08:00`
- Updated: `2026-09-11T23:45:00+08:00`
- Source: `source/2026-09-11-userscript-hot-reload-workspace-handoff.md`
- Requirements: `TFI-USR-HR-R01`–`TFI-USR-HR-R05`
- Source baseline: userscript `main@3124c0aaa4e5cbd5b0fcbff663009289c18d5d49` (`2.9.5`)
- Parent baseline: `bhrumom/fabushi main@6baf6f0d19686cefdf1b9dea570035c13f172b97`
- Source branch: `codex/userscript-hot-reload-workspace-handoff-20260911`
- Parent branch: `codex/tfi-userscript-hot-reload-handoff-20260911`

## Objective

Make same-document userscript replacement atomically hand the tab workspace from the old instance to the new instance, so completed Work replies continue into fresh validation conversations instead of becoming orphaned recoverable records.

## In scope

- Awaitable old-instance shutdown and lock-release completion.
- Same-document handoff retry without weakening true duplicate-tab isolation.
- Complete duplicate UI/style cleanup.
- Focused userscript regression, release and live readback.

## Out of scope

- Fabushi application code/build/package.
- Cross-device/cloud task sync.
- Changes to the planner contract.

## Acceptance criteria

- [x] `TFI-USR-HR-A01`: A replacement instance retains the original `tabId` after an asynchronously released same-document lock.
- [x] `TFI-USR-HR-A02`: A separate duplicated tab whose owner remains alive still receives a distinct `tabId`.
- [x] `TFI-USR-HR-A03`: Startup/shutdown leaves exactly one userscript root/style in the document.
- [x] `TFI-USR-HR-A04`: Resumable continuous task state remains owned and auto-startable after replacement, allowing final Work processing to queue a fresh review.
- [x] `TFI-USR-HR-A05`: Source syntax and full lightweight regression pass on PR head and exact source main.
- [x] `TFI-USR-HR-A06`: Monotonically newer userscript Release is published from accepted source main.
- [ ] `TFI-USR-HR-A07`: Live Chrome readback shows one workbench instance and continuous Work → review operation.
- [x] `TFI-USR-HR-A08`: Parent records merge/readback through protected main.

## Open-source-first survey

- W3C Web Locks API specification (W3C document license): lock release is queued after the lock callback's waiting promise settles; the `request()` returned promise resolves only after release. This directly explains why synchronous shutdown followed by immediate `ifAvailable` acquisition can fail. Adapt by making shutdown completion awaitable and retrying only for a proven same-document replacement; no code copied.
- MDN Web Locks API documentation (CC BY-SA 2.5 for documentation): confirms `request()` returns a promise resolved after the lock is released and `ifAvailable` intentionally fails immediately. Used to validate the lifecycle model; no dependency or copied code.
- Greasemonkey upstream (GPL-3.0): history/navigation can cause userscript re-execution, supporting idempotent root cleanup and explicit instance replacement. No GPL code copied and no dependency added.

## Verification method

- Local lightweight only: `node --check` and jsdom userscript tests. No Fabushi application build/test.
- GitHub: source PR/exact-main CI and userscript Release provenance.
- Live: installed-version readback, one-root check and real continuous-task Work → review journey.

## Implementation / evidence

- Live read-only observation through the user-requested Computer plugin: route `6aa40d6e-4c0c-83e8-b016-9df98acb467e` has a complete assistant final reply, but multiple Fabushi launch controls coexist and the expanded instance owns no tasks, is paused, and reports zero scans; the missing task is exposed as a recoverable foreign workspace on `/`.
- Userscript version: `2.9.6`.
- Source commit: `e51f9bad16190fa2c45a9b9d4b01b4412f1a5da5`.
- Source PR: `bhrumom/fabushi-chatgpt-auto-confirm-userscript#4`, merged.
- PR CI: run `34614674038`, job `103313507289`, PASS.
- Canonical source main: `448d4d8f83d5e9e558ebd17cafad2a3ea426613f`.
- Exact-source-main CI: run `34614827011`, job `103314015767`, PASS.
- Release: `v2.9.6`, release ID `387136022`, target exact source main; asset ID `557478855`, 102,370 bytes.
- Lightweight local syntax: PASS; regression: PASS, 70/70.
- Parent records PR: `bhrumom/fabushi#2518`, PR-head checks run `34615906329` (five required checks PASS), squash-merged.
- Canonical parent main readback: `9548f44514ef63e23a812c9645cdf9bc048b700d`; task/source/evidence/WBS/acceptance/risk/dependency/action/status/changelog records present.
- Bootstrap captures the prior same-window instance, awaits its shutdown, tracks the Web Lock request's released promise and only boundedly retries the original owner when replacement was proven in the same `window`.
- Existing duplicate-tab test continues to prove a different live tab gets a distinct workspace.
- New hot-replacement regression proves original `tabId`/task ownership, exactly one root/style, and Work final → `phase=review`, `state=queued`, old URL cleared.
- No Fabushi application code/build/package is in scope or was run.

## Risks and blockers

- Waiting for a same-document handoff must never steal a lock held by another live tab.
- Old installed builds cannot return an explicit shutdown promise; the new bootstrap must remain compatible by yielding and boundedly reacquiring only when an old instance existed in this same `window`.
- Live proof requires the browser to update from 2.9.3 to the fixed version.

## Next action

Update the live browser from 2.9.3 to 2.9.6, verify exactly one workbench instance and run a continuous Work → fresh review journey; keep the task `IN_PROGRESS` until the complete visual/diagnostic bundle is captured.
