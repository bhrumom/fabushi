# 支付宝登录 401 认证失败问题修复方案

## 问题分析

### 现象
- 邮箱密码登录正常，可以成功获取用户信息
- 支付宝登录后返回 401 认证失败错误
- 错误信息：`❌ 401 认证失败 - 请求头: {Authorization: Bearer eyJhbGci...}`

### 根本原因
支付宝登录回调时生成的 JWT token 使用的 `JWT_SECRET` 与后端 API 验证时使用的 `JWT_SECRET` 不一致。

从日志可以看到：
1. 邮箱登录的 token 可以正常验证（用户 bhrum）
2. 支付宝登录的 token 无法验证（用户 千资_1）

### 技术细节

#### JWT Secret 获取逻辑（auth-utils.js）
```javascript
const secret = (env && (env.JWT_SECRET || (env.vars && env.vars.JWT_SECRET))) || 'dev-secret';
```

#### wrangler.toml 配置问题
```toml
# 生产环境 - 没有 JWT_SECRET！
[env.production.vars]
FROM_EMAIL = "amitabha@ombhrum.com"
FLUTTER_WEB = "true"
# JWT_SECRET 应该使用 Cloudflare Secret，不要在这里明文存储

# 开发环境 - 有 JWT_SECRET
[env.development.vars]
FROM_EMAIL = "amitabha@ombhrum.com"
JWT_SECRET = "dev_secret_key_2025"  # ✅ 开发环境有配置
```

**问题**：生产环境没有配置 JWT_SECRET，导致：
- 支付宝登录时可能使用了默认的 'dev-secret'
- 或者使用了不同的 secret 来源
- 导致生成的 token 无法被后续 API 验证

## 解决方案

### 方案 1：使用 Cloudflare Secrets（推荐）

Cloudflare Workers 的最佳实践是使用 Secrets 存储敏感信息，而不是在 wrangler.toml 中明文配置。

#### 步骤 1：设置 Cloudflare Secret

```bash
# 为生产环境设置 JWT_SECRET
wrangler secret put JWT_SECRET --env production

# 系统会提示输入 secret 值，输入一个强密码（至少32位随机字符串）
# 例如：your-super-secret-jwt-key-min-32-chars-long-2025
```

#### 步骤 2：验证 Secret 已设置

```bash
# 列出所有 secrets
wrangler secret list --env production
```

#### 步骤 3：重新部署

```bash
cd web
wrangler deploy --env production
```

### 方案 2：临时修复（仅用于测试）

如果只是测试环境，可以在 wrangler.toml 中添加 JWT_SECRET（不推荐用于生产）：

```toml
[env.production.vars]
FROM_EMAIL = "amitabha@ombhrum.com"
FLUTTER_WEB = "true"
JWT_SECRET = "your-temporary-secret-key-2025"  # ⚠️ 仅用于测试
```

## 验证修复

### 1. 检查 Token 生成

在 `alipay-login-functions.js` 的 `handleMacOSAlipayCallback` 函数中添加日志：

```javascript
const token = await generateToken(user.username, env);
console.log('生成 token 使用的 secret:', env.JWT_SECRET ? '已配置' : '未配置（使用默认值）');
```

### 2. 检查 Token 验证

在 `admin.js` 的 `handleCheckAdminStatus` 函数中添加日志：

```javascript
const tokenData = await verifyToken(token, env);
console.log('验证 token 使用的 secret:', env.JWT_SECRET ? '已配置' : '未配置（使用默认值）');
```

### 3. 测试流程

1. 清除应用缓存和登录状态
2. 使用支付宝登录
3. 检查是否能正常获取用户信息
4. 查看 Cloudflare Workers 日志确认 secret 配置正确

## 预防措施

### 1. 统一 Secret 管理

创建一个 Secret 管理脚本：

```bash
#!/bin/bash
# setup-secrets.sh

echo "设置 Cloudflare Workers Secrets..."

# 生产环境
echo "设置生产环境 JWT_SECRET..."
wrangler secret put JWT_SECRET --env production

# 开发环境（可选）
echo "设置开发环境 JWT_SECRET..."
wrangler secret put JWT_SECRET --env development

echo "✅ Secrets 设置完成"
```

### 2. 环境变量检查

在 worker 启动时添加环境检查：

```javascript
// worker-modular.js
export default {
  async fetch(request, env, ctx) {
    // 检查必要的环境变量
    if (!env.JWT_SECRET) {
      console.error('❌ JWT_SECRET 未配置！');
      // 在开发环境可以使用默认值，生产环境应该报错
      if (env.ENVIRONMENT === 'production') {
        return new Response('Server configuration error', { status: 500 });
      }
    }
    
    // ... 其他代码
  }
}
```

### 3. 文档更新

在 README.md 中添加部署前检查清单：

```markdown
## 部署前检查清单

- [ ] 已设置 JWT_SECRET secret
- [ ] 已设置支付宝相关配置
- [ ] 已测试邮箱登录
- [ ] 已测试支付宝登录
- [ ] 已验证 token 可以正常使用
```

## 相关文件

- `web/wrangler.toml` - Cloudflare Workers 配置
- `web/auth-utils.js` - JWT token 生成和验证
- `web/alipay-login-functions.js` - 支付宝登录处理
- `web/src/handlers/admin.js` - 管理员状态检查（使用 token 验证）

## 参考资料

- [Cloudflare Workers Secrets](https://developers.cloudflare.com/workers/configuration/secrets/)
- [JWT Best Practices](https://tools.ietf.org/html/rfc8725)
