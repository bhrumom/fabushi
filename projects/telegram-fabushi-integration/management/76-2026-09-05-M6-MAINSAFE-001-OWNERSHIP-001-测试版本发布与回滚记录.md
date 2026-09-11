# TFI-M6-MAINSAFE-001-OWNERSHIP-001 测试版本发布与回滚记录

日期：2026-09-05（+08:00）

## 输入

- Project: FAB-P0001 / TFI
- Product PR: #2336
- Reviewed product head: `8760b7587f6d576262e5993a72b5c5112ff595db`
- Accepted canonical main: `dbf22b467d35c8af2a074896c355a41993c8c191`
- Accepted application version metadata: `1.2.22`; Android version code `29`; iOS canonical build number `29`

## 测试版本决定

**未发布测试版本。**

未创建：

- test tag
- GitHub pre-release/test release
- updater publication
- release assets
- stable release

原因：Electron desktop exact-main aggregate FAILURE，Native mobile exact-main aggregate FAILURE，且证据合同不完整。按照测试发布门禁，任何 required packaged/E2E/visual evidence gate 失败都不能豁免。

## 已产生但未发布的 CI artifacts

这些是失败轮的 CI 旁证，不构成 release assets：

- macOS installable artifact `9955167307` / `fabushi-electron-mac`, digest `sha256:6c1d9861e38f38fea57d848d2b30d975f9552b1e28be2e240ff8476a2812d023`, 90-day retention target met by workflow.
- macOS diagnostics artifact `9955150412` / `fabushi-electron-mac-e2e-diagnostics`, digest `sha256:1c0cfb484b90837cc176c629d39583bbf91a63a4fafb0c74ed91a4e73c0af782`.
- Windows installable artifact `9955145560` / `fabushi-electron-win`, digest `sha256:9e89aecc5b81905512e7a368cfd49ad917766674f8275eb67f0d1a53facb8535`.
- Windows diagnostics artifact `9955134590` / `fabushi-electron-win-e2e-diagnostics`, digest `sha256:c517cde32aa5986710f123e252d8d641d383d3f735dda8f6a7dbcce84a8dcba1`.
- Android reports/package artifact `9955288722` / `android-native-reports`, digest `sha256:ed071830633010e4b6a8d1238247e91cd166cd90acb94cdbdce94a6ebc1899ac`, retention 14 days.
- iOS failure result artifact `9955210308` / `ios-native-xcresult`, digest `sha256:db673bd9376c8a70426eed00ab1602ea19ae6d903b9c2ca955abc2687c63d635`, retention 14 days.

Linux produced no package/evidence artifact because canonical architecture guard failed before package/E2E.

## 回滚判断

本会话不执行 canonical-main 回滚，也不绕过保护回退产品 PR。#2336 已经通过受保护 merge queue 与 required `CI result` 合法进入 main；后续暴露的是 accepted-main 的版本配置与 iOS simulated-user acceptance 阻塞。

如果产品负责人判定 accepted main 必须回滚，应由独立、受审查的 revert PR 走相同 protected-main merge queue；本测试发布会话没有权限直接改写 main 历史。

## 风险

- `app-version.json` 与 `mobile/ios/project.yml` build number 不一致会阻断 desktop canonical architecture guard。
- iOS `testAccountSettingsAndMessagingFlow()` 当前可见 `Messaging unavailable`，说明 native messaging simulated-user acceptance 未通过。
- Android/iOS evidence retention 只有 14 天，低于本轮证据目标的 90 天。
- 现有通用 desktop journey 的视觉证据合同不足以证明一个完整 OWNERSHIP-001 packaged ownership journey。

## 恢复条件

只有后续独立产品/config/workflow 修复经过代码审查、protected-main 合并，并得到新的 accepted canonical-main SHA 后，才允许新开测试发布会话重新执行 packaged/native/evidence acceptance。