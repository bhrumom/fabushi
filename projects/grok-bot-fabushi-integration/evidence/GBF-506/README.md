# GBF-506 evidence index

Implementation paths: `desktop/src/messaging-shell-v2.tsx`, `desktop/src/messaging-shell.module.css`, `desktop/e2e/messenger.spec.ts`.

Visual reference: pinned reconstructed repository screenshot `docs/assets/router-settings.png`; behavior was independently implemented without copying bundled renderer/CSS.

| Gate | Evidence | Status |
|---|---|---|
| Lightweight local inspection | JSX/CSS diff review; no local renderer build | PASSED |
| PR TypeScript/Electron contract | PR #2106 canonical seven-gate `32731980249` | PASSED |
| Packaged Router visual evidence | exact-main Electron `32733627050`; `router-settings-modal` screenshot + full video/trace/report retained | PASSED |
| Protected-main + Release | `f81588d3...`; delivery `32734915241`; `desktop-1.0.867` | PASSED |

GBF-506 is `RELEASED`.
