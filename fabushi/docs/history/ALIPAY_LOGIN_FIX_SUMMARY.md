# 支付宝登录 401 问题总结

## 🔍 问题现象

- ✅ **邮箱密码登录**：正常工作，可以获取用户信息
- ❌ **支付宝登录**：返回 401 认证失败错误

```
flutter: 📥 Response: 401 Unauthorized
flutter: 📄 原始响应体: {"error":"认证失败"}
flutter: ❌ 401 认证失败 - 请求头: {Authorization: Bearer eyJhbGci...}
```

## 🎯 根本原因

**JWT_SECRET 未在生产环境配置！**

### 配置检查结果

```bash
生产环境 Secrets：
[
  {
    "name": "ALIPAY_PRIVATE_KEY",
    "type": "secret_text"
  },
  {
    "name": "ALIPAY_SANDBOX",
    "type": "secret_text"
  }
]
```

**缺少 JWT_SECRET！** ❌

### 为什么邮箱登录正常？

可能的原因：
1. 邮箱登录的 token 是在配置 JWT_SECRET 之前生成的（使用了某个默认值）
2. 或者邮箱登录和支付宝登录使用了不同的 token 生成路径

### 为什么支付宝登录失败？

支付宝登录流程：
1. 用户授权 → 获取 auth_code
2. 后端使用 auth_code 获取用户信息
3. **生成 JWT token**（这里使用 JWT_SECRET）
4. 返回 token 给客户端
5. 客户端使用 token 请求 `/api/admin/check-status`
6. **后端验证 token**（这里也使用 JWT_SECRET）

**问题**：生成和验证使用的 JWT_SECRET 不一致！

## ✅ 解决方案

### 方案 1：设置 Cloudflare Secret（推荐）

```bash
# 1. 进入 web 目录
cd web

# 2. 设置 JWT_SECRET
wrangler secret put JWT_SECRET --env production

# 输入一个强密码（至少32位随机字符串）
# 例如：your-super-secret-jwt-key-min-32-chars-long-2025

# 3. 重新部署
wrangler deploy --env production
```

### 方案 2：使用快速修复脚本

```bash
# 在项目根目录运行
./fix-alipay-login.sh
```

脚本会：
1. 检查当前配置
2. 引导你设置 JWT_SECRET
3. 自动重新部署

## 🧪 验证修复

### 1. 清除缓存

```bash
# Flutter 应用
flutter clean
flutter pub get
```

### 2. 测试支付宝登录

1. 启动应用
2. 点击支付宝登录
3. 完成授权
4. 检查是否能正常进入主界面
5. 验证用户信息是否正确显示

### 3. 检查日志

应该看到类似的成功日志：

```
flutter: 🔑 HttpService: 成功获取token: eyJhbGci...
flutter: 🔐 HttpService: 添加认证头 Authorization: Bearer eyJhbGci...
flutter: 📥 Response: 200 OK
flutter: 📊 解析后数据: {isAdmin: false, email: ..., username: 千资_1, ...}
flutter: ✅ 用户信息刷新完成
```

## 📋 技术细节

### JWT Token 生成（auth-utils.js）

```javascript
async function generateToken(username, env) {
  const secret = (env && (env.JWT_SECRET || (env.vars && env.vars.JWT_SECRET))) || 'dev-secret';
  // ... 生成 token
}
```

### JWT Token 验证（auth-utils.js）

```javascript
async function verifyToken(token, env) {
  const secret = (env && (env.JWT_SECRET || (env.vars && env.vars.JWT_SECRET))) || 'dev-secret';
  // ... 验证 token
}
```

**关键点**：生成和验证必须使用相同的 secret！

### 支付宝登录流程（alipay-login-functions.js）

```javascript
// handleMacOSAlipayCallback
const token = await generateToken(user.username, env);  // 使用 env.JWT_SECRET
```

### 用户信息验证（admin.js）

```javascript
// handleCheckAdminStatus
const tokenData = await verifyToken(token, env);  // 使用 env.JWT_SECRET
if (!tokenData) return jsonResponse({ error: '认证失败' }, 401);  // ❌ 这里失败了
```

## 🔒 安全建议

### 1. 使用强密码

```bash
# 生成强随机密码（macOS/Linux）
openssl rand -base64 32

# 或使用 Python
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

### 2. 不要在代码中硬编码

❌ **错误做法**：
```toml
[env.production.vars]
JWT_SECRET = "my-secret-123"  # 不要这样做！
```

✅ **正确做法**：
```bash
wrangler secret put JWT_SECRET --env production
```

### 3. 定期轮换密钥

建议每 3-6 个月更换一次 JWT_SECRET（会导致所有用户需要重新登录）。

## 📚 相关文件

- `web/wrangler.toml` - Cloudflare Workers 配置
- `web/auth-utils.js` - JWT 工具函数
- `web/alipay-login-functions.js` - 支付宝登录处理
- `web/src/handlers/admin.js` - 管理员状态检查
- `FIX_ALIPAY_LOGIN_401.md` - 详细修复文档
- `fix-alipay-login.sh` - 快速修复脚本
- `check-jwt-config.sh` - 配置检查脚本

## 🎉 预期结果

修复后，支付宝登录应该：
1. ✅ 成功生成 token
2. ✅ Token 可以通过验证
3. ✅ 正常获取用户信息
4. ✅ 显示会员状态
5. ✅ 进入主界面

## 💡 后续优化

### 1. 添加环境检查

在 worker 启动时检查必要的环境变量：

```javascript
if (!env.JWT_SECRET) {
  console.error('❌ JWT_SECRET 未配置！');
  if (env.ENVIRONMENT === 'production') {
    return new Response('Server configuration error', { status: 500 });
  }
}
```

### 2. 统一错误处理

改进 401 错误的提示信息：

```javascript
if (!tokenData) {
  console.error('Token 验证失败:', { 
    hasSecret: !!env.JWT_SECRET,
    tokenPreview: token.substring(0, 20) + '...'
  });
  return jsonResponse({ 
    error: '认证失败',
    hint: '请重新登录'
  }, 401);
}
```

### 3. 添加健康检查

```javascript
// GET /api/health
{
  status: 'ok',
  config: {
    hasJwtSecret: !!env.JWT_SECRET,
    hasAlipayConfig: !!env.ALIPAY_APP_ID && !!env.ALIPAY_PRIVATE_KEY
  }
}
```

## 📞 需要帮助？

如果问题仍然存在：

1. 运行 `./check-jwt-config.sh` 检查配置
2. 查看 Cloudflare Workers 日志
3. 检查 Flutter 应用日志
4. 参考 `FIX_ALIPAY_LOGIN_401.md` 详细文档
