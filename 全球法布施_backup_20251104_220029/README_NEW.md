# 全球法布施 Flutter 应用

> 基于Flutter开发的跨平台佛教经文全球传播应用

[![Flutter](https://img.shields.io/badge/Flutter-3.8.0+-blue.svg)](https://flutter.dev/)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

## 📱 应用简介

全球法布施是一个现代化的跨平台应用，旨在通过技术手段将佛教经文和法布施内容传播到全世界。应用集成了用户认证、会员管理、全球文件传输、视频流等功能。

### 核心功能

- 🔐 **用户认证** - 注册、登录、邮箱验证、密码找回
- 👥 **会员系统** - 多层级会员、兑换码、支付集成
- 🌍 **全球传输** - 多国家IP支持、实时进度、传输统计
- 📖 **经文内容** - 搜索、阅读、下载佛教经文
- 🎥 **视频流** - 法布施视频内容流
- 📊 **排行榜** - 用户贡献排名

### 支持平台

✅ Android | ✅ iOS | ✅ Web | ✅ macOS | ✅ Windows | ✅ Linux

## 🚀 快速开始

### 环境要求

- Flutter SDK >= 3.8.0
- Dart SDK >= 3.8.0
- Android Studio / VS Code / Xcode

### 安装步骤

```bash
# 1. 克隆项目
git clone <repository-url>
cd 全球法布施

# 2. 安装依赖
flutter pub get

# 3. 运行应用
flutter run

# 4. 指定平台运行
flutter run -d chrome      # Web
flutter run -d android     # Android
flutter run -d ios         # iOS
```

### 配置后端

编辑 `lib/core/config/app_config.dart`：

```dart
static const String apiUrl = 'https://your-backend-url.com';
```

## 📁 项目结构

```
lib/
├── core/              # 核心层
│   ├── config/       # 配置
│   ├── constants/    # 常量
│   ├── network/      # 网络
│   └── utils/        # 工具
├── features/          # 功能模块
│   ├── auth/         # 认证
│   ├── membership/   # 会员
│   ├── transfer/     # 传输
│   ├── dharma/       # 法布施内容
│   └── profile/      # 个人中心
├── shared/            # 共享组件
└── routes/            # 路由
```

## 🔧 开发指南

### 代码规范

- 文件名：`snake_case.dart`
- 类名：`PascalCase`
- 变量/方法：`camelCase`
- 常量：`UPPER_SNAKE_CASE`

### 提交规范

```
feat: 添加新功能
fix: 修复bug
docs: 更新文档
style: 代码格式
refactor: 重构
test: 测试
```

### 常用命令

```bash
# 格式化代码
dart format .

# 代码分析
flutter analyze

# 运行测试
flutter test

# 构建发布版
flutter build apk --release        # Android
flutter build ios --release        # iOS
flutter build web --release        # Web
```

## 📚 文档

- [完整重构计划](PROJECT_REFACTOR_PLAN.md)
- [快速重构指南](QUICK_REFACTOR_GUIDE.md)
- [维护指南](MAINTENANCE_GUIDE.md)
- [API文档](docs/api/)
- [架构文档](docs/architecture/)
- [部署文档](docs/deployment/)

## 🔄 项目重构

项目正在进行结构优化，提升可维护性：

```bash
# 执行自动重构
./refactor_project.sh

# 查看重构计划
cat PROJECT_REFACTOR_PLAN.md

# 查看快速指南
cat QUICK_REFACTOR_GUIDE.md
```

## 🏗️ 技术栈

### 前端
- **框架**: Flutter 3.8+
- **状态管理**: Provider + BLoC
- **依赖注入**: GetIt
- **网络**: Dio + HTTP
- **本地存储**: SharedPreferences

### 后端
- **平台**: Cloudflare Workers
- **数据库**: Cloudflare D1
- **存储**: Cloudflare R2 + KV
- **认证**: JWT

### 第三方服务
- **认证**: Firebase Auth
- **支付**: Stripe + 支付宝
- **地图**: Flutter Map
- **3D渲染**: Three.js

## 🧪 测试

```bash
# 单元测试
flutter test test/unit/

# Widget测试
flutter test test/widget/

# 集成测试
flutter test test/integration/
```

## 📦 构建发布

### Android

```bash
# APK
flutter build apk --release

# App Bundle
flutter build appbundle --release
```

### iOS

```bash
flutter build ios --release
```

### Web

```bash
flutter build web --release
```

## 🤝 贡献

欢迎贡献代码！请遵循以下步骤：

1. Fork 项目
2. 创建功能分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'feat: Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 创建 Pull Request

## 📄 许可证

本项目采用 MIT 许可证 - 查看 [LICENSE](LICENSE) 文件了解详情

## 📞 联系我们

- 官网: https://fabushi.ombhrum.com
- 邮箱: support@fabushi.com
- Issues: [GitHub Issues](https://github.com/your-repo/issues)

## 🙏 致谢

感谢所有贡献者和开源社区的支持！

---

**愿此功德回向法界众生，同证菩提！** 🙏
