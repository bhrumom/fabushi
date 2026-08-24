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
| PR code-head checks | [PR #2106](https://github.com/bhrumom/fabushi/pull/2106): CI `32725104017`, Host `32725104003`, Electron `32725103923`, security `32725103937`, native mobile `32725103902`, portfolio `32725103915` | PASSED; final repaired-head rerun pending |
| Protected-main merge/readback | merge SHA + canonical file readback | PENDING |
| Canonical-main packaged E2E | exact SHA/version/platform/run + screenshots/video/trace/report/log | PENDING |
| GitHub Release | tag/target SHA/installable/updater assets | PENDING |

This task remains `IN_PROGRESS` until every required application-delivery gate is evidentially complete.
