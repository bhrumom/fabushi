# TFI-USERSCRIPT-RECOVERY-003 — 连接中断刷新与左侧任务分组

- Project ID: `FAB-P0001`
- Project Key: `TFI`
- Task ID: `TFI-USERSCRIPT-RECOVERY-003`
- Status: `IN_PROGRESS`
- Started: `2026-09-11T21:20:00+08:00`
- Updated: `2026-09-11T21:46:00+08:00`
- Source: `source/2026-09-11-userscript-disconnect-refresh-grouped-sidebar.md`
- Requirements: `TFI-USR-DS-R01`–`TFI-USR-DS-R06`
- Source baseline: userscript `main@db663373e88b603350c24a73aedb991835509b2a` (`2.9.4`)
- Parent baseline: `bhrumom/fabushi main@d8bb64f44a7d97b38d8ac10d2193c8b1cb95f0f4`
- Source branch: `codex/userscript-disconnect-grouped-sidebar-20260911`
- Parent branch: `codex/tfi-userscript-disconnect-sidebar-20260911`

## Objective

Detect ChatGPT's explicit interrupted-connection notice and safely refresh the bound conversation without duplicate dispatch, while moving recoverable workspace records into a tab-grouped, status-visible left task list.

## In scope

- Dedicated visible page-notice detection and finite current-route refresh.
- Preserve durable task/session identity through refresh.
- Current/recoverable tab workspace groups in the left sidebar.
- Per-task state, round and active indicator; in-group restore action.
- Userscript source/tests/release and TFI records.

## Out of scope

- Fabushi application code or application packaging.
- Generic network-health monitoring.
- Changes to prompt semantics or abnormal-end resend count.

## Acceptance criteria

- [x] `TFI-USR-DS-A01`: Exact visible page notice is detected; identical text inside ChatGPT messages or the plugin panel is ignored.
- [x] `TFI-USR-DS-A02`: Detection records waiting state, persists current task/session ownership and requests one current-page refresh without dispatching a message.
- [x] `TFI-USR-DS-A03`: Persistent notice cannot cause an unbounded refresh loop and leaves a clear waiting state when recovery is exhausted.
- [x] `TFI-USR-DS-A04`: Sidebar groups current and recoverable tasks by owner tab; top recovery strip is removed.
- [x] `TFI-USR-DS-A05`: Every task row exposes state and round; current running task is visually distinct; each recoverable group exposes recovery.
- [x] `TFI-USR-DS-A06`: Source syntax and complete lightweight regression suite pass on PR head and exact source main.
- [x] `TFI-USR-DS-A07`: Monotonically newer userscript Release is published from accepted source main.
- [ ] `TFI-USR-DS-A08`: Live Chrome evidence verifies disconnect refresh and grouped sidebar behavior.
- [ ] `TFI-USR-DS-A09`: Parent governance records merge through protected main and are read back.

## Open-source-first survey

- `microsoft/playwright` (Apache-2.0): official `page.reload()` behavior reinforces treating reload as a navigation event and asserting readiness after it rather than assuming recovery from the call alone. Adapted as a finite reload ticket followed by normal DOM inspection; no code copied and no dependency added.
- W3C WAI-ARIA Authoring Practices (W3C document license): disclosure/tree guidance supports explicit grouped hierarchy and keyboard-operable actions. Adapted with semantic group labels and ordinary buttons; no code copied.
- `microsoft/vscode` / `vscode-docs` (MIT): Explorer/Tree View and decoration patterns validate showing hierarchy and compact status decoration together in a sidebar. Adapted as owner-tab groups with state badges; no code copied.
- A new UI framework or automation dependency is rejected because the userscript already owns a small plain-DOM workbench and durable recovery model.

## Verification method

- Local, lightweight only: JavaScript syntax plus existing jsdom userscript regression suite. No Fabushi app build/test.
- GitHub: source PR CI, exact-source-main CI and userscript Release provenance.
- Live: published-version Chrome/ChatGPT screenshots, full operation video and diagnostics for the requested journey.

## Implementation / evidence

- Userscript version: `2.9.5`.
- Source commit: `7fc049403d4afbfbe3ef3e7d8f14d6fa9465094c`.
- Source PR: `bhrumom/fabushi-chatgpt-auto-confirm-userscript#3`.
- PR CI: run `34605769914`, job `103283692515`, PASS.
- Canonical source main: `3124c0aaa4e5cbd5b0fcbff663009289c18d5d49`.
- Exact-source-main CI: run `34605867308`, job `103284014156`, PASS.
- Release: `v2.9.5`, release ID `387070364`, target exact source main; attached `chatgpt-auto-confirm.user.js`, 101,151 bytes.
- Lightweight local syntax: PASS.
- Lightweight regression: PASS, 69/69.
- Detector walks visible page text and excludes `[data-message-author-role]` plus the plugin root.
- Recovery executes before normal generation classification, persists an attempt counter per canonical conversation URL, waits 15 seconds between attempts and stops after two.
- Sidebar renders semantic current/recoverable owner groups, status-colored task rows and one recovery action per foreign owner group; the former top recovery strip was removed.
- No Fabushi application code, build, package or application E2E is in scope or was run.

## Dependencies

- Existing 2.9.4 route ownership, bounded route hydration recovery, workspace lock and recovery-ticket model.
- Signed-in ChatGPT test surface for live acceptance.

## Risks and blockers

- ChatGPT may alter or localize the interruption wording; exact known phrase is authoritative for this task.
- A persistent upstream outage could survive refresh; finite attempts must preserve the task instead of looping.
- Installed browser version may remain older until the userscript/extension update is applied.

## Next action

Install/update the live browser to 2.9.5, run the requested disconnect-refresh and grouped-sidebar journeys with complete visual/diagnostic evidence, then merge/read back this parent record stream.

