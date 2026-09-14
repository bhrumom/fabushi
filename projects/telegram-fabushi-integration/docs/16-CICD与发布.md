# CI/CD 与发布

- **项目**：Fabushi Telegram 全量融合
- **文档 ID**：DOC-16
- **版本**：v1.0
- **状态**：BASELINE
- **基线日期**：2026-08-22
- **源计划**：`../source/完整telegram融合进fabushi.txt`

> 本文档由源计划结构化拆分而来。源计划未明确的管理字段会标记为“项目管理补充/待确认”，避免把推导内容冒充既有事实。

CI 分层：

快速 PR：
- fmt
- clippy
- unit test
- protocol test
- TypeScript lint/typecheck
- focused E2E

完整合并：
- Rust workspace test
- Electron integration
- Playwright E2E
- iOS build/test
- Android build/test
- security scan
- migration test
- Docker integration

Nightly：
- load
- chaos
- protocol compatibility
- soak test
- large history
- large group

Release：
- Desktop artifact
- macOS notarization
- Windows signing
- Linux packages
- iOS archive
- Android bundle/APK
- server images
- release manifest
- SBOM
- checksum

## 2026-09-13 — GitHub immutable Marketplace delivery gate

Marketplace 相关 PR 的快速门禁至少运行 backend pure/HTTP contract（依赖可用时）、Rust formatter/unit/contract、frontend typecheck/build、Chrome extension syntax/package checks 和项目治理校验。PR exact-head workflow 必须证明实际 checkout 的工作树 SHA 等于 PR product head；merge queue 必须证明实际 SHA 等于当前 merge-group SHA。

合入 canonical `main` 后，对准确 SHA 使用可复用缓存执行 packaged Electron、Android、iOS、CLI 与任务相关 Marketplace/Chrome journeys。缓存只能加速，不能作为发布 provenance；必须记录 cache hit/miss、恢复 key、构建时长和 toolchain/source SHA。required journey 必须保留分步截图、完整操作视频、trace、HTML/test report/native logs，PASS/FAIL 均上传并与 SHA/version/platform/run/job/timestamp 绑定。

Release 只能在这些 exact-main gates 全部通过且固定 catalog artifact 的 digest/size/压缩格式核验成功后发布。桌面 Release 需由同一 lineage 生成可更新的 DMG、ZIP、`latest-mac.yml`、blockmap 及 Windows/Linux 对应资产；版本必须单调可比较。旧客户端 updater journey 默认是 advisory，只有任务明确要求时才升级为必需门禁。

本合同已在 M8-MARKET-003 的 accepted product SHA `f6a0d99c85a481999298a18cada6a9f10718a360` 上验证：Electron run `34800013097`、Native mobile run `34800013089`、Chrome run `34800013075` 和 post-main delivery run `34800500558` 均成功。Release `desktop-1.2.65` 的 target SHA 与该主线一致，包含 macOS DMG/ZIP、`latest-mac.yml`、blockmap、Windows/Linux updater/installable assets、SHA256 manifests 和 Chrome package/content manifest；证据 artifact 按 90 天保留至 `2026-12-13`。
