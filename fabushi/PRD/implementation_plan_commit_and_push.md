# 提交与推送代码实施计划 (修订版)

本计划旨在将当前的变更提交并推送到远程仓库。根据您的要求，我们将移除本地的 MediaPipe 二进制依赖，转而使用网络安装。

## 用户审核请求

> [!IMPORTANT]
> **关于 MediaPipe 依赖调整**
> 我们已按照您的要求，取消了 MediaPipe 的本地离线方案。这意味着：
> 1. `native_libs/MediaPipe/` 目录将被删除。
> 2. `ios/MediaPipeTasksGenAI.podspec.json` 和 `ios/MediaPipeTasksGenAIC.podspec.json` 修复文件将被删除。
> 3. iOS 构建时将重新从网络下载 MediaPipe。
> 
> **注意**：`native_libs/llama.cpp` 仍处于 "dirty" 状态，本次提交将仅记录其状态偏移。

## 拟议变更

---

### [Component] iOS 平台与构建配置

#### [DELETE] [MediaPipe 离线资源](file:///Users/gloriachan/Documents/fabushi/fabushi/native_libs/MediaPipe/)
- 删除该目录及其包含的大型二进制压缩包。

#### [DELETE] [MediaPipe Podspec](file:///Users/gloriachan/Documents/fabushi/fabushi/ios/)
- 删除 `MediaPipeTasksGenAI.podspec.json`
- 删除 `MediaPipeTasksGenAIC.podspec.json`

#### [MODIFY] [Podfile](file:///Users/gloriachan/Documents/fabushi/fabushi/ios/Podfile)
- 保持 `TensorFlowLiteSwift` 的本地 podspec 修复（除非您也想删除它）。
- 确保最低部署目标仍为 iOS 16.0 以兼容最新 SDK。

---

### [Component] Flutter 会员与支付功能

#### [MODIFY] [pubspec.yaml](file:///Users/gloriachan/Documents/fabushi/fabushi/pubspec.yaml)
- 升级版本号至 `1.0.0+5`。
- 添加 `in_app_purchase` 依赖。

#### [NEW] [AppleIapService](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/services/apple_iap_service.dart)
- 全新的 iOS IAP 服务，处理产品查询、购买流程和交易恢复。

#### [MODIFY] [MembershipScreen](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/screens/membership_screen.dart)
- 整合 Apple IAP 服务，为 iOS 用户自动识别并启用 IAP 支付流程。

#### [MODIFY] [MembershipService](file:///Users/gloriachan/Documents/fabushi/fabushi/lib/services/membership_service.dart)
- 增加 `verifyAppleReceipt` 方法，支持通过后端 API v2 验证交易 ID。

---

### [Component] 后端 (Cloudflare Worker)

#### [NEW] [Apple IAP Handler](file:///Users/gloriachan/Documents/fabushi/fabushi/web/src/handlers/apple-iap.js)
- 实现收据验证逻辑，使用 Apple App Store Server API v2 进行交易验证。

#### [MODIFY] [Router](file:///Users/gloriachan/Documents/fabushi/fabushi/web/src/router.js)
- 注册 `/api/apple/verify-receipt` 路由。

#### [MODIFY] [Constants](file:///Users/gloriachan/Documents/fabushi/fabushi/web/src/config/constants.js)
- 定义 Apple IAP 商品 ID 与会员套餐的映射关系。

## 验证计划

### 自动化测试
1. 执行 `git status` 确认大文件已被删除且其他变更已正确记录。
2. 运行 `git diff` 检查 `Podfile` 和 `pubspec.yaml` 的改动。

### 手动验证
- 您在后续构建 iOS 时，需确保网络环境良好以便能够下载 MediaPipe。
