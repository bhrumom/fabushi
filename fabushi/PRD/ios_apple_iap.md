# iOS 会员充值接入 Apple In-App Purchase

## 需求概述

将 iOS 端会员充值支付从支付宝 APP 支付改为 Apple In-App Purchase (IAP)，符合 App Store 审核指南 3.1.1。

## 变更范围

- **iOS 端**：会员充值自动使用 Apple IAP，隐藏支付宝入口
- **Android 端**：保持支付宝 APP 支付，不变
- **Web/桌面端**：保持支付宝网页支付，不变
- **支付宝代码**：完整保留，用于未来商城实物商品购买

## 技术方案

### 新增文件
- `lib/services/apple_iap_service.dart` — Apple IAP 封装（单例，产品查询/购买/恢复购买，获取 transactionId）
- `web/src/handlers/apple-iap.js` — Cloudflare Worker 服务端验证逻辑 (实现 ES256 JWT 并在 Apple v2 API 验证)

### 修改文件
- `pubspec.yaml` — 添加 `in_app_purchase: ^3.2.0`
- `lib/core/config/app_config.dart` — 新增 `appleVerifyReceiptUrl`、`enableAppleIAP`
- `lib/services/membership_service.dart` — 新增 `verifyAppleReceipt()` 后端调用
- `lib/screens/membership_screen.dart` — iOS 平台路由到 Apple IAP，增加"恢复购买"按钮

### 支付流程（iOS）
1. 用户选择套餐 → `_getPaymentMethodForPlatform()` 返回 `'apple_iap'`
2. 调用 `AppleIapService.purchase(priceType)` 发起 Apple 支付 (非消耗型调用发起自动续期订阅)
3. IAP 回调 `onPurchaseSuccess` → 取出 `purchase.purchaseID` ( transactionId )
4. `MembershipService.verifyAppleReceipt()` 发送 `transactionId` 到云端 Worker
5. 后端 Worker 携带通过 `.p8` 生成的 ES256 JWT 访问 App Store Server API v2，并解码 JWS 载荷。
6. 后端验证通过 → 记录购买历史，根据 `expiresDate` 激活会员 → 刷新 UI

### 待办
- [x] 代码库前端支持获取 TransactionId 并请求新端点
- [x] 部署实现 `/api/apple/verify-receipt` 接口
- [ ] 按照 [apple_iap_v2_setup_guide.md](apple_iap_v2_setup_guide.md) 创建产品并录入环境变量
- [ ] Sandbox 环境真机测试
