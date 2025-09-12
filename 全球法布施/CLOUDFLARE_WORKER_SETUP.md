# Cloudflare Worker 后端配置指南

## 概述

本 Flutter 应用已配置为使用 Cloudflare Worker 作为后端服务。以下是配置和部署的详细说明。

## 配置步骤

### 1. 更新 Cloudflare Worker URL

编辑 `lib/config/cloudflare_config.dart` 文件，将以下 URL 替换为您实际的 Cloudflare Worker 部署地址：

```dart
// 当前配置的 Worker URL
static const String workerUrl = 'https://fabushi.bhrumom.workers.dev';
static const String productionWorkerUrl = 'https://fabushi.bhrumom.workers.dev';
```

### 2. 部署 Cloudflare Worker

确保您的 `native-web/deploy-package/worker.js` 文件已正确部署到 Cloudflare Workers。

### 3. 环境配置

您可以通过环境变量控制应用行为：

- `ENVIRONMENT`: 设置为 `production`、`staging` 或 `development`
- `USE_CLOUDFLARE_WORKER`: 设置为 `true` 启用 Cloudflare Worker（默认启用）
- `DEBUG`: 设置为 `true` 启用调试模式

## 文件结构

### 新增的配置文件

1. **`lib/config/cloudflare_config.dart`** - Cloudflare Worker 专用配置
2. **`lib/services/api_client.dart`** - 统一的 API 客户端
3. **`lib/services/worker_config.dart`** - Worker 特定配置管理
4. **`lib/services/cloudflare_worker_service.dart`** - Cloudflare Worker 服务封装

### 更新的文件

1. **`lib/config.dart`** - 主配置文件，添加了 Worker 支持
2. **`lib/services/app_settings.dart`** - 应用设置，支持动态后端切换
3. **`lib/services/auth_service.dart`** - 认证服务，使用新的 API 客户端
4. **`lib/services/membership_service.dart`** - 会员服务，使用新的 API 客户端

## API 端点映射

应用中的 API 调用已映射到以下 Cloudflare Worker 端点：

- **认证相关**: `/api/auth/*`
  - 登录: `POST /api/auth/login`
  - 注册: `POST /api/auth/register`
  - 验证: `GET /api/auth/verify`
  - 登出: `POST /api/auth/logout`

- **会员相关**: `/api/stripe/*`
  - 会员状态: `GET /api/stripe/membership-status`
  - 创建订阅: `POST /api/stripe/create-subscription`

- **支付宝**: `/api/alipay/*`
  - 创建订单: `POST /api/alipay/create-order`
  - 查询订单: `GET /api/alipay/query-order`

- **管理员**: `/api/admin/*`
  - 兑换码管理: `POST /api/admin/create-redeem-code`
  - 使用兑换码: `POST /api/admin/use-redeem-code`

## 测试模式

应用支持测试模式，可以在不连接真实后端的情况下进行开发和测试：

```dart
// 在应用设置中启用测试模式
await AppSettings.setTestMode(true);
```

## 错误处理

API 客户端包含以下错误处理机制：

- 自动重试（最多 3 次）
- 超时处理（30 秒）
- 网络错误恢复
- 统一的错误响应格式

## 调试

启用调试模式以查看详细的网络请求日志：

```dart
// 在 CloudflareConfig 中设置
static const bool debugMode = true;
```

## 部署检查清单

- [ ] 更新 `cloudflare_config.dart` 中的 Worker URL
- [ ] 确认 Cloudflare Worker 已正确部署
- [ ] 测试所有 API 端点
- [ ] 验证认证流程
- [ ] 测试会员功能
- [ ] 检查支付集成

## 故障排除

### 常见问题

1. **连接失败**: 检查 Worker URL 是否正确
2. **认证错误**: 确认 JWT token 处理正确
3. **CORS 问题**: 确保 Worker 配置了正确的 CORS 头
4. **超时**: 检查网络连接和 Worker 响应时间

### 日志查看

在调试模式下，所有 API 请求和响应都会记录到控制台。

## 支持

如果遇到问题，请检查：

1. Cloudflare Worker 日志
2. Flutter 应用日志
3. 网络连接状态
4. API 端点配置

---

**注意**: 请确保在生产环境中禁用调试模式，并使用正确的生产环境 Worker URL。