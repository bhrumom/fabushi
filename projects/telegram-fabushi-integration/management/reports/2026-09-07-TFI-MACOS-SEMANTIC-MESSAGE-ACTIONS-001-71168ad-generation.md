# TFI-MACOS-SEMANTIC-MESSAGE-ACTIONS-001 — 71168ad generation-freshness round

Status: `IN_PROGRESS`

Exact canonical failure: `71168adbeea65e998bb650ba3a4636911287636a`, Electron run `34058850412`, macOS job `101555620505`, diagnostics artifact `9996959351`.

The signed/notarized package is valid. The App MCP regression intentionally put the authored message beyond the 500-element snapshot cap, then used that old truncated snapshot generation for mutation. The live generation advanced by one and correctly failed closed. This round changes only the test controller discipline: fresh exact `find` immediately before mutation, with a bounded retry only for `stale_app_surface_generation`. Product stale-generation enforcement remains unchanged.

Global Dharma packaged parity passed in the same exact run. A second independent macOS test setup race in the returning-user performance case is tracked separately and is not hidden by this task.

Completion remains `PENDING` until required PR CI, protected merge, newer canonical-main Electron three-platform gate, same-SHA mobile/security/post-main, and required packaged visual evidence are all verified.
