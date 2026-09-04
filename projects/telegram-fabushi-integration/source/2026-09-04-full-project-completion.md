# 2026-09-04 — 完整实现 TFI 项目要求

## 用户要求

用户要求“完全实现项目文件夹里面的第一个项目，完全按照它的那个要求去做，完全实现所有”。按 `projects/PORTFOLIO.json`，第一个注册项目是 `FAB-P0001 / TFI / telegram-fabushi-integration`。

## 归一化范围

本轮要求被解释为：继续推进 TFI 源计划和现行 WBS 中所有尚未达到 `RELEASED` 的功能、跨端集成、旧栈迁移、验证与交付闭环；不把已有代码、未合并分支或单元测试误记为完成。用户未要求复制 Telegram 品牌、专有资产或依赖 Telegram 官方 API，因此继续遵守项目既有自研协议、自建服务、Rust canonical core 和许可证边界。

## 执行边界

- 复用 `FAB-P0001` 及其既有 `TFI` 命名空间，不创建重复项目。
- 以 `main` 上的 `projects/telegram-fabushi-integration/`、源计划、WBS、验收矩阵和实时 GitHub 事实为准。
- 任何功能必须进入 canonical `native/mahayana-messaging` 或已批准的 Mahayana Host/Pay/MiniApp 边界；不得新增第二套消息、联系人、支付或 Mini App 真相源。
- 本机只做轻量静态检查；构建、原生/集成/E2E、打包、Release 和部署验证必须由 GitHub Actions 完成。

## 开源优先调研基线

本轮在实现前检查了成熟官方项目：

| 项目 | 学习/复用结论 | 许可证与边界决定 |
|---|---|---|
| [matrix-org/synapse](https://github.com/matrix-org/synapse) | 参考自建 homeserver 的分层部署、反向代理、同步/联邦边界和可运维性；不直接采用其 Python/Matrix 协议。 | Apache-2.0；只吸收公开架构经验，Fabushi 仍使用自有 Rust Protocol v2 与 self-hosted gateway。 |
| [element-hq/element-web](https://github.com/element-hq/element-web) | 参考成熟 Web/Electron Messenger 的信息架构、跨端客户端组织和完整交互测试思路；不复制 UI 资产或代码。 | AGPL/GPL/商业多许可证，且含 Element 商业许可边界；不直接引入依赖，保持 Fabushi 自有 UI 与品牌。 |
| [signalapp/libsignal](https://github.com/signalapp/libsignal) | 参考 Rust 实现、Java/Swift/TypeScript 跨语言暴露方式及 Double Ratchet/X3DH 类密钥生命周期测试边界；先做独立威胁/许可证审查再决定是否依赖。 | AGPL-3.0；当前不直接 vendoring，M13 以协议边界、测试策略和许可证兼容性为前置门槛。 |

## 初始决策

采用“阶段化闭环 + canonical-main 交付”策略：优先处理最早未完成且能解除后续依赖的消息/媒体/联系人/群组链路，再推进频道、通话、移动端、高级 IM、安全和 M14 旧栈退出。每个阶段都必须有实现、测试、权限/错误处理、可观测性、项目记录、受保护合并、canonical-main packaged E2E 证据和适用的 Release 证据，才能晋级状态。
