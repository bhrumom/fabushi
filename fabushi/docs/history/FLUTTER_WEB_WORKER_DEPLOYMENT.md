# Flutter Web 部署到 Cloudflare Worker 指南

本指南将帮助你将 Flutter Web 应用部署到 Cloudflare Worker，同时集成完整的后端 API 功能。

## 🏗️ 架构说明

这个部署方案将 Flutter Web 和后端 API 合并到一个 Cloudflare Worker 中：

- **静态文件服务**: 服务 Flutter Web 构建的静态文件
- **API 后端**: 提供完整的用户认证、支付、会员管理等功能
- **数据存储**: 使用 Cloudflare KV 存储用户数据
- **文件存储**: 使用 Cloudflare R2 存储媒体文件
- **邮件服务**: 使用 Cloudflare Email Workers 发送邮件

## 📋 前置要求

1. **Flutter SDK**: 确保已安装 Flutter
2. **Wrangler CLI**: Cloudflare 的命令行工具
3. **Cloudflare 账户**: 需要有 Cloudflare 账户并已登录

### 安装 Wrangler CLI

```bash
npm install -g wrangler
```

### 登录 Cloudflare

```bash
wrangler login
```

## 🚀 部署步骤

### 1. 构建 Flutter Web 应用

```bash
cd 全球法布施
flutter clean
flutter pub get
flutter build web --release --web-renderer html
```

### 2. 配置 Cloudflare Worker

确保 `web/wrangler.toml` 配置正确：

```toml
name = "fabushi-flutter-web"
main = "worker.js"
compatibility_date = "2024-06-05"

[assets]
binding = "ASSETS"
directory = "./build/web"

# KV 存储配置
[[kv_namespaces]]
binding = "USERS_KV"
id = "your-kv-namespace-id"

# 更多配置...
```

### 3. 部署到 Cloudflare

使用提供的部署脚本：

```bash
chmod +x deploy_flutter_web.sh
./deploy_flutter_web.sh
```

或手动部署：

```bash
cd web
wrangler deploy --env development
wrangler deploy --env production
```

## 🔧 环境配置

### 设置 Secrets（敏感信息）

```bash
# JWT 密钥
wrangler secret put JWT_SECRET --env production

# Resend API Key（邮件服务）
wrangler secret put RESEND_API_KEY --env production

# 支付宝配置
wrangler secret put ALIPAY_APP_ID --env production
wrangler secret put ALIPAY_PRIVATE_KEY --env production
wrangler secret put ALIPAY_PUBLIC_KEY --env production

# Stripe 配置
wrangler secret put STRIPE_SECRET_KEY --env production
wrangler secret put STRIPE_WEBHOOK_SECRET --env production
```

### 创建 KV 命名空间

```bash
# 创建用户数据存储
wrangler kv:namespace create "USERS_KV" --env production

# 创建订单数据存储
wrangler kv:namespace create "ORDERS_KV" --env production

# 创建会员数据存储
wrangler kv:namespace create "MEMBERSHIP_KV" --env production

# 创建兑换码存储
wrangler kv:namespace create "REDEEM_CODES_KV" --env production
```

### 创建 R2 存储桶

```bash
wrangler r2 bucket create bushi
```

## 🌐 域名配置

### 1. 在 Cloudflare 控制台配置自定义域名

1. 进入 Cloudflare 控制台
2. 选择你的 Worker
3. 点击 "Triggers" 标签
4. 添加自定义域名

### 2. 更新 wrangler.toml

```toml
[env.production]
routes = [
  { pattern = "yourdomain.com/*", custom_domain = true }
]
```

## 📱 Flutter 应用配置

### 更新 API 基础 URL

在 Flutter 应用中更新 API 配置：

```dart
// lib/config/api_config.dart
class ApiConfig {
  static const String baseUrl = 'https://your-worker.your-domain.workers.dev';
  // 或使用自定义域名
  // static const String baseUrl = 'https://api.yourdomain.com';
}
```

## 🧪 测试部署

### 1. 测试静态文件服务

访问你的 Worker URL，确保 Flutter Web 应用正常加载。

### 2. 测试 API 功能

```bash
# 测试用户注册
curl -X POST https://your-worker.workers.dev/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@example.com","password":"Test123!"}'

# 测试用户登录
curl -X POST https://your-worker.workers.dev/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"Test123!"}'
```

### 3. 测试文件上传（R2）

确保 R2 存储桶正常工作，可以上传和访问文件。

## 🔍 监控和调试

### 查看日志

```bash
wrangler tail --env production
```

### 查看 KV 数据

```bash
wrangler kv:key list --binding USERS_KV --env production
```

### 查看 R2 文件

```bash
wrangler r2 object list bushi
```

## 🚨 故障排除

### 常见问题

1. **静态文件 404**: 检查 `assets` 配置和 Flutter 构建输出
2. **API 错误**: 检查 KV 命名空间 ID 和环境变量
3. **CORS 错误**: 确保 Worker 正确设置 CORS 头部
4. **邮件发送失败**: 检查 Email Workers 绑定和 API 密钥

### 调试步骤

1. 检查 `wrangler.toml` 配置
2. 验证所有 secrets 已正确设置
3. 查看 Worker 日志
4. 测试各个 API 端点

## 📈 性能优化

1. **启用缓存**: 为静态资源设置适当的缓存头部
2. **压缩**: 确保 Flutter Web 构建时启用压缩
3. **CDN**: 利用 Cloudflare 的全球 CDN 网络

## 🔒 安全考虑

1. **HTTPS**: Cloudflare Workers 默认提供 HTTPS
2. **环境变量**: 敏感信息使用 secrets 而不是环境变量
3. **CORS**: 根据需要配置 CORS 策略
4. **认证**: 使用 JWT 进行用户认证

## 📚 相关文档

- [Cloudflare Workers 文档](https://developers.cloudflare.com/workers/)
- [Flutter Web 部署指南](https://docs.flutter.dev/deployment/web)
- [Wrangler CLI 文档](https://developers.cloudflare.com/workers/wrangler/)

## 🎉 完成

部署完成后，你的 Flutter Web 应用将：

1. ✅ 在 Cloudflare 的全球网络上运行
2. ✅ 提供完整的后端 API 功能
3. ✅ 支持用户认证和会员管理
4. ✅ 集成支付功能（支付宝/Stripe）
5. ✅ 支持文件存储和邮件发送

现在你可以通过一个 URL 访问完整的 Flutter Web 应用和所有后端功能！