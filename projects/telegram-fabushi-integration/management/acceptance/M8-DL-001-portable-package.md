# M8-DL-001 Portable Package Acceptance Trace

- Project: `FAB-P0001 / TFI`
- Task: `M8-DL-001`
- Round: `2026-08-26 independent installable/migratable Mini App`
- Current status: `TESTING`

| Requirement | Implementation | Objective verification | Evidence | Status |
|---|---|---|---|---|
| Independent package | `marketplace/packages/douyin-batch-downloader/1.0.0/app.tar.gz` + `fabushi-miniapp.json` | package exists; manifest declares GUI/MCP/CLI/local; SHA matches catalog | `evidence/M8-DL-001/README.md` | IMPLEMENTED |
| No app-specific platform backend | Downloader source/test removed from `ai-backend`; generic Marketplace router restored | dedicated CI asserts no `ai-backend/src/douyin_downloader.js` and no downloader registration | dedicated workflow | IMPLEMENTED |
| Local CLI | `.mahayana/plugin.json` -> `fabushi-plugin-cli --plugin douyin-batch-downloader` | dump manifest + Rust build/test | dedicated workflow | IMPLEMENTED |
| Local MCP | `.mcp.json` -> stdio `mcp-serve` on same plugin runtime | descriptor existence + runtime manifest/tool checks | dedicated workflow | IMPLEMENTED |
| Runtime safety | Rust allowlists, retries, byte cap, safe filenames, SHA-256, no browser-cookie scraping | Rust unit/contract tests | dedicated workflow | IMPLEMENTED |
| Marketplace install | `mahayana.external-release.v1` package source with SHA/size | Marketplace search/install tests + digest verification | dedicated workflow | IMPLEMENTED |
| Project identity | only `FAB-P0001 / TFI`; duplicate P0009 removed | portfolio validator + branch readback | portfolio check | IMPLEMENTED |
| PR acceptance | PR #2141 current-head required checks | GitHub Actions | pending run IDs | PENDING |
| Canonical main | protected merge + main readback | GitHub main SHA/readback | pending | PENDING |
| Product delivery | exact-main packaged E2E screenshots/video/trace/reports + Release | canonical post-main workflows + Release | pending | PENDING |

A row moves to `PASSED` only when its stated objective evidence exists. Implementation presence alone does not close the task.
