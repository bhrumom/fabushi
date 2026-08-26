# M8-DL-001 Evidence Index

## Current architecture evidence

### Independent installable package

- `marketplace/packages/douyin-batch-downloader/1.0.0/app.tar.gz`
- `marketplace/packages/douyin-batch-downloader/1.0.0/fabushi-miniapp.json`
- `marketplace/packages/douyin-batch-downloader/1.0.0/index.html`
- Package SHA-256: `6784eb6ade91ef75ff61717a232dd154c7a3fb28c093ce330bc7ca4857ace473`.
- Package size: `3069` bytes.
- Immutable package source commit: `7b02d8d00e0646e9bf4e90a129cbf203fcff015d`.
- Archive contents are self-describing: `.codex-plugin/plugin.json`, `.mahayana/plugin.json`, `.mcp.json`, `README.md`, `fabushi-miniapp.json`, `index.html`.
- Marketplace catalog publishes exactly that archive through `mahayana.external-release.v1` using the immutable source reference plus SHA-256/size.

### MCP / CLI / local runtime

- `.agents/plugins/plugins/douyin-batch-downloader/.mahayana/plugin.json` — CLI and shared runtime descriptor.
- `.agents/plugins/plugins/douyin-batch-downloader/.mcp.json` — local stdio MCP descriptor.
- `.agents/plugins/plugins/douyin-batch-downloader/.codex-plugin/plugin.json` — plugin metadata.
- The same three descriptors are embedded in `app.tar.gz` so migration does not require reconstructing them from repository paths.
- `third_party/mahayana/mahayana-rs/providers/official-miniapps/src/douyin_downloader.rs` — Rust resolve/download implementation.
- `third_party/mahayana/mahayana-rs/providers/official-miniapps/src/main.rs` / `lib.rs` — CLI and MCP runtime dispatch/manifest integration.

### Platform decoupling proof

- `ai-backend/src/douyin_downloader.js` is deleted.
- `ai-backend/test/douyin_downloader.test.js` is deleted.
- `ai-backend/src/miniapp_marketplace_http.js` contains only generic Marketplace routes and no Downloader-specific runtime registration.
- `.github/workflows/douyin-batch-downloader.yml` has explicit independent-package boundary assertions and checks archive descriptor contents.

## Governance evidence

- Canonical project remains `FAB-P0001 / TFI` at `projects/telegram-fabushi-integration/`.
- Feeder PR `#2136` supplied package/MCP/CLI/Rust implementation and was merged into the canonical task feature branch as `fb1478d0f9d52b9cdee32acac6fb1c7581ece680`.
- The duplicate imported `FAB-P0009 / DBD` project was removed; feature-branch `projects/PORTFOLIO.json` was restored to the same registered P0001-P0008 / `next_sequence=9` state as canonical main in `baed8e4c66badb0409d04eb15aeab8341af5362e`.
- `projects/douyin-batch-downloader-miniapp/**` no longer exists on the feature branch.

## Implementation / remediation commits

- Historical embedded prototype: `fd13a64b8f3e4dde58453df812f4787d5c3020eb` through `009c175d6b1b6454573f019ded84db01fc654ca7` — provenance only, not accepted architecture.
- Feeder package merge: `fb1478d0f9d52b9cdee32acac6fb1c7581ece680`.
- Portfolio identity cleanup: `baed8e4c66badb0409d04eb15aeab8341af5362e` plus duplicate-project removal commits.
- Remove app runtime from `ai-backend`: `81f6385f856251559f2ef64c29c3dd7df282620b`, `55594d4ebad5723c7aedb2db12430bd756ab61a5`, `8ac37f594032761aa03df29720162059b7075034`, `953724e369b3154245fce5c4a7896c8b20345e80`.
- Rust formatting remediation: `fc1f13be0acdf3b993695bc0aa5d5b190a22f989`.
- Initial portable-boundary CI: `892570d5004d194c648d93c77f931f0e7d1dc803`.
- Portable manifest: `88938ab40b6e3b4c65f2415e9fdda1c6470a961c`.
- Descriptor-embedded deterministic archive: `7b02d8d00e0646e9bf4e90a129cbf203fcff015d`.
- Catalog immutable source/digest pin: `bbbf69e1c1a8fb8541c1a9c2dfba605146b016b0`.
- Archive-content/digest CI enforcement: `0673d3f81a987796cafa217db0e98b8afa0d0b81`.
- Task record with final package contract: `fb93ed2e63dc474c5dec037cd7b338c73376f156`.

## Previous CI evidence

Feeder PR #2136 dedicated validation reached the Rust formatting gate and failed only because `douyin_downloader.rs` was not rustfmt-clean. The exact CI diff was read and applied in `fc1f13be0acdf3b993695bc0aa5d5b190a22f989`; semantic/build/package checks must be rerun on the canonical PR head and are not inferred from that historical run.

## Pending closure evidence

- Canonical PR #2141 latest-head required checks.
- Dedicated `Douyin Batch Downloader MiniApp` workflow success after independent-boundary/rustfmt/package fixes.
- Protected-main merge SHA and canonical-main readback.
- Exact-main packaged Mini App E2E with step screenshots, full operation video, trace/report/log bundle.
- Verified GitHub Release tag, target SHA and assets for the accepted main lineage.

Task status remains `TESTING`; package implementation is present, but closure is prohibited until pending current-head/main/post-main evidence exists.
