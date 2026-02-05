# Flutter应用后端集成指南

本指南将帮助你将Cloudflare Worker后端集成到Flutter应用中，实现与Web版本的用户数据共享。

## 📋 概述

已成功将以下文件复制到Flutter项目中：

### 后端文件 (web/cloudflare-backend/)
- `worker.js` - 主要的Worker代码
- `wrangler.toml` - Cloudflare配置文件
- `alipay-config.js` - 支付宝配置
- `alipay-utils.js` - 支付宝工具函数
- `stripe-config.js` - Stripe配置
- `package.json` - 项目依赖
- `deploy.sh` - 部署脚本
- `README.md` - 详细文档

### Flutter集成文件 (lib/)
- `config/api_config.dart` - API配置
- `services/auth_service.dart` - 认证服务
- `services/http_service.dart` - HTTP服务
- `models/user_model.dart` - 用户数据模型

## 🚀 快速开始

### 1. 部署Cloudflare Worker后端

```bash
cd 全球法布施/web/cloudflare-backend

# 给部署脚本执行权限
chmod +x deploy.sh

# 运行部署脚本
./deploy.sh
```

### 2. 配置Flutter应用

#### 2.1 更新API配置

编辑 `lib/config/api_config.dart`，将 `baseUrl` 替换为你的Worker域名：

```dart
// 替换为你的实际域名
static const String baseUrl = 'https://fabushi-prod.你的账户名.workers.dev';
```

#### 2.2 添加依赖

在 `pubspec.yaml` 中添加必要的依赖：

```yaml
dependencies:
  flutter:
    sdk: flutter
  http: ^1.1.0
  shared_preferences: ^2.2.2
  # 其他现有依赖...
```

然后运行：
```bash
flutter pub get
```

#### 2.3 初始化认证服务

在 `lib/main.dart` 中初始化认证服务：

```dart
import 'package:flutter/material.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化认证服务
  await AuthService().initialize();
  
  runApp(MyApp());
}
```

### 3. 使用认证服务

#### 3.1 用户登录

```dart
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _authService = AuthService();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  Future<void> _login() async {
    final result = await _authService.login(
      _usernameController.text,
      _passwordController.text,
    );
    
    if (result['success']) {
      // 登录成功，跳转到主页
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      // 显示错误消息
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'])),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('登录')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: '用户名'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: '密码'),
              obscureText: true,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _login,
              child: Text('登录'),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### 3.2 用户注册

```dart
class RegisterPage extends StatefulWidget {
  @override
  _RegisterPageState createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _authService = AuthService();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  
  Future<void> _sendVerificationCode() async {
    final result = await _authService.sendVerificationCode(
      email: _emailController.text,
      type: 'register',
    );
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(result['message'] ?? result['error'])),
    );
  }
  
  Future<void> _register() async {
    final result = await _authService.register(
      username: _usernameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      verificationCode: _codeController.text,
    );
    
    if (result['success']) {
      // 注册成功，跳转到登录页
      Navigator.pushReplacementNamed(context, '/login');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'])),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('注册')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(labelText: '用户名'),
            ),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(labelText: '邮箱'),
            ),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(labelText: '密码'),
              obscureText: true,
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    decoration: InputDecoration(labelText: '验证码'),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _sendVerificationCode,
                  child: Text('发送验证码'),
                ),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _register,
              child: Text('注册'),
            ),
          ],
        ),
      ),
    );
  }
}
```

#### 3.3 检查登录状态

```dart
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _authService = AuthService();
  
  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }
  
  Future<void> _checkAuthStatus() async {
    if (!_authService.isLoggedIn) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }
    
    // 验证token是否仍然有效
    final isValid = await _authService.verifyToken();
    if (!isValid) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }
  
  Future<void> _logout() async {
    await _authService.logout();
    Navigator.pushReplacementNamed(context, '/login');
  }
  
  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: Text('全球法布施'),
        actions: [
          IconButton(
            icon: Icon(Icons.logout),
            onPressed: _logout,
          ),
        ],
      ),
      body: user != null
          ? Column(
              children: [
                ListTile(
                  title: Text('欢迎, ${user.displayName}'),
                  subtitle: Text(user.email ?? '未绑定邮箱'),
                ),
                ListTile(
                  title: Text('会员状态'),
                  subtitle: Text(user.membership.displayName),
                  trailing: user.membership.isActive
                      ? Icon(Icons.check_circle, color: Colors.green)
                      : Icon(Icons.cancel, color: Colors.red),
                ),
                // 其他UI组件...
              ],
            )
          : Center(child: CircularProgressIndicator()),
    );
  }
}
```

## 🔧 高级配置

### 1. 环境变量配置

创建 `lib/config/env_config.dart`：

```dart
class EnvConfig {
  static const String environment = String.fromEnvironment('ENVIRONMENT', defaultValue: 'development');
  
  static String get apiBaseUrl {
    switch (environment) {
      case 'production':
        return 'https://api.ombhrum.com';
      case 'staging':
        return 'https://staging-api.ombhrum.com';
      default:
        return 'https://fabushi-prod.你的账户名.workers.dev';
    }
  }
}
```

### 2. 错误处理

创建 `lib/utils/error_handler.dart`：

```dart
class ErrorHandler {
  static String getErrorMessage(dynamic error) {
    if (error is Exception) {
      return error.toString().replaceFirst('Exception: ', '');
    }
    return error.toString();
  }
  
  static void showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }
  
  static void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 2),
      ),
    );
  }
}
```

### 3. 状态管理集成

如果使用Provider状态管理：

```dart
// lib/providers/auth_provider.dart
import 'package:flutter/foundation.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class AuthProvider with ChangeNotifier {
  final AuthService _authService = AuthService();
  
  UserModel? get currentUser => _authService.currentUser;
  bool get isLoggedIn => _authService.isLoggedIn;
  
  Future<bool> login(String username, String password) async {
    final result = await _authService.login(username, password);
    if (result['success']) {
      notifyListeners();
      return true;
    }
    return false;
  }
  
  Future<void> logout() async {
    await _authService.logout();
    notifyListeners();
  }
  
  Future<void> refreshUserInfo() async {
    await _authService.refreshUserInfo();
    notifyListeners();
  }
}
```

## 📱 平台特定配置

### Android配置

在 `android/app/src/main/AndroidManifest.xml` 中添加网络权限：

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
```

### iOS配置

在 `ios/Runner/Info.plist` 中添加网络配置：

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>
```

## 🔐 安全注意事项

1. **Token存储**: 使用 `shared_preferences` 安全存储认证token
2. **HTTPS**: 确保所有API请求都使用HTTPS
3. **输入验证**: 在客户端进行基本的输入验证
4. **错误处理**: 不要在错误消息中暴露敏感信息

## 🧪 测试

### 单元测试示例

```dart
// test/services/auth_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:your_app/services/auth_service.dart';

void main() {
  group('AuthService', () {
    late AuthService authService;
    
    setUp(() {
      authService = AuthService();
    });
    
    test('should login successfully with valid credentials', () async {
      // 测试登录功能
      final result = await authService.login('testuser', 'password123');
      expect(result['success'], isTrue);
    });
    
    test('should fail login with invalid credentials', () async {
      // 测试登录失败
      final result = await authService.login('invalid', 'wrong');
      expect(result['success'], isFalse);
    });
  });
}
```

## 🚀 部署和发布

### 1. 构建应用

```bash
# Android
flutter build apk --release

# iOS
flutter build ios --release
```

### 2. 更新API配置

在发布前，确保将API配置更新为生产环境的URL。

### 3. 测试

在发布前进行完整的功能测试：
- 用户注册和登录
- 邮箱验证
- 会员功能
- 支付功能（如果启用）

## 📞 支持和故障排除

### 常见问题

1. **网络请求失败**
   - 检查网络权限配置
   - 确认API URL正确
   - 检查Cloudflare Worker是否正常运行

2. **认证失败**
   - 检查token是否正确存储
   - 确认token未过期
   - 检查API认证逻辑

3. **数据不同步**
   - 确认使用相同的KV存储空间
   - 检查数据格式是否一致

### 调试技巧

1. 启用API日志记录
2. 使用Cloudflare Dashboard查看Worker日志
3. 使用Flutter Inspector检查状态

## 🔄 更新和维护

### 更新后端

```bash
cd web/cloudflare-backend
wrangler deploy
```

### 更新Flutter应用

1. 更新依赖版本
2. 测试新功能
3. 发布新版本

---

现在你的Flutter应用已经成功集成了Cloudflare Worker后端，可以与Web版本共享用户数据和会员系统！