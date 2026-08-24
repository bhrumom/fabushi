# GBF-506 evidence index

Implementation paths: `desktop/src/messaging-shell-v2.tsx`, `desktop/src/messaging-shell.module.css`, `desktop/e2e/messenger.spec.ts`.

Visual reference: pinned reconstructed repository screenshot `docs/assets/router-settings.png`; behavior was independently implemented without copying bundled renderer/CSS.

| Gate | Evidence | Status |
|---|---|---|
| Lightweight local inspection | JSX/CSS diff review; no local renderer build | PASSED |
| PR TypeScript/Electron contract | PR #2106: CI/frontend `32725104017`, Host complete journey `32725104003`, Electron `32725103923` | PASSED; final consolidated rerun pending |
| Packaged Router visual evidence | `router-settings-modal` screenshot + video/trace/report for exact main SHA | PENDING |
| Protected-main + Release | SHA/tag/assets/readback | PENDING |

The task remains `IMPLEMENTED`, not completed, until packaged visual inspection and delivery gates pass.
