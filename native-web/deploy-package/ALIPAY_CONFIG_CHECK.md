# 支付宝当面付配置检查清单

## ✅ 配置完成状态

### 应用信息 - 全部配置完成 ✓
- **应用ID**: `2021005184653913` ✓
- **应用公钥**: 已配置 ✓
- **支付宝公钥**: 已配置 ✓
- **应用私钥**: 已配置 ✓

### 域名配置 - 全部配置完成 ✓
- **域名**: https://ombhrum.com/ ✓
- **通知URL**: https://ombhrum.com/api/alipay/notify ✓
- **同步返回URL**: https://ombhrum.com/membership.html ✓

## 🔧 支付宝开放平台配置

**需要在支付宝开放平台完成的最后步骤：**

1. 登录 [支付宝开放平台](https://open.alipay.com/)
2. 进入你的应用详情页面
3. 点击「开发设置」
4. 配置以下信息：
   - **应用网关**: `https://ombhrum.com/api/alipay/notify`
   - **授权回调地址**: `https://ombhrum.com/membership.html`

## 🧪 测试指南

### 本地测试
```bash
# 启动本地开发服务器
wrangler dev

# 测试创建订单
curl -X POST http://localhost:8787/api/alipay/create-order \
  -H "Content-Type: application/json" \
  -d '{"userId":"test123