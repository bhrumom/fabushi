# 支付宝当面付测试指南

## 🎯 当前配置状态

✅ **所有密钥已配置完成**：
- 应用ID: 2021005184653913
- 应用公钥: 已配置
- 支付宝公钥: 已配置  
- 应用私钥: 已配置

## 🧪 本地测试步骤

### 1. 启动本地服务
```bash
wrangler dev
```

### 2. 测试支付宝API接口

#### 创建订单测试
```bash
curl -X POST http://localhost:8787/api/alipay/create-order \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "test-user-123",
    "type": "monthly"
  }'
```

#### 查询订单状态
```bash
curl http://localhost:8787/api/alipay/query-order?orderId=YOUR_ORDER_ID
```

#### 检查会员状态
```bash
curl http://localhost:8787/api/alipay/check-membership?userId=test-user-123
```

### 3. 前端集成测试

#### 测试页面访问
- 会员页面: http://localhost:8787/membership.html
- 创建订单: 点击"支付宝支付"按钮

#### 浏览器控制台测试
```javascript
// 创建支付宝订单
fetch('/api/alipay/create-order', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ userId: 'test-user', type: 'monthly' })
}).then(r => r.json()).then(console.log);
```

## 🔧 支付宝开放平台配置检查

### 必需设置
1. **应用网关**: `https://your-domain.com/api/alipay/notify`
2. **授权回调地址**: `https://your-domain.com/membership.html`
3. **应用状态**: 已上线
4. **功能列表**: 包含"当面付"功能

### 密钥配置验证
- 登录 [支付宝开放平台](https://open.alipay.com/)
- 进入应用详情 → 开发设置
- 确认以下配置正确：
  - 应用公钥匹配
  - 支付宝公钥正确
  - 接口加签方式: RSA2

## 🚀 部署前检查清单

### 域名配置
- [ ] 替换所有 `your-domain.com` 为你的实际域名
- [ ] 配置HTTPS证书
- [ ] 验证域名备案状态

### Cloudflare配置
- [ ] 创建 KV 命名空间: `ORDERS_KV`
- [ ] 创建 KV 命名空间: `MEMBERSHIP_KV`
- [ ] 更新 wrangler.toml 中的命名空间ID
- [ ] 设置环境变量

### 生产环境测试
1. **部署命令**:
   ```bash
   wrangler deploy
   ```

2. **生产环境验证**:
   ```bash
   curl https://your-domain.com/api/alipay/check-membership?userId=test
   ```

## 🚨 常见问题排查

### 签名错误
- 检查私钥格式是否正确
- 确认应用ID匹配
- 验证公钥上传状态

### 通知接收失败
- 检查应用网关URL是否可访问
- 验证HTTPS证书有效性
- 查看Cloudflare Worker日志

### 订单创建失败
- 检查用户认证状态
- 验证会员类型参数
- 查看KV存储权限

## 📊 日志调试

### 查看Worker日志
```bash
wrangler tail
```

### 关键日志标识
- `[ALIPAY]`: 支付宝相关操作
- `[ORDER]`: 订单创建/查询
- `[MEMBERSHIP]`: 会员状态更新

## 🎯 完整测试流程

1. **本地测试**:
   - 启动 wrangler dev
   - 测试创建订单API
   - 验证会员页面功能

2. **沙箱测试**:
   - 使用支付宝沙箱环境
   - 模拟支付流程
   - 验证异步通知

3. **生产部署**:
   - 配置生产域名
   - 部署到Cloudflare
   - 端到端测试

## 📞 技术支持

如果测试过程中遇到问题：
1. 检查 `wrangler tail` 日志输出
2. 验证支付宝开放平台配置
3. 确认所有密钥匹配
4. 测试网络连通性