# Flutter应用Cloudflare Worker后端

这个目录包含了Flutter应用的Cloudflare Worker后端代码，与之前部署的Web版本共享相同的用户数据库和会员系统。

## 功能特性

- 🔐 **用户认证系统**: 注册、登录、邮箱验证、忘记密码
- 👥 **微信登录**: 支持微信公众号授权登录
- 💳 **支付系统**: 支持支付宝当面付和Stripe支付
- 🎫 **会员系统**: 试用期、付费会员、兑换码系统
- 👑 **管理员系统**: 兑换码生成、用户管理
- 📧 **邮件服务**: 支持多种邮件服务提供商
- 💾 **数据存储**: 使用Cloudflare KV和R2存储

## 文件说明

- `worker.js` - 主要的Worker代码，包含所有API端点
- `wrangler.toml` - Cloudflare Worker配置文件
- `alipay-config.js` - 支付宝支付配置
- `alipay-utils.js` - 支付宝工具函数
- `stripe-config.js` - Stripe支付配置
- `package.json` - 项目依赖配置
- `deploy.sh` - 自动部署脚本

## 快速部署

1. **安装Wrangler CLI**:
   ```bash
   npm install -g wrangler
   ```

2. **登录Cloudflare**:
   ```bash
   wrangler login
   ```

3. **运行部署脚本**:
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

## 手动部署步骤

### 1. 创建KV存储空间

```bash
# 用户数据存储
wrangler kv:namespace create "USERS_KV"

# 支付订单存储
wrangler kv:namespace create "ORDERS_KV"

# 会员信息存储
wrangler kv:namespace create "MEMBERSHIP_KV"

# 兑换码存储
wrangler kv:namespace create "REDEEM_CODES_KV"
```

### 2. 创建R2存储桶

```bash
wrangler r2 bucket create bushi
```

### 3. 设置环境变量

在Cloudflare Dashboard中设置以下Secrets:

```bash
# 必需的环境变量
wrangler secret put JWT_SECRET
# 输入一个强密码作为JWT密钥

# 可选的邮件服务
wrangler secret put RESEND_API_KEY
# 输入Resend API密钥

# 可选的支付宝配置
wrangler secret put ALIPAY_APP_ID
wrangler secret put ALIPAY_PRIVATE_KEY
wrangler secret put ALIPAY_PUBLIC_KEY

# 可选的Stripe配置
wrangler secret put STRIPE_SECRET_KEY
wrangler secret put STRIPE_WEBHOOK_SECRET

# 可选的微信登录配置
wrangler secret put WECHAT_APP_ID
wrangler secret put WECHAT_APP_SECRET
```

### 4. 部署Worker

```bash
wrangler deploy
```

## API端点

### 认证相关
- `POST /api/auth/register` - 用户注册
- `POST /api/auth/login` - 用户登录
- `GET /api/auth/verify` - 验证Token
- `POST /api/auth/send-verification-code` - 发送验证码
- `POST /api/auth/forgot-password` - 忘记密码
- `POST /api/auth/reset-password` - 重置密码

### 微信登录
- `GET /api/auth/wechat/login-url` - 获取微信登录URL
- `POST /api/auth/wechat/login` - 微信登录
- `POST /api/auth/wechat/bind` - 绑定微信账号
- `POST /api/auth/wechat/register` - 微信注册

### 支付宝支付
- `POST /api/alipay/create-order` - 创建支付订单
- `GET /api/alipay/query-order` - 查询订单状态
- `POST /api/alipay/notify` - 支付回调

### Stripe支付
- `GET /api/stripe/membership-status` - 获取会员状态
- `POST /api/stripe/create-subscription` - 创建订阅
- `POST /api/stripe/cancel-subscription` - 取消订阅

### 管理员系统
- `GET /api/admin/check-status` - 检查管理员状态
- `POST /api/admin/create-redeem-code` - 生成兑换码
- `GET /api/admin/redeem-codes` - 查询兑换码列表
- `POST /api/admin/use-redeem-code` - 使用兑换码

## Flutter应用集成

### 1. 配置API端点

在Flutter应用中设置API基础URL:

```dart
// lib/config/api_config.dart
class ApiConfig {
  static const String baseUrl = 'https://fabushi-prod.你的账户名.workers.dev';
  
  // API端点
  static const String loginUrl = '$baseUrl/api/auth/login';
  static const String registerUrl = '$baseUrl/api/auth/register';
  static const String verifyUrl = '$baseUrl/api/auth/verify';
  // ... 其他端点
}
```

### 2. 用户认证服务

```dart
// lib/services/auth_service.dart
class AuthService {
  static Future<Map<String, dynamic>> login(String username, String password) async {
    final response = await http.post(
      Uri.parse(ApiConfig.loginUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
      }),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      // 保存token到本地存储
      await _saveToken(data['token']);
      return data;
    } else {
      throw Exception('登录失败');
    }
  }
  
  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }
}
```

### 3. HTTP拦截器

```dart
// lib/services/http_service.dart
class HttpService {
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }
  
  static Future<http.Response> authenticatedRequest(
    String method,
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _getToken();
    final headers = {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    
    switch (method.toUpperCase()) {
      case 'GET':
        return http.get(Uri.parse(url), headers: headers);
      case 'POST':
        return http.post(
          Uri.parse(url),
          headers: headers,
          body: body != null ? jsonEncode(body) : null,
        );
      default:
        throw Exception('不支持的HTTP方法');
    }
  }
}
```

## 数据共享说明

此后端与Web版本共享以下数据:

1. **用户账户**: 用户可以在Web版和移动版之间无缝切换
2. **会员状态**: 会员权限在所有平台同步
3. **支付记录**: 支付历史和订单信息共享
4. **兑换码**: 兑换码可在任意平台使用

## 安全注意事项

1. **JWT密钥**: 确保JWT_SECRET足够复杂且保密
2. **API密钥**: 所有第三方服务密钥都应通过Cloudflare Secrets设置
3. **CORS配置**: 根据需要调整CORS设置
4. **速率限制**: 考虑添加API速率限制

## 故障排除

### 常见问题

1. **KV存储空间ID不匹配**:
   - 检查wrangler.toml中的KV namespace ID
   - 使用`wrangler kv:namespace list`查看现有空间

2. **邮件发送失败**:
   - 检查RESEND_API_KEY是否正确设置
   - 确认发件人邮箱已验证

3. **支付回调失败**:
   - 检查支付宝/Stripe的回调URL配置
   - 确认Worker域名可以被外部访问

### 调试方法

1. **查看Worker日志**:
   ```bash
   wrangler tail
   ```

2. **本地开发**:
   ```bash
   wrangler dev
   ```

3. **测试API端点**:
   ```bash
   curl -X POST https://your-worker.workers.dev/api/auth/login \
     -H "Content-Type: application/json" \
     -d '{"username":"test","password":"test123"}'
   ```

## 更新和维护

1. **更新Worker代码**:
   ```bash
   wrangler deploy
   ```

2. **更新KV数据**:
   ```bash
   wrangler kv:key put --binding=USERS_KV "key" "value"
   ```

3. **备份数据**:
   ```bash
   wrangler kv:key list --binding=USERS_KV
   ```

## 支持

如果遇到问题，请检查:
1. Cloudflare Dashboard中的Worker日志
2. KV存储空间的配置
3. 环境变量的设置
4. Flutter应用的网络权限配置