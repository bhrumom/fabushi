# Fix IAP Verification and Qwen Model Timeout Plan

## 1. 背景问题
iOS 端正在测试中遇到了两个阻碍发版的问题：
1. **Qwen 模型下载超时**: `QwenModelManager` 下载卡住了。控制台抛出了 DioException connection timeout (30秒被中止)。
2. **Apple IAP 验证失败**: 云端 Worker 校验收据失败，App Store Server API 返回 `401 Unauthorized`。

**401 报错原因分析**：
- StoreKit v2 API 中，如果不小心把 Sandbox 购买的 `transactionId` 发送到了 Production 环境 (`https://api.storekit.apple.com/inApps/v1/transactions/`)，部分情况下会返回 `401 Unauthorized` 而不是常规的 `404 Not Found`。
- `APPLE_ISSUER_ID`、`APPLE_KEY_ID`、`APPLE_BUNDLE_ID` 环境变量字符串由于人为复制粘贴导致带有结尾空格或换行符，从而使 JWT 签名无效。

## 2. 改进方案

### 服务端 (Cloudflare Worker)
**文件**: `web/src/handlers/apple-iap.js`
- 在 `generateAppleJWT` 函数和 `handleVerifyAppleReceipt` 函数中，对获取的 `APPLE_ISSUER_ID`, `APPLE_KEY_ID`, `APPLE_BUNDLE_ID` 应用 `.trim()` 处理，消除潜在的空白符格式问题。
- 在 `fetchTransactionInfo` 函数中，将请求环境降级的条件放宽：不仅遇到 `404` 降级读取沙盒，遇到 `401` 也 fallback 回传请求到 Sandbox URL 进行重试。

### 客户端 (Flutter)
**文件**: `lib/services/qwen_model_manager.dart`
- 将 Dio 的 `BaseOptions` 中的网络超时参数（`connectTimeout` 和 `sendTimeout`）从较短的 30 秒增加到 **5 分钟** (300秒) 以适应不稳定的海外网络和体积过大的文件。

## 3. 测试验证
1. 通过 `wrangler deploy` 重新部署 `web/` 的 Cloudflare Worker 代码。
2. 重启 Flutter 运行，确认 `MembershipScreen` 的沙盒充值能走通并激活会员。
3. 检查控制台或触发 AI 对话功能，确认 Qwen 模型的下载能维持连接直到下载完毕，不发生 30秒断连。
