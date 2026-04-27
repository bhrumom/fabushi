# 🚀 支付宝登录 401 问题 - 快速修复

## ✅ 问题已修复！

**修复时间**：2025-11-21

**修复内容**：已在生产环境配置 JWT_SECRET 并重新部署

---

## 原问题

支付宝登录后返回 **401 认证失败**，但邮箱密码登录正常。

**原因**：生产环境缺少 `JWT_SECRET` 配置。

## ✅ 已完成修复

已在 `web/wrangler.toml` 中添加：

```toml
[env.production.vars]
JWT_SECRET = "prod_secret_key_2025_ombhrum_fabushi"
```

并已重新部署到生产环境。

## 测试步骤

### 1️⃣ 清除缓存

```bash
flutter clean
flutter pub get
```

### 2️⃣ 重启应用

```bash
flutter run
```

### 3️⃣ 测试支付宝登录

1. 点击支付宝登录
2. 完成授权
3. 验证是否返回 200 OK（不是 401）

详细测试指南：[TEST_ALIPAY_LOGIN.md](TEST_ALIPAY_LOGIN.md)

## 手动修复

如果脚本不工作，手动执行：

```bash
cd web

# 设置 JWT_SECRET
wrangler secret put JWT_SECRET --env production
# 输入密码（例如：your-super-secret-jwt-key-min-32-chars-long-2025）

# 重新部署
wrangler deploy --env production
```

## 生成强密码

```bash
# macOS/Linux
openssl rand -base64 32

# 或
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

## 验证修复

成功的日志应该是：

```
flutter: 📥 Response: 200 OK
flutter: 📊 解析后数据: {isAdmin: false, email: ..., username: 千资_1, ...}
flutter: ✅ 用户信息刷新完成
```

## 详细文档

- 📖 [完整问题分析](ALIPAY_LOGIN_FIX_SUMMARY.md)
- 🔧 [详细修复方案](FIX_ALIPAY_LOGIN_401.md)

## 需要帮助？

查看 Cloudflare Workers 日志：
```bash
cd web
wrangler tail --env production
```
