# 全球法布施 Flutter 应用

## 项目简介

全球法布施是一个基于Flutter开发的跨平台应用，集成了Cloudflare Workers后端服务，提供用户认证、会员管理、全球文件传输等功能。应用旨在通过现代技术手段，将佛教经文和法布施内容传播到全世界。

## 🌟 主要功能

### 用户认证系统
- ✅ 用户注册与登录
- ✅ 邮箱验证码验证
- ✅ 忘记密码功能
- ✅ JWT Token认证
- ✅ 用户会话管理
- ✅ 安全密码存储

### 会员管理系统
- ✅ 多层级会员体系（试用/月度/季度/年度）
- ✅ 兑换码系统
- ✅ 支付集成（Stripe + 支付宝）
- ✅ 会员权限管理
- ✅ 管理员功能

### 全球传输功能
- ✅ 全球文件传输
- ✅ 多国家IP地址支持
- ✅ 实时传输进度
- ✅ 网络状态监控
- ✅ 传输统计分析

### 跨平台支持
- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ macOS
- ✅ Windows
- ✅ Linux

## 🏗️ 系统架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Flutter 前端应用                          │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │  认证模块    │  │  会员模块    │  │  传输模块    │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
├─────────────────────────────────────────────────────────────┤
│                    HTTP/HTTPS API                          │
├─────────────────────────────────────────────────────────────┤
│                 Cloudflare Workers 后端                    │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐        │
│  │   KV存储     │  │   R2存储     │  │  邮件服务    │        │
│  └─────────────┘  └─────────────┘  └─────────────┘        │
└─────────────────────────────────────────────────────────────┘
```

## 📱 界面预览

### 主要界面
- **主屏幕**: 文件选择、传输控制、状态显示
- **登录界面**: 用户登录、注册入口
- **注册界面**: 用户注册、邮箱验证
- **个人中心**: 用户信息、会员状态、兑换码
- **会员中心**: 会员套餐、支付购买
- **设置界面**: 应用配置、传输设置

## 🚀 快速开始

### 环境要求
- Flutter SDK >= 3.0.0
- Dart SDK >= 3.0.0
- Android Studio / VS Code
- Xcode (iOS开发)

### 安装步骤

1. **克隆项目**
```bash
git clone <repository-url>
cd 全球法布施
```

2. **安装依赖**
```bash
flutter pub get
```

3. **配置后端URL**
编辑 `lib/config.dart` 文件：
```dart
static const String backendUrl = 'https://your-cloudflare-worker.workers.dev';
```

4. **运行应用**
```bash
# 调试模式
flutter run

# 发布模式
flutter run --release

# 指定平台
flutter run -d chrome  # Web
flutter run -d android # Android
flutter run -d ios     # iOS
```

### 构建发布版本

```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release

# macOS
flutter build macos --release

# Windows
flutter build windows --release
```

## 🔧 配置说明

### 后端配置
应用需要配合Cloudflare Workers后端使用，后端代码位于 `native-web/deploy-package/` 目录。

主要配置项：
- **认证服务**: JWT Token验证
- **会员服务**: 支付和会员管理
- **邮件服务**: 验证码和通知
- **存储服务**: KV和R2存储

### 应用配置
主要配置文件：`lib/config.dart`

```dart
class AppConfig {
  // 后端API地址
  static const String backendUrl = 'https://fabushi.ombhrum.com';
  
  // 支持的国家列表
  static const List<String> countryCodes = ['ALL', 'US', 'CN', 'IN', ...];
  
  // 传输配置
  static const int fileChunkSize = 1024;
  static const int maxRetryCount = 3;
  static const int timeoutDuration = 5000;
}
```

## 📚 API文档

### 认证相关API

#### 用户登录
```http
POST /api/auth/login
Content-Type: application/json

{
  "username": "用户名或邮箱",
  "password": "密码"
}
```

#### 用户注册
```http
POST /api/auth/register
Content-Type: application/json

{
  "username": "用户名",
  "email": "邮箱",
  "password": "密码",
  "verificationCode": "验证码"
}
```

#### 发送验证码
```http
POST /api/auth/send-verification-code
Content-Type: application/json

{
  "email": "邮箱",
  "type": "register|forgot"
}
```

### 会员相关API

#### 获取会员状态
```http
GET /api/membership/status
Authorization: Bearer <token>
```

#### 兑换码使用
```http
POST /api/redeem/use
Authorization: Bearer <token>
Content-Type: application/json

{
  "code": "兑换码"
}
```

## 🎯 功能特性

### 用户体验
- **现代化UI**: Material Design 3设计语言
- **响应式布局**: 适配各种屏幕尺寸
- **流畅动画**: 自然的过渡效果
- **多语言支持**: 中文界面
- **深色模式**: 护眼模式支持

### 安全特性
- **密码加密**: PBKDF2-SHA256加密存储
- **JWT认证**: 安全的Token机制
- **HTTPS通信**: 全程加密传输
- **输入验证**: 防止恶意输入
- **会话管理**: 自动登录和安全登出

### 性能优化
- **状态管理**: Provider状态管理
- **内存优化**: 合理的资源管理
- **网络优化**: 请求缓存和重试机制
- **异步处理**: 非阻塞UI操作
- **错误处理**: 完善的异常处理机制

## 🔍 开发指南

### 项目结构
```
lib/
├── main.dart                 # 应用入口
├── config.dart              # 配置文件
├── models/                  # 数据模型
│   ├── auth_model.dart      # 认证模型
│   ├── file_transfer_model.dart
│   └── settings_model.dart
├── services/                # 服务层
│   ├── auth_service.dart    # 认证服务
│   ├── membership_service.dart
│   └── global_transfer_service.dart
├── screens/                 # 界面
│   ├── home_screen.dart     # 主界面
│   ├── login_screen.dart    # 登录界面
│   ├── register_screen.dart # 注册界面
│   ├── profile_screen.dart  # 个人中心
│   └── membership_screen.dart
├── widgets/                 # 组件
└── utils/                   # 工具类
```

### 状态管理
使用Provider进行状态管理：

```dart
// 在main.dart中注册Provider
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (context) => AuthModel()),
    ChangeNotifierProvider(create: (context) => FileTransferModel()),
  ],
  child: MaterialApp(...),
)

// 在界面中使用
Consumer<AuthModel>(
  builder: (context, authModel, child) {
    return Text(authModel.currentUser?.username ?? '未登录');
  },
)
```

### 网络请求
使用http包进行网络请求：

```dart
final response = await http.post(
  Uri.parse('$baseUrl/api/auth/login'),
  headers: {'Content-Type': 'application/json'},
  body: jsonEncode({'username': username, 'password': password}),
);
```

## 🐛 故障排除

### 常见问题

1. **网络连接失败**
   - 检查网络连接
   - 确认后端URL配置正确
   - 检查防火墙设置

2. **登录失败**
   - 确认用户名密码正确
   - 检查账户是否已激活
   - 查看网络请求日志

3. **构建失败**
   - 运行 `flutter clean`
   - 重新获取依赖 `flutter pub get`
   - 检查Flutter版本兼容性

4. **权限问题**
   - Android: 检查网络权限
   - iOS: 检查Info.plist配置
   - Web: 检查CORS设置

### 调试技巧

1. **启用调试日志**
```dart
debugPrint('调试信息: $message');
```

2. **网络请求调试**
```dart
print('Request: ${request.url}');
print('Response: ${response.body}');
```

3. **状态调试**
```dart
print('Auth State: ${authModel.isLoggedIn}');
```

## 🤝 贡献指南

### 开发流程
1. Fork项目
2. 创建功能分支
3. 提交代码
4. 创建Pull Request

### 代码规范
- 遵循Dart代码规范
- 使用有意义的变量名
- 添加必要的注释
- 编写单元测试

### 提交规范
```
feat: 添加新功能
fix: 修复bug
docs: 更新文档
style: 代码格式调整
refactor: 代码重构
test: 添加测试
chore: 构建过程或辅助工具的变动
```

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情。

## 🙏 致谢

- Flutter团队提供的优秀框架
- Cloudflare提供的边缘计算服务
- 所有贡献者的辛勤付出

## 📞 联系我们

- 邮箱: support@fabushi.com
- 官网: https://fabushi.ombhrum.com
- 问题反馈: [GitHub Issues](https://github.com/your-repo/issues)

---

**愿此功德回向法界众生，同证菩提！** 🙏