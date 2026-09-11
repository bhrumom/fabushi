# TFI-USERSCRIPT-RECOVERY-001 evidence index

Status: `IN_PROGRESS`

## Current evidence

- User screenshot, 2026-09-11: ChatGPT Web displays an empty 2.9.2 Fabushi task workspace after a replacement tab is opened; the top-level UI has no recovery control.
- Root-cause inspection: task array is stored under `fabushi-workbench-v2` in same-origin `localStorage`; task visibility is filtered by a per-tab `sessionStorage` identity.
- Local lightweight syntax check: PASS, 2026-09-11.
- Local userscript regression suite: PASS, 66/66, 2026-09-11; includes in-place recovery and completed-record recovery.
- Source PR: `bhrumom/fabushi-chatgpt-auto-confirm-userscript#1`, squash-merged to `main@9ace3f40858e0c8b56e87b39971f8b6741441200`.
- PR CI: run `34582472715`, job `103209000224`, PASS.
- Canonical source-main CI: run `34582579268`, job `103209328563`, PASS.
- Release: `v2.9.3`, release ID `386908798`, target `9ace3f40858e0c8b56e87b39971f8b6741441200`; attached `chatgpt-auto-confirm.user.js` (95,068 bytes).
- Live browser pre-update readback: currently installed root reports `data-version=2.9.2`, 2026-09-11; user-side update is still required.

## Pending closure evidence

- Successful installed update readback from 2.9.2 to published 2.9.3.
- Live Chrome create/close/reopen/recover/open-conversation journey screenshots, complete video, trace/diagnostics and timestamps bound to exact source SHA/version.
- Parent TFI project-record PR/protected merge/canonical-main readback.

No Fabushi application build or heavy test was run locally.
