# GBF-307 evidence index

## Implementation paths

- Rust/TypeScript settings contracts: `mahayana-host-protocol`, `frontend/apps/web/src/lib/mahayana-host/contracts.ts`.
- Host routing: `desktop/electron/host-process.cjs`, `mahayana-app-host/src/lib.rs`, `desktop/electron/main.cjs`.
- Readiness/usage: `desktop/electron/native-capability-handlers.cjs` and native-edge allowlists.
- UI/E2E: `desktop/src/messaging-shell-v2.tsx`, `desktop/src/messaging-shell.module.css`, `desktop/e2e/messenger.spec.ts`, `desktop/e2e/grok-visual-evidence.spec.ts`.

## Verification ledger

| Gate | Evidence | Status |
|---|---|---|
| Lightweight local inspection | changed Electron CJS syntax and `git diff --check` passed; no build/test | PASSED |
| PR code-head checks | [PR #2106](https://github.com/bhrumom/fabushi/pull/2106), one commit; canonical seven-gate `32731980249` on `4d8d3a6a...` | PASSED |
| Protected-main merge/readback | merge-group CI `32733468063`; canonical main `f81588d33c1f10610ed0d0e4b147ae239b72b3a3` | PASSED |
| Canonical-main packaged E2E | Electron `32733627050`; native mobile `32733627056`; screenshots/video/trace/report retained for Windows/macOS/Linux and Android/iOS | PASSED |
| GitHub Release | delivery `32734915241`; [desktop-1.0.867](https://github.com/bhrumom/fabushi/releases/tag/desktop-1.0.867), exact target SHA, `.exe`, blockmap and `latest.yml` | PASSED |

GBF-307 is `RELEASED`.
