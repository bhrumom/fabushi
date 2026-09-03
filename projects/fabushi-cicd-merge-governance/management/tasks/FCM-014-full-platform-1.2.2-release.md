# FCM-014 — Fabushi 1.2.2 全平台正式发布

## 目标

从受保护 `main` 的当前产品基线发布统一版本 `1.2.2`，覆盖 Web/服务端控制面、macOS、Windows、Linux、iOS、Android，并复用仓库现有的 exact-SHA CI、签名、公证、App Store Connect、Google Play、GitHub Release、更新通道与回滚防护。

## 版本身份

- Marketing / desktop / native mobile version: `1.2.2`
- Android repository build identity: `8`（商店工作流仍使用单调 versionCode，避免 Play Console 冲突）
- iOS repository build identity: `8`（App Store Connect 工作流使用单调构建号，避免同日重跑冲突）
- 发布源必须是本任务 PR 通过保护合并后的 exact `main` SHA。

## 变更记录

- 修复 macOS App Store 包中 Computer Use 私有运行时的 plist 布局：源码清单改为 `ComputerHelper-Info.plist`，仅在真正的 Helper `.app/Contents/Info.plist` 中恢复 bundle 清单，避免 Transporter 将资源目录误判为缺少可执行文件的嵌套应用。
- 保持 MAS 构建 `--publish never`，并继续使用商店包布局/签名校验；Developer ID 桌面包仍执行完整私有 MCP handshake。
- 统一桌面、原生移动端和版本策略元数据为 `1.2.2`，Android/iOS repository build identity 顺延为 `8`。
- 继续使用现有 GitHub Actions exact-main release gates、GitHub Release/updater、Apple 官方签名/Transporter/App Store Connect、Google Play 和生产部署路径，不引入旁路凭据处理。

## 验收

- [ ] PR 与 merge-group required checks 全绿并通过受保护 merge queue。
- [ ] exact-main Electron macOS/Windows/Linux、Android、iOS、Computer control security、生产控制面部署全绿。
- [ ] post-main delivery 从同一 SHA 发布 immutable desktop Release，Updater metadata、SHA256 与 Latest 单调保护通过。
- [ ] Android 产物通过签名/安装验证并完成 Google Play 可验证交付。
- [ ] macOS MAS 与 iOS 包通过签名验证并上传 App Store Connect；不把 Apple App Review 当成自动化已完成事项。
- [ ] Web/服务端生产入口健康；桌面/移动平台启动、核心登录/消息/远程控制 fail-closed 合同由 exact-SHA runner 与可用真实设备验证。
- [ ] 回滚/失败路径由 immutable release、Latest 单调保护、exact-SHA source gates、旧版本保留及商店外部审核边界验证。

## 发布证据

合并后在本文件记录 exact main SHA、Actions run、Release/tag、商店 delivery、生产 smoke 与安装/启动验证结果；在证据产生前不得将本任务标记为完成。
