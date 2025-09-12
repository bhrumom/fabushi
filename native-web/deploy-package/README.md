# Cloudflare 登录系统部署指南

本项目为佛教经文发送系统添加了基于 Cloudflare Workers 的登录认证功能。

## 功能特性

- ✅ 用户注册与登录
- ✅ JWT Token 认证
- ✅ 用户会话管理
- ✅ 密码安全存储（哈希加密）
- ✅ 登录状态持久化
- ✅ 登出功能

## 文件结构

```
deploy-package/
├── index.html          # 主页面（需要登录）
├── login.html          # 登录页面
├── register.html       # 注册页面
├── worker.js           # Cloudflare Workers 认证服务
├── wrangler.toml       # Cloudflare 配置文件
└── README.md          # 本文件
```

## 部署步骤

### 1. 准备工作

确保已安装：
- Node.js (v16+)
- Wrangler CLI (`npm install -g wrangler`)
- Cloudflare 账号

### 2. 配置 KV 存储

登录 Cloudflare 控制台：
1. 进入 Workers & Pages
2. 选择 KV
3. 创建一个新的 KV 命名空间，命名为 `users-kv`
4. 记录命名空间 ID

### 3. 更新 wrangler.toml

编辑 `wrangler.toml` 文件，将 `id` 替换为你的 KV 命名空间 ID：

```toml
name = "fabushi"
main = "worker.js"
compatibility_date = "2024-01-01"

[[kv_namespaces]]
binding = "USERS_KV"
id = "你的kv命名空间id"

[env.production]
name = "fabushi-prod"

[[env.production.kv_namespaces]]
binding = "USERS_KV"
id = "你的kv命名空间id"
```

### 4. 配置 Wrangler

1. 登录 Wrangler：
```bash
wrangler login
```

2. 验证配置：
```bash
wrangler whoami
```

### 5. 部署到 Cloudflare

#### 开发环境部署：
```bash
wrangler dev
```

#### 生产环境部署：
```bash
wrangler deploy
```

### 6. 访问应用

部署完成后，你将获得一个类似 `https://fabushi.your-subdomain.workers.dev` 的 URL。

- 主页面：`https://your-domain.workers.dev/`
- 登录页面：`https://your-domain.workers.dev/login.html`
- 注册页面：`https://your-domain.workers.dev/register.html`

## 使用说明

### 注册新用户
1. 访问注册页面 `/register.html`
2. 填写用户名、邮箱和密码
3. 点击"注册"按钮

### 登录系统
1. 访问登录页面 `/login.html`
2. 输入用户名和密码
3. 点击"登录"按钮
4. 登录成功后将自动跳转到主页面

### 登出系统
1. 在主页面右上角点击用户名旁的"退出"按钮
2. 确认登出后将返回登录页面

## API 接口

### 注册接口
- **POST** `/api/auth/register`
- **Body**: `{ username, email, password, verificationCode }`

### 登录接口
- **POST** `/api/auth/login`
- **Body**: `{ username, password }`
- **Response**: `{ token, username }`

### 验证接口
- **GET** `/api/auth/verify`
- **Headers**: `Authorization: Bearer <token>`
- **Response**: `{ username }`

### 登出接口
- **POST** `/api/auth/logout`
- **Headers**: `Authorization: Bearer <token>`

### 发送邮箱验证码
- **POST** `/api/auth/send-verification-code`
- **Body**: `{ email, type?: 'register' | 'forgot' }`（默认 `register`）
- **Response**: `{ message }`

### 验证邮箱验证码
- **POST** `/api/auth/verify-code`
- **Body**: `{ email, code }`
- **Response**: `{ message }`

### 忘记密码
- **POST** `/api/auth/forgot-password`
- **Body**: `{ email }`
- **Response**: `{ message }`

### 重置密码
- **POST** `/api/auth/reset-password`
- **Body**: `{ email, token, newPassword }`
- **Response**: `{ message }`

## 安全特性

- 密码使用 PBKDF2-SHA256 + Salt 存储；旧用户会在首次登录后平滑升级
- JWT 使用 HMAC-SHA256 签名（密钥可通过环境变量配置），有效期 7 天
- 支持 CORS 跨域请求
- 输入验证和错误处理
- 邮箱验证码发送增加频率限制（默认 60 秒）

## 故障排除

### 常见问题

1. **KV 存储未配置**
   - 确保在 Cloudflare 控制台创建了 KV 命名空间
   - 检查 wrangler.toml 中的 ID 是否正确

2. **部署失败**
   - 检查 wrangler 是否已登录：`wrangler whoami`
   - 确保 KV 命名空间已绑定

3. **登录失败**
   - 检查用户名和密码是否正确
   - 查看浏览器控制台网络请求
   
4. **收不到验证码**
   - 同一邮箱 60 秒内仅允许请求一次
   - 检查邮箱是否填写正确，或查看垃圾箱

### 调试命令

```bash
# 查看日志
wrangler tail

# 本地开发调试
wrangler dev --local

# 检查 KV 内容
wrangler kv:key list --binding USERS_KV
```

## 后续扩展

- [ ] 添加密码重置功能
- [ ] 支持第三方登录（Google、GitHub）
- [ ] 添加用户角色和权限管理
- [ ] 实现用户统计和分析

## 技术支持

如有问题，请检查：
- Cloudflare Workers 文档：https://developers.cloudflare.com/workers/
- Wrangler CLI 文档：https://developers.cloudflare.com/workers/wrangler/

---

**愿此功德回向法界众生，同证菩提！** 🙏# fabushi
