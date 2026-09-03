# FCM-013 — Fabushi 1.2.1 全平台正式发布

## 目标

从受保护 `main` 的当前产品基线发布统一版本 `1.2.1`，覆盖 Web/服务端控制面、macOS、Windows、Linux、iOS、Android，并复用仓库现有的 exact-SHA CI、签名、公证、App Store Connect、Google Play、GitHub Release、更新通道与回滚防护。

## 版本身份

- Marketing / desktop / native mobile version: `1.2.1`
- Android repository build identity: `7`（商店工作流仍使用其单调时间型 versionCode，避免 Play Console 冲突）
- iOS repository build identity: `7`（App Store Connect 工作流使用单调构建号，避免同日重跑冲突）
- 发布源必须是本任务 PR 通过保护合并后的 exact `main` SHA。

## 变更记录

- 汇入 `1.2.0` 后已进入 canonical main 的远程设备会话 provider 绑定与相关稳定性修复。
- 保留并验证当前 main 中的 macOS MAS 嵌入式 Computer Use bundle 布局修复、签名/沙盒校验兼容以及 `--publish never` 商店构建安全约束。
- 统一桌面、原生移动端和版本策略元数据为 `1.2.1`，保证升级比较、安装包命名和发布渠道一致。
- 继续使用现有 GitHub Actions release gates；不引入新的第三方发布实现或凭据处理路径。

## 验收

- [ ] PR 与 merge-group required checks 全绿并通过受保护 merge queue。
- [ ] exact-main CI、Electron macOS/Windows/Linux、Android、iOS、Computer control security、生产控制面部署全绿。
- [ ] post-main delivery 从同一 SHA 发布新的 immutable desktop Release，Updater metadata 完整且 Latest 不发生降级。
- [ ] signed Android APK 发布；Google Play 工作流完成可验证交付（生产变更保持 review handoff 时不冒充已公开审核）。
- [ ] macOS MAS 与 iOS 包通过签名验证并上传 App Store Connect；不把 Apple App Review 当成自动化已完成事项。
- [ ] GitHub `v1.2.1` 全平台发布工作流（若触发）只接受 exact-main green gates，并产出跨平台可安装包。
- [ ] 实际验证官方 Web/控制面可访问；macOS 安装/启动验证成功；其余平台由 exact-SHA 平台 runner 的真实打包/安装/模拟器或虚拟显示测试作为发布证据。
- [ ] 回滚/失败路径由 immutable release、Latest 单调保护、exact-SHA source gates 与旧版本保留机制验证。

## 开源优先记录

本任务不新增功能实现；发布技术直接复用仓库已采用的 electron-builder/electron-updater、GitHub Actions、Apple 官方签名/Transporter/App Store Connect 流程与 Google Play 上传 Action，因此不存在需要重新选型或复制的新实现。
