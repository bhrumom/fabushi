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