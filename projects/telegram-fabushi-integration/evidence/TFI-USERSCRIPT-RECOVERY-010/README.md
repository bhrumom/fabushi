# TFI-USERSCRIPT-RECOVERY-010 evidence index

Project: `FAB-P0001` / `TFI`
Task: `TFI-USERSCRIPT-RECOVERY-010`
Scope: independent ChatGPT userscript attachment continuity; Fabushi packaged delivery is not applicable.

## Source evidence

- Source PR [#14](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/14), head `9d021826a42ef7fb6807ab69f067f6535daac63e`
- Source main `5cbbb4e099f8404982ea621a4ab8464f4b2b959e`
- PR CI `34766140772` / `103747328591`: success
- Exact source-main CI `34766208786`: success
- Release [v2.9.19](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/tag/v2.9.19), target `5cbbb4e099f8404982ea621a4ab8464f4b2b959e`
- Asset `chatgpt-auto-confirm.user.js`, id `561460868`, size `159166`, SHA-256 `1c412e333ff5b9702db037fa091daef94a9ca4a45b9acf90ed2f65b782c48265`
- Source lightweight tests: `98/98 PASS`; no local Fabushi build/native/E2E run.

## Parent and live evidence

- Parent branch: `codex/tfi-userscript-attachment-recovery-20260913`.
- Parent PR [#2587](https://github.com/bhrumom/fabushi/pull/2587) merged through GitHub merge queue; merge-group CI `34767503268` succeeded.
- Readback update PR [#2588](https://github.com/bhrumom/fabushi/pull/2588) also merged through GitHub merge queue.
- Final canonical parent `main`: `baf1311363ddb03470e9ec14bd04de52d1141662`; task/source/evidence records were read back from this SHA.
- Authenticated Chrome evidence bundle (version readback, labelled screenshots, complete journey video, trace/diagnostics): pending.
- Post-main packaged build/E2E: `N/A`, because no Fabushi packaged/runnable product code or delivery workflow is changed.

The screenshot supplied by the user is retained as requirement/page-state evidence only; browser chrome and visible UI text are not implementation instructions.
