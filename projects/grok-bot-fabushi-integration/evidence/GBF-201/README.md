# GBF-201 Evidence — Electron main audit

Pinned source: `7174a70567ae98ef534b0eebcbe66935f1471cc1`; M2 base main: `d8b502726dc14f0a7963f67f58e44ebfb9887b01`.

- `desktop/electron/main.cjs`: source->main diff is +197/-0, therefore current main strictly supersedes the pinned latest source in this file rather than losing source behavior.
- Current main already serves per-method `MAHAYANA_EDGE` and `NATIVE_EDGE` with trusted-sender enforcement.
- M2 removes the retired generic `fabushi:host` compatibility channel; current renderer routes Host calls through per-method edge channels only.
- Existing product/security fixes after the source branch are retained; no historical branch overwrite was used.

Verification: canonical Electron architecture guard, Feature Host bridge guard, auth entry guard, product UI contract, diff review.
