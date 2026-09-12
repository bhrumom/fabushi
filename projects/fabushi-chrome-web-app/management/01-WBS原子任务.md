# WBS 原子任务

| Task | Action | Dependency | Acceptance / evidence | Status | Next action |
|---|---|---|---|---|---|
| CWA-001 | Allocate P0011 and scaffold project | canonical registry | governance validator | passed | — |
| CWA-002 | Survey Chrome APIs and compare old Bridge | CWA-001 | official references + decision | passed | — |
| CWA-003 | Build three-module MV3 shell | CWA-002 | manifest/static contract | PR-passed | canonical CI |
| CWA-004 | Integrate Electron dual native hosts/runtime staging | CWA-003 | host/server tests | PR-passed | Electron/post-main delivery |
| CWA-005 | Add command parity/generation/Marketplace catalog | CWA-003/004 | contract/security tests | PR-passed | canonical CI |
| CWA-006 | Package, release and migrate Chrome profiles | CWA-005 + protected main | exact SHA CI/E2E/Release/profile evidence | in-progress | protected PR checks |
