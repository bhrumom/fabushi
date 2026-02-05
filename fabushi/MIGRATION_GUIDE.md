# 🔄 代码迁移指南

## 概述

本指南帮助开发者从旧代码结构迁移到新的重构架构。

## 主要变化

### 1. 配置管理

#### 旧方式 ❌
```dart
// lib/config/unified_config.dart
import 'config/unified_config.dart';

UnifiedConfig.backendUrl
```

#### 新方式 ✅
```dart
// lib/core/config/app_config.dart
import 'core/config/app_config.dart';

AppConfig.backendUrl
AppConfig.appName
AppConfig.printConfigInfo()
```

### 2. 主入口文件

#### 旧方式 ❌
```dart
// 没有依赖注入
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ...
  runApp(const MyApp());
}
```

#### 新方式 ✅
```dart
// 使用依赖注入
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 初始化依赖注入
  setupDependencies();
  
  // 打印配置信息
  AppConfig.printConfigInfo();
  
  // ...
  runApp(const MyApp());
}
```

### 3. 依赖注入

#### 注册服务
```dart
// lib/core/di/injection.dart
import 'package:get_it/get_it.dart';

final getIt = GetIt.instance;

void setupDependencies() {
  // 注册单例
  getIt.registerLazySingleton<ApiClient>(() => ApiClient());
  
  // 注册工厂
  getIt.registerFactory<AuthService>(() => AuthService());
}
```

#### 使用服务
```dart
// 在代码中获取实例
final apiClient = getIt<ApiClient>();
final authService = getIt<AuthService>();
```

### 4. 目录结构

#### 旧结构 ❌
```
lib/
├── config/              # 配置文件
├── models/              # 所有模型
├── services/            # 所有服务
├── screens/             # 所有界面
└── widgets/             # 所有组件
```

#### 新结构 ✅
```
lib/
├── core/                # 核心层
│   ├── config/         # 配置管理
│   ├── constants/      # 常量定义
│   ├── di/             # 依赖注入
│   ├── errors/         # 错误处理
│   ├── network/        # 网络层
│   └── utils/          # 工具类
│
├── features/            # 功能模块（Clean Architecture）
│   ├── auth/           # 认证模块
│   │   ├── data/       # 数据层
│   │   ├── domain/     # 领域层
│   │   └── presentation/ # 表现层
│   ├── membership/     # 会员模块
│   ├── transfer/       # 传输模块
│   └── ...
│
├── shared/              # 共享组件
│   ├── widgets/        # UI组件
│   └── models/         # 共享模型
│
└── routes/              # 路由管理
```

## 迁移步骤

### 步骤1: 更新导入语句

查找并替换所有旧的导入：

```bash
# 查找使用旧配置的文件
grep -r "import 'config/unified_config.dart'" lib/

# 替换为新配置
# 手动或使用IDE的查找替换功能
```

### 步骤2: 更新配置引用

```dart
// 旧代码
UnifiedConfig.backendUrl

// 新代码
AppConfig.backendUrl
```

### 步骤3: 使用依赖注入

```dart
// 旧代码 - 直接实例化
final apiClient = ApiClient();

// 新代码 - 使用依赖注入
final apiClient = getIt<ApiClient>();
```

### 步骤4: 新功能使用新架构

创建新功能时，使用 Clean Architecture 结构：

```
features/
└── new_feature/
    ├── data/
    │   ├── models/
    │   ├── datasources/
    │   └── repositories/
    ├── domain/
    │   ├── entities/
    │   ├── repositories/
    │   └── usecases/
    └── presentation/
        ├── pages/
        └── widgets/
```

## 常见问题

### Q1: 旧代码还能用吗？
**A**: 可以！旧代码（models/, services/, screens/）暂时保留，继续正常工作。我们采用渐进式迁移。

### Q2: 必须立即迁移所有代码吗？
**A**: 不需要。建议：
- 新功能使用新架构
- 旧功能逐步重构
- 保持应用稳定

### Q3: 如何回滚？
**A**: 所有旧代码已备份到 `.old_code_backup_20251106_084400/`

```bash
# 恢复旧的main.dart
cp .old_code_backup_20251106_084400/main.dart lib/

# 恢复旧的config
cp -r .old_code_backup_20251106_084400/config lib/
```

### Q4: 依赖注入有什么好处？
**A**: 
- 更容易测试
- 更好的解耦
- 更灵活的配置
- 更清晰的依赖关系

### Q5: Clean Architecture 太复杂？
**A**: 
- 对于简单功能，可以简化
- 对于复杂功能，架构能带来长期收益
- 团队可以根据实际情况调整

## 最佳实践

### 1. 新功能开发
```dart
// ✅ 推荐：使用新架构
features/
└── my_feature/
    ├── data/
    ├── domain/
    └── presentation/
```

### 2. 共享组件
```dart
// ✅ 推荐：放在shared目录
shared/
└── widgets/
    └── my_shared_widget.dart
```

### 3. 配置管理
```dart
// ✅ 推荐：使用AppConfig
import 'core/config/app_config.dart';

final url = AppConfig.backendUrl;
```

### 4. 错误处理
```dart
// ✅ 推荐：使用统一的异常类
import 'core/errors/exceptions.dart';

throw ServerException('服务器错误');
```

### 5. 网络请求
```dart
// ✅ 推荐：使用ApiClient
import 'core/network/api_client.dart';

final client = getIt<ApiClient>();
final response = await client.get('/api/endpoint');
```

## 迁移检查清单

- [ ] 更新 main.dart 导入
- [ ] 替换配置引用（UnifiedConfig → AppConfig）
- [ ] 测试应用启动
- [ ] 测试核心功能
- [ ] 更新团队文档
- [ ] 培训团队成员
- [ ] 制定迁移计划
- [ ] 逐步迁移旧代码

## 参考文档

- `CLEANUP_COMPLETE.md` - 清理完成报告
- `REFACTOR_100_COMPLETE.md` - 重构完成报告
- `MAINTENANCE_GUIDE.md` - 维护指南
- `README_FINAL.md` - 项目说明

## 获取帮助

如有问题，请：
1. 查看相关文档
2. 查看代码示例
3. 联系团队成员

---

**最后更新**: 2024-11-06  
**版本**: 1.0.1

**愿此功德回向法界众生，同证菩提！** 🙏
