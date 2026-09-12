# TFI-USERSCRIPT-RECOVERY-006 evidence index

- Project: `FAB-P0001` / `TFI`
- Task: `TFI-USERSCRIPT-RECOVERY-006`
- Scope: independent ChatGPT userscript only; Fabushi packaged application post-main delivery is `N/A` because no application source, build, dependency, workflow, or packaged runtime was changed.
- Source baseline: userscript `main@76856ab7c0c4aa6edd94cb0941dc112bf7db2516`, version `2.9.9`.
- Implementation commit: `f3c6d4e098741b3baac703891f4207a2eadfeff6`.
- Source PR: [#10](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/10), merged to source `main`.
- Source canonical main: `fbd7b2bd8b549c1fb61acc29dc3a4af99cba1e50`.
- Source PR CI: [run `34701330510`](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/actions/runs/34701330510), job `103573506968`, success.
- Exact source-main CI: [run `34701374228`](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/actions/runs/34701374228), job `103573628135`, success.
- Source Release: [`v2.9.10`](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/releases/tag/v2.9.10), release `387608537`, target `fbd7b2bd8b549c1fb61acc29dc3a4af99cba1e50`.
- Release asset: `chatgpt-auto-confirm.user.js`, asset `559456795`, 112931 bytes, SHA-256 `3cc9c4e0a223440fd2c7a21d670fee88c3f9af0a8d4e806421fcb2ba30c4b4dd`.
- Local lightweight verification: `node --check chatgpt-auto-confirm.user.js` PASS; `npm test` 81/81 PASS; no local Fabushi application build/native/E2E run.

## Required live evidence — pending

The following evidence is intentionally not claimed yet and must be captured against installed userscript `2.9.10` and the exact source Release lineage:

- version/root `data-version` readback;
- step-labelled screenshots for loading spinner, task state “正在加载”, fully rendered conversation, and resumed supervision;
- one complete video covering the whole loading → loaded → continued-supervision journey;
- trace/diagnostics and browser console/network evidence where supported;
- parent TFI records PR, protected checks, merge SHA, and canonical-main readback.
