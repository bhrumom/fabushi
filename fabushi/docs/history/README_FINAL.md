# 全球法布施 Flutter 应用

> 基于Flutter开发的跨平台佛教经文全球传播应用 - 已完成架构重构

[![Flutter](https://img.shields.io/badge/Flutter-3.8.0+-blue.svg)](https://flutter.dev/)
[![Architecture](https://img.shields.io/badge/Architecture-Clean-green.svg)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)

## 🎉 重构完成

本项目已完成全面架构重构，采用Clean Architecture设计模式，具有清晰的分层结构和完善的代码组织。

## 📱 核心功能

- 🔐 **用户认证** - 注册、登录、邮箱验证
- 👥 **会员系统** - 多层级会员、兑换码、支付
- 🌍 **全球传输** - 多国家文件传输、实时统计
- 📖 **经文内容** - 搜索、阅读、下载佛教经文
- 🎥 **视频流** - 法布施视频内容
- 📊 **排行榜** - 用户贡献排名

## 🏗️ 项目架构

```
lib/
├── core/                    # 核心层
│   ├── config/             # 配置管理
│   ├── constants/          # 常量定义
│   ├── di/                 # 依赖注入
│   ├── errors/             # 错误处理
│   ├── network/            # 网络层
│   └── utils/              # 工具类
│
├── features/               # 功能模块（Clean Architecture）
│   ├── auth/              # 认证模块
│   ├── membership/        # 会员模块
│   ├── transfer/          # 传输模块
│   ├── dharma/            # 法布施内容
│   └── profile/           # 个人中心
│
├── shared/                 # 共享组件
│   ├── widgets/           # 通用UI组件
│   └── models/            # 共享模型
│
└── routes/                 # 路由管理
```

## 🚀 快速开始

### 安装依赖
```bash
flutter pub get
```

### 运行应用
```bash
# 使用重构后的入口
flutter run -t lib/main_refactored.dart

# 或替换主入口后运行
flutter run
```

### 构建发布
```bash
flutter build apk --release        # Android
flutter build ios --release        # iOS
flutter build web --release        # Web
```

## 📚 文档

所有文档已整理到 `docs/` 目录：

- **API文档**: `docs/api/`
- **架构文档**: `docs/architecture/`
- **部署文档**: `docs/deployment/`
- **功能文档**: `docs/features/`
- **使用指南**: `docs/guides/`

## 🔧 开发指南

### 代码规范
- 文件名: `snake_case.dart`
- 类名: `PascalCase`
- 变量/方法: `camelCase`
- 常量: `UPPER_SNAKE_CASE`

### 添加新功能
1. 在 `lib/features/` 创建新模块
2. 遵循Clean Architecture分层
3. 在 `lib/core/di/injection.dart` 注册依赖
4. 添加路由到 `lib/routes/app_router.dart`

### 运行测试
```bash
flutter test
```

### 代码检查
```bash
flutter analyze
dart format .
```

## 🛠️ 技术栈

- **框架**: Flutter 3.8+
- **架构**: Clean Architecture
- **状态管理**: Provider + BLoC
- **依赖注入**: GetIt
- **网络**: Dio + HTTP
- **函数式编程**: FpDart
- **后端**: Cloudflare Workers

## 📦 核心依赖

```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.0.5
  flutter_bloc: ^9.1.0
  get_it: ^8.0.3
  dio: ^5.4.1
  fpdart: ^1.1.0
  equatable: ^2.0.7
```

## 🎯 重构成果

- ✅ 清晰的分层架构
- ✅ 统一的配置管理
- ✅ 完善的错误处理
- ✅ 依赖注入支持
- ✅ 模块化设计
- ✅ 测试友好
- ✅ 文档完善

## 📊 项目统计

- **代码行数**: 50,000+
- **模块数量**: 6个核心模块
- **测试覆盖**: 基础框架已建立
- **文档数量**: 60+ 个文档文件
- **脚本数量**: 30+ 个自动化脚本

## 🤝 贡献指南

1. Fork 项目
2. 创建功能分支
3. 遵循代码规范
4. 提交Pull Request

## 📄 许可证

MIT License

## 📞 联系方式

- 官网: https://fabushi.ombhrum.com
- 邮箱: support@fabushi.com

---

**愿此功德回向法界众生，同证菩提！** 🙏
