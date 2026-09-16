# WBS 原子任务

| Task | Action | Dependency | Acceptance / evidence | Status | Next action |
|---|---|---|---|---|---|
| CWA-001 | Allocate P0011 and scaffold project | canonical registry | governance validator | passed | — |
| CWA-002 | Survey Chrome APIs and compare old Bridge | CWA-001 | official references + decision | passed | — |
| CWA-003 | Build three-module MV3 shell | CWA-002 | manifest/static contract | PR-passed | canonical CI |
| CWA-004 | Integrate Electron dual native hosts/runtime staging | CWA-003 | host/server tests | PR-passed | Electron/post-main delivery |
| CWA-005 | Add command parity/generation/Marketplace catalog | CWA-003/004 | contract/security tests | PR-passed | canonical CI |
| CWA-006 | Package, release and migrate Chrome profiles | CWA-005 + protected main | exact SHA CI/E2E/Release/profile evidence | in-progress | protected PR checks |

| CWA-007 | Official Chrome login and same-account MCP browser control plus GitHub Actions remote manual test | CWA-006/AAC/gateway/interactive Runner | CWA-R009..R012, CWA-R019..R021; exact-SHA CI/release/remote evidence | in-progress | Restore connector access, run remote Runner manual gate |
| CWA-008 | Userscript tab-recovery capability and crash watchdog | CWA-006 + TFI-USERSCRIPT-RECOVERY-011 | CWA-R013..R018; exact-SHA package/E2E/release | in-progress / Web Store pending review | Await review; capture live crash-recovery evidence and public listing proof |
| CWA-010 | Publish userscript v2.9.32 to the live Marketplace projection | CWA-006 + existing GitHub Release + protected platform deployment | CWA-R022; exact metadata and live API readback | in-progress / deployment pending | Merge protected PR and verify `api.ombhrum.com` returns 2.9.32 |
