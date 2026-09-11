# TFI-USERSCRIPT-RECOVERY-003 evidence index

Status: `IN_PROGRESS`

## Current evidence

- User screenshots, 2026-09-11 Asia/Shanghai: ChatGPT displays “连接已中断。正在等待完整回复。” while Stop remains visible; recovery records appear in a top strip rather than the left task list.
- Scope clarification: this task changes only the independent userscript, not Fabushi application code.
- Source commit: `7fc049403d4afbfbe3ef3e7d8f14d6fa9465094c`.
- Source PR: `bhrumom/fabushi-chatgpt-auto-confirm-userscript#3`, merged.
- PR CI: run `34605769914`, job `103283692515`, PASS.
- Canonical source main: `3124c0aaa4e5cbd5b0fcbff663009289c18d5d49`.
- Exact-main CI: run `34605867308`, job `103284014156`, PASS.
- Release: `v2.9.5`, release ID `387070364`, exact target SHA above; `.user.js` asset ID `557331325`, 101,151 bytes.
- Parent records PR: `bhrumom/fabushi#2514`; all five PR-head checks PASS; merge-queue run `34606606642` PASS.
- Parent canonical main: `6baf6f0d19686cefdf1b9dea570035c13f172b97`, task record read back successfully.
- Local lightweight syntax: PASS.
- Local userscript regression suite: PASS, 69/69.
- Regression covers visible notice detection, transcript/plugin-root exclusions, per-conversation cooldown/two-refresh ceiling, preserved URL/token/dispatch identity, owner-tab grouping, state labels, removal of the top recovery strip and existing restore-lock behavior.

## Pending closure evidence

- Live installed-version readback for 2.9.5.
- Chrome/ChatGPT screenshots, complete operation video and diagnostics proving visible interruption → current-page reload → same task/session resumes without duplicate send.
- Chrome/ChatGPT screenshots proving current/recoverable tab groups and status-visible task rows.

No Fabushi application build, package or application E2E is applicable to this userscript-only task.
