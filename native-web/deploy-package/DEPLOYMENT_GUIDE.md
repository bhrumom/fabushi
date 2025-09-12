# Cloudflare Worker 支付宝当面付集成部署指南

## 概述
本文档指导如何在现有的Cloudflare Worker中集成支付宝当面付功能，实现会员购买和支付功能。

## 文件结构
```
deploy-package/
├── worker.js              # 主Worker文件（已集成支付宝功能）
├── alipay-config.js       # 支付宝配置和工具类
├── membership.html        # 会员购买页面
├── login.html            # 登录页面（已更新跳转逻辑）
├── test-alipay.html      # 支付宝功能测试页面
├── wrangler.toml         # Worker配置文件（已更新KV存储）
└── DEPLOYMENT_GUIDE.md   # 本部署指南
```

## 集成变更说明

### 1. 主Worker文件 (worker.js)
- ✅ 已添加支付宝当面付API路由
- ✅ 已集成订单创建、查询、通知处理功能
- ✅ 已添加会员状态管理功能
- ✅ 保持现有Stripe支付功能不变

### 2. 配置文件 (wrangler.toml)
- ✅ 已添加支付宝订单KV存储 (`ORDERS_KV`)
- ✅ 已添加支付宝会员KV存储 (`MEMBERSHIP_KV`)
- ✅ 已添加支付宝环境变量配置

### 3. 登录页面 (login.html)
- ✅ 已更新跳转逻辑，支持redirect参数

## 部署步骤

### 1. 创建KV命名空间

在Cloudflare控制台中创建以下KV命名空间：

```bash
# 创建订单KV存储
wrangler kv:namespace create "ORDERS_KV"
wrangler kv:namespace create "ORDERS_KV" --preview

# 创建会员KV存储
wrangler kv:namespace create "MEMBERSHIP_KV"
wrangler kv:namespace create "MEMBERSHIP_KV" --preview
```

### 2. 更新wrangler.toml

将创建的KV命名空间ID填入wrangler.toml：

```toml
[[kv_namespaces]]
binding = "ORDERS_KV"
id = "你的实际订单KV_ID"
preview_id = "你的实际预览订单KV_ID"

[[kv_namespaces]]
binding = "MEMBERSHIP_KV"
id = "你的实际会员KV_ID"
preview_id = "你的实际预览会员KV_ID"
```

### 3. 设置环境变量

在Cloudflare控制台设置以下Secrets：

```bash
# 设置支付宝相关配置
wrangler secret put ALIPAY_APP_ID
wrangler secret put ALIPAY_PRIVATE_KEY
wrangler secret put ALIPAY_PUBLIC_KEY
wrangler secret put ALIPAY_SANDBOX
wrangler secret put JWT_SECRET
```

### 4. 配置支付宝开放平台

1. 登录[支付宝开放平台](https://open.alipay.com/)
2. 创建应用并获取：
   - 应用ID (ALIPAY_APP_ID)
   - 应用私钥 (ALIPAY_PRIVATE_KEY)
   - 支付宝公钥 (ALIPAY_PUBLIC_KEY)
3. 配置应用网关：
   - 生产环境：`https://your-domain.workers.dev/api/alipay/notify`
   - 开发环境：`https://your-domain.workers.dev/api/alipay/notify`

### 5. 部署到Cloudflare

```bash
# 安装依赖
npm install

# 部署到开发环境
wrangler deploy --env development

# 部署到生产环境
wrangler deploy --env production
```

## API接口

### 支付宝当面付API

| 接口 | 方法 | 描述 |
|------|------|------|
| `/api/alipay/create-order` | POST | 创建支付宝订单 |
| `/api/alipay/query-order` | GET | 查询订单状态 |
| `/api/alipay/notify` | POST | 支付宝异步通知处理 |
| `/api/alipay/check-membership` | GET | 检查会员状态 |

### 现有Stripe API（保持不变）

| 接口 | 方法 | 描述 |
|------|------|------|
| `/api/stripe/membership-status` | GET | 获取Stripe会员状态 |
| `/api/stripe/create-subscription` | POST | 创建Stripe订阅 |
| `/api/stripe/cancel-subscription` | POST | 取消Stripe订阅 |
| `/api/stripe/webhook` | POST | Stripe Webhook处理 |

## 测试验证

### 1. 本地测试
```bash
# 启动本地开发服务器
wrangler dev

# 访问测试页面
http://localhost:8787/test-alipay.html
```

### 2. 生产环境测试
1. 访问会员购买页面：`https://your-domain.workers.dev/membership.html`
2. 登录后选择会员套餐
3. 使用支付宝扫码支付测试

## 使用流程

1. **用户登录** → 访问 `login.html`
2. **选择会员** → 访问 `membership.html`
3. **支付购买** → 选择支付宝支付，扫码完成支付
4. **会员激活** → 支付成功后自动激活会员

## 故障排除

### 常见问题

1. **KV存储未配置**
   - 检查wrangler.toml中的KV命名空间ID是否正确
   - 确认已在Cloudflare控制台创建KV存储

2. **支付宝配置错误**
   - 检查ALIPAY_APP_ID、私钥、公钥是否正确
   - 确认支付宝应用已上线

3. **通知处理失败**
   - 检查支付宝应用网关配置是否正确
   - 确认域名已添加到支付宝白名单

### 调试工具

使用test-alipay.html页面进行功能测试：
- 测试用户登录
- 测试订单创建
- 测试订单查询
- 测试会员状态检查

## 安全注意事项

1. **密钥管理**
   - 所有敏感信息使用wrangler secret管理
   - 不要提交私钥到代码仓库

2. **签名验证**
   - 所有支付宝通知都需要验证签名
   - 使用HTTPS确保通信安全

3. **访问控制**
   - API接口需要认证令牌
   - 定期更新JWT密钥

## 后续优化

1. **缓存优化**
   - 添加订单状态缓存
   - 优化会员状态查询

2. **监控告警**
   - 添加支付失败监控
   - 设置异常通知

3. **用户体验**
   - 添加支付进度提示
   - 优化错误处理