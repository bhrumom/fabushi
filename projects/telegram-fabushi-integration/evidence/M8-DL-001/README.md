# M8-DL-001 Evidence Index

## Current architecture evidence

### Independent installable package

- `marketplace/packages/douyin-batch-downloader/1.0.0/app.tar.gz`
- `marketplace/packages/douyin-batch-downloader/1.0.0/fabushi-miniapp.json`
- `marketplace/packages/douyin-batch-downloader/1.0.0/index.html`
- Expected package SHA-256: `9b7aa85b751755cc776a884afba2927ceb661d7580c8b135826bc8760cc6ba75`.
- Marketplace catalog publishes the package through `mahayana.external-release.v1` using an immutable GitHub source reference plus SHA-256/size.

### MCP / CLI / local runtime

- `.agents/plugins/plugins/douyin-batch-downloader/.mahayana/plugin.json` — CLI and shared runtime descriptor.
- `.agents/plugins/plugins/douyin-batch-downloader/.mcp.json` — local stdio MCP descriptor.
- `.agents/plugins/plugins/douyin-batch-downloader/.codex-plugin/plugin.json` — plugin metadata.
- `third_party/mahayana/mahayana-rs/providers/official-miniapps/src/douyin_downloader.rs` — Rust resolve/download implementation.
- `third_party/mahayana/mahayana-rs/providers/official-miniapps/src/main.rs` / `lib.rs` — plugin runtime dispatch/manifest integration.

### Platform decoupling proof

- `ai-backend/src/douyin_downloader.js` is deleted.
- `ai-backend/test/douyin_downloader.test.js` is deleted.
- `ai-backend/src/miniapp_marketplace_http.js` contains only generic Marketplace routes and no Downloader-specific runtime registration.
- `.github/workflows/douyin-batch-downloader.yml` has an explicit independent-package boundary assertion to prevent the app runtime from drifting back into `ai-backend`.

## Governance evidence

- Canonical project remains `FAB-P0001 / TFI` at `projects/telegram-fabushi-integration/`.
- Feeder PR `#2136` supplied the package/MCP/CLI/Rust implementation and was merged into the canonical task feature branch as `fb1478d0f9d52b9cdee32acac6fb1c7581ece680`.
- The duplicate imported `FAB-P0009 / DBD` project was removed; feature-branch `projects/PORTFOLIO.json` was restored to the same registered P0001-P0008 / `next_sequence=9` state as canonical main in `baed8e4c66badb0409d04eb15aeab8341af5362e`.
- `projects/douyin-batch-downloader-miniapp/**` no longer exists on the feature branch.

## Implementation / remediation commits

- Historical embedded prototype: `fd13a64b8f3e4dde58453df812f4787d5c3020eb` through `009c175d6b1b6454573f019ded84db01fc654ca7` — retained only as provenance, not the accepted architecture.
- Feeder package merge: `fb1478d0f9d52b9cdee32acac6fb1c7581ece680`.
- Portfolio identity cleanup: `baed8e4c66badb0409d04eb15aeab8341af5362e` plus duplicate-project removal commits.
- Remove Downloader app runtime from `ai-backend`: `81f6385f856251559f2ef64c29c3dd7df282620b`, `55594d4ebad5723c7aedb2db12430bd756ab61a5`, `8ac37f594032761aa03df29720162059b7075034`, `953724e369b3154245fce5c4a7896c8b20345e80`.
- Rust formatting remediation from feeder CI evidence: `fc1f13be0acdf3b993695bc0aa5d5b190a22f989`.
- Portable-boundary CI: `892570d5004d194c648d93c77f931f0e7d1dc803`.
- Requirement/task architecture updates: `1c55a9e77f8334efad9f8c0b2e2e7acae3f5baef`, `a500e3a9c7794e20551af952c10b5cf54e928b9f`.

## Previous CI evidence

Feeder PR #2136 dedicated validation reached the Rust formatting gate and failed only because `douyin_downloader.rs` was not rustfmt-clean. The exact CI diff was read and applied in `fc1f13be0acdf3b993695bc0aa5d5b190a22f989`; semantic/build/package checks must be rerun on the canonical PR head and are not inferred from this historical run.

## Pending closure evidence

- Canonical PR #2141 reopened on latest head and current-head required checks.
- Dedicated `Douyin Batch Downloader MiniApp` workflow success after the independent-boundary/rustfmt fixes.
- Protected-main merge SHA and canonical-main readback.
- Exact-main packaged Mini App E2E with step screenshots, full operation video, trace/report/log bundle.
- Verified GitHub Release tag, target SHA and assets for the accepted main lineage.

Task status remains `TESTING`; package implementation is present, but closure is prohibited until the pending current-head/main/post-main evidence exists.
