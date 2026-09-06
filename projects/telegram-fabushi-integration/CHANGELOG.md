# Changelog

## v1.0 — 2026-08-22

- 建立 Telegram → Fabushi 全量融合标准项目资料夹。
- 纳入原始总计划作为 Source of Truth。
- 建立产品、架构、协议、客户端、服务端、Agent、Mini Apps、支付、安全、测试、CI/CD、迁移、验收等专题文档。
- 建立 M0–M14 路线图与 WBS 原子任务。
- 建立验收追踪矩阵、风险登记、ADR、PR/Task/Status 模板。
- 所有工程任务状态保持 `NOT_STARTED`，等待基于 Fabushi 仓库当前事实回填。

## v1.1 — 2026-08-27

- 明确 Telegram 式全平台 UI/功能一致性：Web 是完整 Fabushi Host，不是独立 Marketplace 产品。
- Marketplace、SEO、内容搜索与 WebMCP 保留为主 Host 的扩展与公开分发能力。
- Web 与桌面继续共享 HostClient，Host Marketplace 改用统一 Mini App catalog。

## 2026-09-07 — Native iOS close-control AX fallback

- Recorded canonical `43ce998fd5fbcae032c179a8814de9ec08d03f4c` Native mobile run `34055531700`: Android passed while iOS failed because XCTest attempted `AXScrollToVisible` on the already-visible `remote-computer-close` Button and received `kAXErrorCannotComplete`.
- Added a test-only fallback that retains a screenshot and taps the center coordinate of the exact discovered element frame when the normal semantic element is present but not hittable; product behavior and the post-close disappearance assertion are unchanged.

## 2026-09-07 — iOS shell-overlay Marketplace recovery

- Recorded canonical `dca0fea5…` Native iOS failure from run `34056507262` / artifact `9996206512`.
- Replaced unsafe non-hittable close center-coordinate fallback with a fail-closed hittability path plus a remote-computer-only explicit shell-back fallback.
- Added legacy workbench recovery before Marketplace navigation while retaining the remote surface disappearance assertion.
