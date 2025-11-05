# 项目维护指南

## 📋 目录

1. [日常维护](#日常维护)
2. [代码规范](#代码规范)
3. [版本管理](#版本管理)
4. [依赖更新](#依赖更新)
5. [性能优化](#性能优化)
6. [问题排查](#问题排查)

## 日常维护

### 代码提交规范

使用语义化提交信息：

```
feat: 添加新功能
fix: 修复bug
docs: 更新文档
style: 代码格式调整
refactor: 代码重构
test: 添加测试
chore: 构建/工具变动
perf: 性能优化
```

示例：
```bash
git commit -m "feat: 添加会员兑换码功能"
git commit -m "fix: 修复登录页面验证码显示问题"
```

### 分支管理

- `main` - 生产环境分支
- `develop` - 开发分支
- `feature/*` - 功能分支
- `hotfix/*` - 紧急修复分支
- `release/*` - 发布分支

工作流程：
```bash
# 创建功能分支
git checkout -b feature/new-feature develop

# 开发完成后合并到develop
git checkout develop
git merge --no-ff feature/new-feature

# 发布时创建release分支
git checkout -b release/1.1.0 develop

# 发布后合并到main和develop
git checkout main
git merge --no-ff release/1.1.0
git tag -a v1.1.0
```

## 代码规范

### 文件组织

每个功能模块遵循以下结构：

```
feature_name/
├── data/
│   ├── models/           # 数据模型
│   ├── datasources/      # 数据源
│   └── repositories/     # 仓库实现
├── domain/
│   ├── entities/         # 实体
│   ├── repositories/     # 仓库接口
│   └── usecases/         # 用例
└── presentation/
    ├── bloc/             # 状态管理
    ├── pages/            # 页面
    └── widgets/          # 组件
```

### 命名规范

```dart
// 类名：大驼峰
class UserProfile {}

// 文件名：小写+下划线
user_profile.dart

// 变量/方法：小驼峰
String userName;
void getUserData() {}

// 常量：大写+下划线
const String API_URL = 'https://api.example.com';

// 私有成员：下划线开头
String _privateField;
void _privateMethod() {}
```

### 代码注释

```dart
/// 用户认证服务
/// 
/// 提供用户登录、注册、登出等功能
class AuthService {
  /// 用户登录
  /// 
  /// [username] 用户名或邮箱
  /// [password] 密码
  /// 
  /// 返回登录成功的用户信息
  /// 
  /// 抛出 [AuthException] 当认证失败时
  Future<User> login(String username, String password) async {
    // 实现代码
  }
}
```

## 版本管理

### 版本号规则

遵循语义化版本 (Semantic Versioning)：

```
主版本号.次版本号.修订号

1.0.0 -> 1.0.1 (修复bug)
1.0.1 -> 1.1.0 (添加新功能，向后兼容)
1.1.0 -> 2.0.0 (重大变更，不向后兼容)
```

### 更新版本

1. 更新 `pubspec.yaml`：
```yaml
version: 1.1.0+2  # 版本号+构建号
```

2. 创建版本标签：
```bash
git tag -a v1.1.0 -m "Release version 1.1.0"
git push origin v1.1.0
```

3. 更新 CHANGELOG.md

## 依赖更新

### 检查过期依赖

```bash
flutter pub outdated
```

### 更新依赖

```bash
# 更新所有依赖到最新兼容版本
flutter pub upgrade

# 更新特定依赖
flutter pub upgrade package_name

# 获取最新依赖
flutter pub get
```

### 依赖审查清单

更新依赖前检查：

- [ ] 查看更新日志
- [ ] 检查破坏性变更
- [ ] 更新相关代码
- [ ] 运行测试
- [ ] 测试主要功能
- [ ] 更新文档

## 性能优化

### 定期检查项

1. **包大小**
```bash
flutter build apk --analyze-size
flutter build appbundle --analyze-size
```

2. **启动时间**
```bash
flutter run --profile --trace-startup
```

3. **内存使用**
```bash
flutter run --profile
# 使用 DevTools 分析内存
```

4. **帧率**
```bash
flutter run --profile
# 使用 Performance Overlay
```

### 优化建议

- 使用 const 构造函数
- 避免不必要的 rebuild
- 使用 ListView.builder 而非 ListView
- 图片使用合适的分辨率
- 延迟加载大型资源
- 使用缓存策略

## 问题排查

### 常见问题

#### 1. 构建失败

```bash
# 清理缓存
flutter clean
flutter pub get

# 重新生成代码
flutter pub run build_runner build --delete-conflicting-outputs
```

#### 2. 依赖冲突

```bash
# 查看依赖树
flutter pub deps

# 解决冲突
flutter pub upgrade --major-versions
```

#### 3. 平台特定问题

**Android:**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

**iOS:**
```bash
cd ios
pod deintegrate
pod install
cd ..
flutter clean
flutter pub get
```

**Web:**
```bash
flutter clean
flutter pub get
flutter build web --release
```

### 日志调试

```dart
// 开发环境启用详细日志
import 'package:flutter/foundation.dart';

if (kDebugMode) {
  print('Debug: $message');
}

// 使用 logger 包
import 'package:logger/logger.dart';

final logger = Logger();
logger.d('Debug message');
logger.i('Info message');
logger.w('Warning message');
logger.e('Error message');
```

### 性能分析

```bash
# Profile 模式运行
flutter run --profile

# 生成性能报告
flutter run --profile --trace-startup --verbose
```

## 定期维护任务

### 每周

- [ ] 检查并处理 GitHub Issues
- [ ] 审查 Pull Requests
- [ ] 更新项目文档
- [ ] 运行测试套件

### 每月

- [ ] 检查依赖更新
- [ ] 审查代码质量
- [ ] 性能分析
- [ ] 安全审计

### 每季度

- [ ] 重大版本更新
- [ ] 架构评审
- [ ] 技术债务清理
- [ ] 用户反馈整理

## 工具推荐

### 开发工具

- **IDE**: VS Code / Android Studio
- **版本控制**: Git + GitHub
- **API测试**: Postman
- **设计工具**: Figma

### Flutter工具

```bash
# 代码格式化
dart format .

# 代码分析
flutter analyze

# 测试
flutter test

# 代码生成
flutter pub run build_runner build
```

### 监控工具

- **Crashlytics**: 崩溃报告
- **Analytics**: 用户行为分析
- **Performance Monitoring**: 性能监控

## 备份策略

### 代码备份

- Git 远程仓库（GitHub/GitLab）
- 定期创建 release 分支
- 重要节点打 tag

### 数据备份

- 数据库定期备份
- 用户数据导出功能
- 配置文件版本控制

## 安全检查

### 代码安全

- [ ] 不提交敏感信息（密钥、密码）
- [ ] 使用环境变量管理配置
- [ ] 定期更新依赖修复漏洞
- [ ] 代码审查

### API安全

- [ ] 使用 HTTPS
- [ ] Token 过期机制
- [ ] 请求签名验证
- [ ] 频率限制

## 文档维护

### 必须更新的文档

- README.md - 项目介绍
- CHANGELOG.md - 版本变更
- API.md - API文档
- CONTRIBUTING.md - 贡献指南

### 文档规范

- 使用 Markdown 格式
- 保持简洁清晰
- 及时更新
- 添加示例代码

## 联系方式

- 技术负责人：[姓名]
- 邮箱：support@fabushi.com
- 项目地址：[GitHub URL]

---

**最后更新**: 2024年
