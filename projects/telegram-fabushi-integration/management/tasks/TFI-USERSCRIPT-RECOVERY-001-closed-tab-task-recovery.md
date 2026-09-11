# TFI-USERSCRIPT-RECOVERY-001 — 关闭标签页后的任务记录恢复

- Project ID: `FAB-P0001`
- Project Key: `TFI`
- Status: `IN_PROGRESS`
- Started: `2026-09-11T17:00:00+08:00`
- Updated: `2026-09-11T17:19:00+08:00`
- Source requirement: `source/2026-09-11-userscript-closed-tab-task-recovery.md`
- Requirement IDs: `TFI-USR-R01`–`TFI-USR-R06`
- Implementation repository: `bhrumom/fabushi-chatgpt-auto-confirm-userscript`
- Parent-record branch: `codex/tfi-userscript-workspace-recovery-20260911`
- Source branch: `codex/workspace-recovery-20260911`
- Baseline parent main: `e79ec333f70eb283435f66440beb0cc00e9d1bd4`
- Baseline userscript main: `34f23a570f2f8c4996761c7f7d0f521dd7b7017e` (`2.8.2`)
- Reproduced installed version: `2.9.2`

## Objective

Make every persisted Fabushi task record discoverable and safely recoverable after its owning ChatGPT browser tab closes, with in-place recovery in a new empty tab and race-safe refusal while the original tab is alive.

## In scope

- Upgrade the independently published userscript from the installed 2.9.2 baseline to 2.9.3.
- Show a first-class “恢复任务记录” control whenever another persisted workspace exists.
- Restore a closed workspace into the current empty ChatGPT tab.
- Preserve terminal task history as well as active/paused tasks.
- Preserve Web Locks mutual exclusion and the existing dedicated-tab fallback when the caller already owns tasks.
- Add dependency-light regression tests and update durable TFI source, WBS, acceptance, status, change, risk, dependency/action and evidence records.

## Out of scope

- Running work while Chrome/the extension is fully closed.
- Cross-browser-profile or cross-device synchronization of local task records.
- Changing ChatGPT server-side conversation retention.
- Product-wide Electron/iOS/Android behavior unrelated to the independent userscript.

## Dependencies

- Same-origin `localStorage`, `sessionStorage` and the Web Locks API on ChatGPT Web.
- Source repository release/version publication and Fabushi Marketplace update propagation.
- Authenticated ChatGPT live UI for post-release simulated-user evidence.

## Acceptance criteria

- [x] `TFI-USR-A01`: New empty tab visibly exposes recovery without opening Settings.
- [x] `TFI-USR-A02`: Closed workspace can be adopted in the current empty tab and retains its original owner identity, records and manual pause state.
- [x] `TFI-USR-A03`: Completed task records remain recoverable.
- [x] `TFI-USR-A04`: Original still-open tab causes fail-closed rejection; existing regression remains green.
- [x] `TFI-USR-A05`: Non-empty caller retains dedicated-tab fallback instead of overwriting its workspace.
- [x] `TFI-USR-A06`: Source PR is reviewed, CI-green and merged to userscript `main`.
- [x] `TFI-USR-A07`: Version 2.9.3 is published through the supported Marketplace/userscript update path.
- [ ] `TFI-USR-A08`: Live Chrome journey records step screenshots, complete video and diagnostic/action evidence for create → close tab → open new tab → recover record → open recorded conversation.
- [x] `TFI-USR-A09`: Parent TFI records merge through protected canonical `bhrumom/fabushi` main and are read back.

## Verification method and current result

| Check | Result | Evidence |
|---|---|---|
| JavaScript syntax (`node --check`) | PASS | local lightweight check, 2026-09-11 |
| Userscript unit/regression suite | PASS, 66/66 | `npm test`; includes two new closed-tab recovery cases |
| Existing live-tab duplicate refusal | PASS | regression suite |
| Open-source-first survey | COMPLETE | W3C Web Locks and Google Chrome storage/lifecycle references; decision below |
| Source PR/CI/merge | PASS | PR #1; source `main@9ace3f40858e0c8b56e87b39971f8b6741441200`; PR run `34582472715`; exact-main run `34582579268` |
| Marketplace publication | PASS | official raw-main endpoint reads 2.9.3; GitHub Release `v2.9.3`, release `386908798`, source + installable `.user.js` asset |
| Live simulated-user visual evidence | PENDING | must run after published version is installed |
| Parent protected-main merge/readback | PASS | PR #2509; merge queue; canonical `main@4363f07b186b9bee85004a3a2d6a5f0c5e9ef4f1`; all five PR checks PASS |

Local checks are intentionally limited to the small userscript test suite. No Fabushi application build, native test, package build, emulator, simulator or Electron E2E was run locally.

## Open-source-first survey and decision

- `w3c/web-locks` (W3C Software and Document License): confirms that same-origin tabs share one lock manager, a tab-lifetime exclusive lock is a supported ownership pattern, and `ifAvailable` is the race-safe non-waiting acquisition mechanism. Reused as the coordination model; no source copied and no dependency added.
- `GoogleChrome/chrome-extensions-samples` / `GoogleChrome/modern-web-guidance` (Apache-2.0): reinforces that durable extension state must live in storage rather than page globals and that session-scoped state must not be mistaken for durable identity. Adapted as a storage-tier design lesson; no code copied.
- A separate database, service worker or synchronization dependency was rejected because the existing same-origin task data is already durable enough for this bug; the missing piece is discoverable ownership recovery, not a new persistence backend.

## Implementation summary

- Candidate 2.9.3 makes orphaned workspaces visible through a top-level recovery control.
- An empty replacement tab atomically releases its empty identity lock, claims the closed workspace lock, switches its session identity, merges the latest stored records and restores the selected task in place.
- All task states remain recoverable for history; explicitly deleted task IDs remain excluded because deleted records are absent from the stored task array.
- If the caller already has tasks, the existing one-use dedicated-tab recovery path remains in use.

## Branch / commit / PR

- Source branch: `codex/workspace-recovery-20260911`
- Source commits: `71cad2ff1` (installed 2.9.2 lineage import), `be13bdefd` (recovery fix), `628317938` (CI)
- Source PR: `bhrumom/fabushi-chatgpt-auto-confirm-userscript#1` (squash-merged)
- Canonical source main: `9ace3f40858e0c8b56e87b39971f8b6741441200`
- PR CI: run `34582472715`, job `103209000224`, PASS
- Post-main CI: run `34582579268`, job `103209328563`, PASS
- Release: `v2.9.3`, release ID `386908798`, target `9ace3f40858e0c8b56e87b39971f8b6741441200`
- Parent record branch: `codex/tfi-userscript-workspace-recovery-20260911`
- Parent record commit: `94fd704017cd6b779f464c41a50c3f5124222801`
- Parent PR: `bhrumom/fabushi#2509`, merged through queue
- Parent canonical main readback: `4363f07b186b9bee85004a3a2d6a5f0c5e9ef4f1`

## Post-main / release / E2E evidence

Application-affecting task: required. Source main, post-main CI and release are `PASS`; live installed-browser journey is `PENDING`.

Required evidence bundle must bind userscript 2.9.3 source SHA, parent canonical main record SHA, Chrome platform/version, Marketplace/version source, journey ID and timestamp. It must retain step-labelled screenshots, a complete operation video, action trace/diagnostics and the unit/CI report. Passing assertions without that bundle do not close the task.

## Risks and blockers

- Existing installed 2.9.2 had been ahead of the public source repository's 2.8.2; commit `71cad2ff1` preserves that full lineage before the 2.9.3 fix.
- `localStorage` remains profile/origin-local and can be cleared by the user/browser; this change is recovery, not cloud backup.
- Browser installation and visual evidence are pending. Browser automation cannot open `chrome-extension://` management pages under its security policy, so the user must click the Fabushi extension's Marketplace update once; do not mark complete before the live journey passes.

## Next action

Ask the user to click “更新油猴脚本” for ChatGPT 自动确认 in the Fabushi extension. Then execute the live Chrome recovery journey with complete evidence and close the remaining installed-browser gate in a governed follow-up PR.
