# 支付宝当面付集成指南

本文档说明如何在全球发送应用中集成支付宝当面付功能，实现用户购买会员服务。

## 功能概述

- **月度会员**: ¥21/月
- **季度会员**: ¥63/3个月 (9折优惠)
- **年度会员**: ¥252/年 (8折优惠)

## 文件结构

```
deploy-package/
├── alipay-config.js          # 支付宝配置和工具类
├── alipay-worker.js          # Cloudflare Worker 处理程序
├── membership.html           # 会员购买页面
├── ALIPAY_SETUP.md           # 本配置文档
└── ...
```

## 配置步骤

### 1. 支付宝开放平台配置

1. 访问 [支付宝开放平台](https://open.alipay.com/platform/home.htm)
2. 创建应用并获取以下信息：
   - **APP_ID**: 应用ID
   - **PRIVATE_KEY**: 应用私钥
   - **ALIPAY_PUBLIC_KEY**: 支付宝公钥
   - **GATEWAY_URL**: 支付宝网关地址

### 2. Cloudflare Worker 配置

#### 2.1 创建 KV 命名空间

在 Cloudflare Workers 控制台：

1. 创建两个 KV 命名空间：
   - `ALIPAY_ORDERS`: 存储订单信息
   - `MEMBERSHIP_DATA`: 存储会员数据

2. 绑定到 Worker：
   - 变量名: `ORDERS_KV` 绑定到 `ALIPAY_ORDERS`
   - 变量名: `MEMBERSHIP_KV` 绑定到 `MEMBERSHIP_DATA`

#### 2.2 环境变量配置

在 Worker 设置中添加以下环境变量：

```bash
# 支付宝配置
ALIPAY_APP_ID=你的应用ID
ALIPAY_PRIVATE_KEY=你的应用私钥
ALIPAY_PUBLIC_KEY=支付宝公钥
ALIPAY_GATEWAY=https://openapi.alipay.com/gateway.do

# 应用配置
APP_SECRET=随机生成的应用密钥（用于签名验证）
```

### 3. 修改配置文件

#### 3.1 更新 alipay-config.js

根据实际环境更新以下配置：

```javascript
// 生产环境配置
const ALIPAY_CONFIG = {
    APP_ID: '你的实际APP_ID',
    GATEWAY_URL: 'https://openapi.alipay.com/gateway.do',
    CHARSET: 'utf-8',
    SIGN_TYPE: 'RSA2',
    FORMAT: 'json',
    VERSION: '1.0',
    PRODUCT_CODE: 'FACE_TO_FACE_PAYMENT',
    RETURN_URL: 'https://你的域名.com/membership.html',
    NOTIFY_URL: 'https://你的域名.com/api/alipay/notify'
};
```

#### 3.2 更新支付回调地址

在 `alipay-worker.js` 中更新通知 URL：

```javascript
const CONFIG = {
    ALIPAY: {
        NOTIFY_URL: 'https://你的域名.com/api/alipay/notify'
    }
};
```

## API 接口

### 创建订单

**POST** `/api/alipay/create-order`

**请求体:**
```json
{
    "userId": "用户ID",
    "months": 1
}
```

**响应:**
```json
{
    "success": true,
    "orderId": "订单ID",
    "qrCode": "二维码内容",
    "amount": 21
}
```

### 查询订单状态

**POST** `/api/alipay/query-order`

**请求体:**
```json
{
    "orderId": "订单ID"
}
```

**响应:**
```json
{
    "success": true,
    "paid": true,
    "orderInfo": { ... }
}
```

### 检查会员状态

**POST** `/api/alipay/check-membership`

**请求体:**
```json
{
    "userId": "用户ID"
}
```

**响应:**
```json
{
    "success": true,
    "isActive": true,
    "expiresAt": "2024-12-31",
    "daysLeft": 30
}
```

### 支付通知处理

**POST** `/api/alipay/notify`

支付宝异步通知接口，自动处理支付完成后的会员激活。

## 本地开发测试

### 1. 使用模拟数据

在开发环境中，系统会使用模拟的支付宝 SDK，不会进行真实的支付。

### 2. 测试流程

1. 访问 `membership.html` 页面
2. 选择会员时长
3. 点击"使用支付宝支付"
4. 在弹窗中点击"我已支付"模拟支付成功
5. 检查会员状态是否更新

### 3. 测试用户

使用以下测试用户：
- 用户名: test@example.com
- 密码: 123456

## 生产环境部署

### 1. 部署到 Cloudflare Workers

```bash
wrangler deploy
```

### 2. 配置自定义域名

在 Cloudflare Workers 设置中添加自定义域名：
- 添加路由: `yourdomain.com/*` → 你的 Worker
- 确保 HTTPS 已启用

### 3. 验证配置

1. 访问会员页面
2. 创建测试订单
3. 使用真实支付宝扫码支付
4. 验证会员自动激活

## 故障排除

### 常见问题

1. **二维码无法生成**
   - 检查 APP_ID 和密钥配置
   - 验证支付宝应用状态

2. **支付通知未收到**
   - 确认 notify_url 可公网访问
   - 检查 HTTPS 证书有效性

3. **会员状态未更新**
   - 查看 Worker 日志
   - 验证 KV 存储权限

### 调试工具

- **支付宝开放平台**: 查看应用调用日志
- **Cloudflare Workers**: 使用 `wrangler tail` 查看实时日志
- **浏览器控制台**: 查看前端错误信息

## 安全注意事项

1. **密钥管理**
   - 私钥文件不要提交到代码仓库
   - 使用环境变量存储敏感信息

2. **数据验证**
   - 所有回调数据都要验证签名
   - 防止重复订单处理

3. **访问控制**
   - 确保支付接口需要用户认证
   - 限制订单创建频率

## 技术支持

- [支付宝当面付文档](https://opendocs.alipay.com/open-v3/05pf4f)
- [Cloudflare Workers 文档](https://developers.cloudflare.com/workers/)
- [支付宝技术支持](https://support.open.alipay.com/)

## 更新日志

- v1.0.0: 初始版本，集成支付宝当面付
- 支持月度/季度/年度会员购买
- 完整的支付流程和会员管理