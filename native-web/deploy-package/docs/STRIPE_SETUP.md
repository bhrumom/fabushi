# Stripe支付系统配置指南

## 概述

本系统已集成Stripe支付功能，支持：
- 新用户自动获得3天免费试用
- 月度会员订阅（¥7/月 或 $1/月）
- 自动续费和取消订阅
- Webhook事件处理

## 环境变量配置

### 必需的环境变量

在Cloudflare Workers中设置以下环境变量：

```bash
# Stripe密钥（从Stripe Dashboard获取）
STRIPE_SECRET_KEY=sk_test_...  # 测试环境密钥，生产环境使用sk_live_...
STRIPE_WEBHOOK_SECRET=whsec_...  # Webhook签名验证密钥

# 可选：自定义发件人邮箱
FROM_EMAIL=noreply@yourdomain.com
```

### Stripe Dashboard配置

1. **创建Stripe账户**
   - 访问 https://stripe.com 注册账户
   - 完成账户验证

2. **获取API密钥**
   - 进入Dashboard > Developers > API keys
   - 复制"Secret key"到环境变量`STRIPE_SECRET_KEY`
   - 复制"Publishable key"到`membership.html`中的Stripe初始化代码

3. **创建产品和价格**
   ```bash
   # 使用Stripe CLI或Dashboard创建产品
   
   # 中文版月度会员 - ¥7/月
   stripe products create --name="月度会员" --description="全球法布施月度会员"
   stripe prices create --product=prod_xxx --unit-amount=700 --currency=cny --recurring-interval=month
   
   # 国际版月度会员 - $1/月  
   stripe products create --name="Monthly Membership" --description="Global Dharma Sharing Monthly Membership"
   stripe prices create --product=prod_yyy --unit-amount=100 --currency=usd --recurring-interval=month
   ```

4. **更新价格ID**
   在`stripe-config.js`中更新实际的价格ID：
   ```javascript
   PRODUCTS: {
     MONTHLY_MEMBERSHIP_CNY: 'price_1234567890abcdef', // 替换为实际价格ID
     MONTHLY_MEMBERSHIP_USD: 'price_0987654321fedcba'  // 替换为实际价格ID
   }
   ```

5. **配置Webhook**
   - 进入Dashboard > Developers > Webhooks
   - 点击"Add endpoint"
   - URL: `https://your-worker-domain.workers.dev/api/stripe/webhook`
   - 选择以下事件：
     - `invoice.payment_succeeded`
     - `invoice.payment_failed`
     - `customer.subscription.created`
     - `customer.subscription.updated`
     - `customer.subscription.deleted`
   - 复制"Signing secret"到环境变量`STRIPE_WEBHOOK_SECRET`

## 前端配置

更新`membership.html`中的Stripe可发布密钥：

```javascript
// 第264行左右，替换为你的实际可发布密钥
stripe = Stripe('pk_test_your_actual_publishable_key_here');
```

## 测试

### 测试卡号

Stripe提供测试卡号用于开发：

```
成功支付: 4242 4242 4242 4242
需要验证: 4000 0025 0000 3155
被拒绝: 4000 0000 0000 0002
```

过期日期：任何未来日期
CVC：任何3位数字
邮编：任何5位数字

### 测试流程

1. 注册新用户 → 自动获得3天试用
2. 试用期内访问会员中心 → 显示试用状态
3. 点击订阅 → 进入支付流程
4. 使用测试卡号完成支付
5. 检查Webhook是否正确处理支付事件
6. 验证会员状态更新

## 生产环境部署

1. **切换到生产密钥**
   - 将`STRIPE_SECRET_KEY`更换为`sk_live_...`
   - 更新前端的可发布密钥为`pk_live_...`

2. **更新Webhook URL**
   - 将Webhook端点URL更新为生产域名

3. **价格配置**
   - 在生产环境中创建实际的产品和价格
   - 更新`stripe-config.js`中的价格ID

## 功能特性

### 新用户体验
- 注册即获得3天免费试用
- 试用期内享受完整功能
- 试用结束前提醒升级

### 订阅管理
- 支持人民币和美元支付
- 自动续费
- 随时取消订阅
- 取消后当前周期内仍可使用

### 安全性
- Webhook签名验证
- JWT token认证
- 密码强度验证
- 邮箱验证码

## 故障排除

### 常见问题

1. **支付失败**
   - 检查Stripe密钥是否正确
   - 确认价格ID是否存在
   - 查看浏览器控制台错误

2. **Webhook不工作**
   - 验证Webhook URL是否可访问
   - 检查签名密钥是否正确
   - 查看Stripe Dashboard中的Webhook日志

3. **会员状态不更新**
   - 确认Webhook事件被正确处理
   - 检查KV存储是否正常工作
   - 验证用户数据结构

### 调试工具

- Stripe CLI: `stripe listen --forward-to localhost:8787/api/stripe/webhook`
- Stripe Dashboard: 查看支付和Webhook日志
- Cloudflare Workers日志: 查看Worker执行日志

## 支持

如有问题，请检查：
1. Stripe Dashboard中的日志
2. Cloudflare Workers的实时日志
3. 浏览器开发者工具的网络和控制台面板

---

配置完成后，用户可以享受完整的会员订阅体验！🎉