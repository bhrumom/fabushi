# 设置 JWT_SECRET

## 问题
支付宝登录后，后续 API 请求返回 401 认证失败。原因是不同环境使用了不同的 JWT_SECRET。

## 解决方案

### 方法 1: 使用 Cloudflare Secret（推荐）

```bash
# 为生产环境设置 Secret
npx wrangler secret put JWT_SECRET --env production
# 输入一个强密码，例如: your-super-secret-jwt-key-2025

# 为开发环境设置相同的 Secret
npx wrangler secret put JWT_SECRET --env development
# 输入相同的密码
```

### 方法 2: 临时在 wrangler.toml 中设置（仅用于测试）

在 `web/wrangler.toml` 中添加：

```toml
[vars]
JWT_SECRET = "your-temporary-secret-key-2025"

[env.production.vars]
JWT_SECRET = "your-temporary-secret-key-2025"

[env.development.vars]
JWT_SECRET = "your-temporary-secret-key-2025"
```

**注意**: 生产环境不要使用这种方式，应该使用 Cloudflare Secret。

## 验证

设置完成后，重新部署：

```bash
cd web
npx wrangler deploy --env production
```

然后测试支付宝登录，应该不再出现 401 错误。
