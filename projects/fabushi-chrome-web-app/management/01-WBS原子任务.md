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
| CWA-010 | Publish and make userscript v2.9.32 installable from the live Marketplace projection | CWA-006 + existing GitHub Release + protected platform deployment | CWA-R022; exact metadata, commit-bound artifact URL and live API readback | in-progress / online install contract verified; no-E2E exception | Ask user to refresh and retry; retain normal E2E gate exception |
| CWA-012 | Make installed Marketplace userscripts update from their own Tampermonkey-style `@updateURL` and display the metadata-authoritative version | CWA-005 + userscript metadata contract | CWA-R023; stale catalog does not block URL-based metadata/source update, identity and HTTPS checks; installed card shows script `@version` | in-progress / canonical `main@aa154989` package `0.6.14` passed; independent `v0.6.15` and local `0.6.15`/`2.9.41` readback verified; Web Store review and packaged interactive evidence pending | Await review; retain exact-main evidence and complete required packaged journey |

| CWA-013 | Rebuild Fabushi Chrome as Grok Bot 0.18 extension edition while preserving all approved current extension capabilities | pinned Grok baseline + CWA-006/007/008/010/012 capabilities | parity ledger, full-page Grok UI, Coordinator/Host/Runner contracts, existing-feature regression, same-run worker/app recovery, exact-HEAD packaged/Web Store evidence | in-progress / Spec active | Generate ledger and begin full-page renderer + Coordinator transport cutover |
