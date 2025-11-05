# 全球法布施系统部署指南

## 概述

本文档详细说明如何将全球法布施系统部署到生产环境，包括Cloudflare Workers后端和Flutter前端应用的完整部署流程。

## 🏗️ 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                    用户设备                                  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Android   │  │     iOS     │  │     Web     │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                 Cloudflare 全球网络                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Workers   │  │   KV存储     │  │   R2存储     │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    第三方服务                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   Stripe    │  │    支付宝    │  │   邮件服务   │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## 📋 部署前准备

### 1. 账户准备
- [ ] Cloudflare账户（免费版即可开始）
- [ ] 域名（可选，用于自定义域名）
- [ ] Stripe账户（用于信用卡支付）
- [ ] 支付宝开发者账户（用于支付宝支付）
- [ ] 邮件服务提供商账户（如Resend、SendGrid等）

### 2. 开发环境
- [ ] Node.js >= 16.0.0
- [ ] Wrangler CLI >= 3.0.0
- [ ] Flutter SDK >= 3.0.0
- [ ] Git

### 3. 必要信息收集
- [ ] JWT密钥（用于Token签名）
- [ ] Stripe API密钥
- [ ] 支付宝应用密钥
- [ ] 邮件服务API密钥

## 🚀 后端部署（Cloudflare Workers）

### 步骤1: 安装Wrangler CLI

```bash
npm install -g wrangler
```

### 步骤2: 登录Cloudflare

```bash
wrangler login
```

### 步骤3: 配置项目

进入后端项目目录：
```bash
cd native-web/deploy-package/
```

复制配置文件：
```bash
cp wrangler.toml.example wrangler.toml
```

编辑 `wrangler.toml` 配置：
```toml
name = "fabushi-prod"
main = "worker.js"
compatibility_date = "2024-06-05"

# 生产环境配置
[env.production]
name = "fabushi"

[env.production.vars]
FROM_EMAIL = "noreply@yourdomain.com"
JWT_SECRET = "your-super-secret-jwt-key-here"
```

### 步骤4: 创建KV命名空间

```bash
# 创建用户存储
wrangler kv:namespace create "USERS_KV" --env production

# 创建订单存储
wrangler kv:namespace create "ORDERS_KV" --env production

# 创建会员存储
wrangler kv:namespace create "MEMBERSHIP_KV" --env production

# 创建兑换码存储
wrangler kv:namespace create "REDEEM_CODES_KV" --env production
```

将返回的命名空间ID更新到 `wrangler.toml` 中：
```toml
[[env.production.kv_namespaces]]
binding = "USERS_KV"
id = "your-users-kv-id"

[[env.production.kv_namespaces]]
binding = "ORDERS_KV"
id = "your-orders-kv-id"

[[env.production.kv_namespaces]]
binding = "MEMBERSHIP_KV"
id = "your-membership-kv-id"

[[env.production.kv_namespaces]]
binding = "REDEEM_CODES_KV"
id = "your-redeem-codes-kv-id"
```

### 步骤5: 创建R2存储桶

```bash
wrangler r2 bucket create bushi
```

### 步骤6: 设置环境变量

```bash
# 设置JWT密钥
wrangler secret put JWT_SECRET --env production

# 设置Stripe密钥
wrangler secret put STRIPE_SECRET_KEY --env production

# 设置支付宝密钥
wrangler secret put ALIPAY_APP_ID --env production
wrangler secret put ALIPAY_PRIVATE_KEY --env production

# 设置邮件服务密钥
wrangler secret put RESEND_API_KEY --env production
```

### 步骤7: 部署到生产环境

```bash
# 部署到生产环境
wrangler deploy --env production

# 查看部署状态
wrangler tail --env production
```

### 步骤8: 配置自定义域名（可选）

在Cloudflare控制台中：
1. 进入 Workers & Pages
2. 选择你的Worker
3. 点击 "Custom domains"
4. 添加你的域名

或使用命令行：
```bash
wrangler custom-domains add yourdomain.com --env production
```

## 📱 前端部署

### Android应用

#### 步骤1: 配置签名

创建 `android/key.properties`：
```properties
storePassword=your-store-password
keyPassword=your-key-password
keyAlias=your-key-alias
storeFile=../app/fabushi-key.jks
```

#### 步骤2: 更新配置

编辑 `lib/config.dart`：
```dart
static const String backendUrl = 'https://yourdomain.com';
```

#### 步骤3: 构建APK

```bash
# 构建发布版APK
flutter build apk --release

# 构建App Bundle（推荐用于Google Play）
flutter build appbundle --release
```

#### 步骤4: 发布到Google Play

1. 登录 [Google Play Console](https://play.google.com/console)
2. 创建新应用
3. 上传APK或App Bundle
4. 填写应用信息
5. 提交审核

### iOS应用

#### 步骤1: 配置Xcode项目

```bash
cd ios
pod install
```

#### 步骤2: 更新配置

在Xcode中：
1. 设置Bundle Identifier
2. 配置签名证书
3. 设置版本号

#### 步骤3: 构建IPA

```bash
flutter build ios --release
```

#### 步骤4: 发布到App Store

1. 在Xcode中Archive项目
2. 上传到App Store Connect
3. 填写应用信息
4. 提交审核

### Web应用

#### 步骤1: 构建Web版本

```bash
flutter build web --release
```

#### 步骤2: 部署到Cloudflare Pages

```bash
# 安装Wrangler
npm install -g wrangler

# 创建Pages项目
wrangler pages project create fabushi-web

# 部署
wrangler pages deploy build/web --project-name fabushi-web
```

#### 步骤3: 配置自定义域名

在Cloudflare控制台中配置Pages的自定义域名。

### 桌面应用

#### Windows

```bash
flutter build windows --release
```

使用Inno Setup或NSIS创建安装程序。

#### macOS

```bash
flutter build macos --release
```

使用Xcode创建DMG安装包。

#### Linux

```bash
flutter build linux --release
```

创建AppImage或Snap包。

## 🔧 生产环境配置

### 1. 安全配置

#### JWT密钥
使用强随机密钥：
```bash
openssl rand -base64 32
```

#### CORS配置
在Worker中配置适当的CORS策略：
```javascript
const corsHeaders = {
  'Access-Control-Allow-Origin': 'https://yourdomain.com',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type, Authorization',
};
```

#### 速率限制
实现API速率限制：
```javascript
// 在Worker中实现
const rateLimiter = new Map();
const RATE_LIMIT = 100; // 每分钟100次请求
```

### 2. 监控配置

#### 日志监控
```bash
# 实时查看日志
wrangler tail --env production

# 设置日志级别
wrangler tail --env production --format pretty
```

#### 性能监控
在Cloudflare控制台中查看：
- 请求数量
- 响应时间
- 错误率
- CPU使用率

### 3. 备份策略

#### KV数据备份
```bash
# 导出KV数据
wrangler kv:key list --binding USERS_KV --env production > users_backup.json
```

#### R2数据备份
```bash
# 使用rclone同步R2数据
rclone sync cloudflare:bushi ./backup/r2/
```

## 📊 监控和维护

### 1. 健康检查

创建健康检查端点：
```javascript
// 在worker.js中添加
if (url.pathname === '/health') {
  return new Response(JSON.stringify({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    version: '1.0.0'
  }), {
    headers: { 'Content-Type': 'application/json' }
  });
}
```

### 2. 错误监控

使用Sentry或类似服务：
```javascript
// 错误上报
try {
  // 业务逻辑
} catch (error) {
  console.error('Error:', error);
  // 发送到监控服务
}
```

### 3. 性能优化

#### 缓存策略
```javascript
// 设置适当的缓存头
const response = new Response(data, {
  headers: {
    'Cache-Control': 'public, max-age=3600',
    'Content-Type': 'application/json'
  }
});
```

#### 数据库优化
- 定期清理过期数据
- 优化KV存储结构
- 使用适当的索引

## 🔄 CI/CD配置

### GitHub Actions示例

创建 `.github/workflows/deploy.yml`：
```yaml
name: Deploy to Production

on:
  push:
    branches: [main]

jobs:
  deploy-backend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: '18'
      - name: Install Wrangler
        run: npm install -g wrangler
      - name: Deploy to Cloudflare
        run: wrangler deploy --env production
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}

  deploy-frontend:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.16.0'
      - name: Build Web
        run: flutter build web --release
      - name: Deploy to Cloudflare Pages
        run: wrangler pages deploy build/web
        env:
          CLOUDFLARE_API_TOKEN: ${{ secrets.CLOUDFLARE_API_TOKEN }}
```

## 🚨 故障排除

### 常见问题

1. **Worker部署失败**
   ```bash
   # 检查配置
   wrangler whoami
   wrangler kv:namespace list
   ```

2. **KV存储访问失败**
   ```bash
   # 检查绑定
   wrangler kv:key list --binding USERS_KV --env production
   ```

3. **域名解析问题**
   ```bash
   # 检查DNS设置
   dig yourdomain.com
   nslookup yourdomain.com
   ```

4. **SSL证书问题**
   - 检查Cloudflare SSL设置
   - 确认域名验证状态

### 调试技巧

1. **本地测试**
   ```bash
   wrangler dev --env production --local
   ```

2. **远程调试**
   ```bash
   wrangler tail --env production --format pretty
   ```

3. **性能分析**
   ```bash
   wrangler analytics --env production
   ```

## 📈 扩展计划

### 短期目标
- [ ] 添加更多支付方式
- [ ] 实现推送通知
- [ ] 添加数据分析
- [ ] 优化传输性能

### 长期目标
- [ ] 多语言支持
- [ ] AI功能集成
- [ ] 区块链集成
- [ ] 全球CDN优化

## 📞 技术支持

如果在部署过程中遇到问题，请：

1. 查看本文档的故障排除部分
2. 检查Cloudflare控制台的错误日志
3. 联系技术支持：support@fabushi.com

---

**祝您部署顺利！愿此功德回向法界众生！** 🙏