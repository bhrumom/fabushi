# 微信公众号登录功能配置指南

## 功能概述

本系统已集成微信公众号登录功能，支持以下特性：

- ✅ 新用户通过微信注册并自动绑定
- ✅ 现有邮箱用户绑定微信账号
- ✅ 微信用户直接登录
- ✅ 微信账号解绑功能
- ✅ 微信账号管理页面

## 配置步骤

### 1. 微信公众号配置

1. 登录 [微信公众平台](https://mp.weixin.qq.com/)
2. 进入"开发" -> "接口权限" -> "网页服务" -> "网页授权获取用户基本信息"
3. 设置授权回调域名（例如：`your-domain.com`）

### 2. 环境变量配置

在 Cloudflare Worker 中设置以下环境变量：

```bash
# 微信公众号配置
WECHAT_APP_ID=your_wechat_app_id
WECHAT_APP_SECRET=your_wechat_app_secret
WECHAT_REDIRECT_URI=https://your-domain.com/wechat-callback.html
```

### 3. 域名配置

确保以下域名已正确配置：

- 主域名：`https://your-domain.com`
- 微信回调地址：`https://your-domain.com/wechat-callback.html`

## API 接口说明

### 微信登录相关接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/auth/wechat/login-url` | GET | 获取微信登录授权URL |
| `/api/auth/wechat/login` | POST | 处理微信登录回调 |
| `/api/auth/wechat/bind` | POST | 绑定微信到现有账号 |
| `/api/auth/wechat/register` | POST | 微信用户注册新账号 |
| `/api/auth/wechat/unbind` | POST | 解绑微信账号 |
| `/api/auth/user-info` | GET | 获取用户详细信息 |

### 请求示例

#### 获取微信登录URL
```javascript
const response = await fetch('/api/auth/wechat/login-url', {
  method: 'GET'
});
const data = await response.json();
// 返回: { authUrl: "https://open.weixin.qq.com/...", state: "uuid" }
```

#### 处理微信登录
```javascript
const response = await fetch('/api/auth/wechat/login', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ code: 'auth_code', state: 'uuid' })
});
```

#### 绑定现有账号
```javascript
const response = await fetch('/api/auth/wechat/bind', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ 
    openid: 'wechat_openid', 
    email: 'user@example.com', 
    password: 'password' 
  })
});
```

## 前端页面

### 新增页面

1. **微信登录回调页面** (`/wechat-callback.html`)
   - 处理微信授权回调
   - 自动判断新用户/现有用户
   - 提供绑定/注册界面

2. **微信账号管理页面** (`/wechat-settings.html`)
   - 查看微信绑定状态
   - 绑定/解绑微信账号
   - 管理微信登录设置

### 更新页面

1. **登录页面** (`/login.html`)
   - 添加微信登录按钮
   - 保持原有邮箱登录功能

2. **注册页面** (`/register.html`)
   - 添加微信登录按钮
   - 保持原有邮箱注册功能

## 数据存储结构

### 用户数据扩展

在现有用户数据基础上添加微信相关字段：

```javascript
{
  // 原有字段...
  username: "user123",
  email: "user@example.com",
  
  // 新增微信字段
  wechatOpenid: "wx_openid_123",
  wechatNickname: "微信昵称",
  wechatHeadimgurl: "https://...",
  wechatBoundAt: "2024-01-01T00:00:00.000Z"
}
```

### KV 存储键值

- `wechat_binding:{openid}` -> `username` (微信OpenID到用户名的映射)
- `user_wechat:{username}` -> `openid` (用户名到微信OpenID的映射)
- `wechat_state:{state}` -> `valid` (微信授权状态验证)

## 使用流程

### 新用户微信注册流程

1. 用户点击"微信登录"按钮
2. 跳转到微信授权页面
3. 用户授权后回调到 `/wechat-callback.html`
4. 系统检测到新用户，显示注册表单
5. 用户填写用户名、邮箱、密码
6. 系统创建账号并绑定微信
7. 自动登录并跳转到首页

### 现有用户绑定微信流程

1. 用户点击"微信登录"按钮
2. 跳转到微信授权页面
3. 用户授权后回调到 `/wechat-callback.html`
4. 系统检测到已有账号，显示绑定表单
5. 用户输入邮箱和密码
6. 系统验证密码并绑定微信
7. 自动登录并跳转到首页

### 微信用户直接登录流程

1. 用户点击"微信登录"按钮
2. 跳转到微信授权页面
3. 用户授权后回调到 `/wechat-callback.html`
4. 系统检测到已绑定账号
5. 直接登录并跳转到首页

## 安全考虑

1. **State 参数验证**：防止 CSRF 攻击
2. **OpenID 唯一性**：确保一个微信账号只能绑定一个系统账号
3. **密码验证**：绑定现有账号时需要验证密码
4. **Token 管理**：使用 JWT 进行身份验证
5. **HTTPS 要求**：微信授权必须在 HTTPS 环境下进行

## 测试建议

1. **功能测试**
   - 新用户微信注册
   - 现有用户绑定微信
   - 微信用户直接登录
   - 微信账号解绑

2. **安全测试**
   - 重复绑定测试
   - 无效授权码测试
   - State 参数验证测试

3. **用户体验测试**
   - 移动端适配
   - 网络异常处理
   - 错误提示友好性

## 故障排除

### 常见问题

1. **微信授权失败**
   - 检查 APP_ID 和 APP_SECRET 是否正确
   - 确认回调域名已配置
   - 检查网络连接

2. **绑定失败**
   - 确认邮箱和密码正确
   - 检查账号是否已绑定其他微信
   - 查看控制台错误信息

3. **登录失败**
   - 检查 JWT 配置
   - 确认用户数据完整性
   - 查看 Worker 日志

### 调试工具

- 浏览器开发者工具
- Cloudflare Worker 日志
- 微信开发者工具

## 更新日志

- **v1.0.0** (2024-01-01)
  - 初始版本
  - 支持微信登录、注册、绑定功能
  - 添加微信账号管理页面
  - 完善错误处理和用户体验

