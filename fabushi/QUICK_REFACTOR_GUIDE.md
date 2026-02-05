# 快速重构指南

## 🚀 立即开始

### 步骤1: 执行自动重构脚本

```bash
# 给脚本执行权限（如果还没有）
chmod +x refactor_project.sh

# 执行重构
./refactor_project.sh
```

这个脚本会自动：
- ✅ 创建项目备份
- ✅ 创建新目录结构
- ✅ 整理文档到 `docs/` 目录
- ✅ 整理脚本到 `scripts/` 目录
- ✅ 清理临时文件
- ✅ 生成重构报告

### 步骤2: 更新依赖配置

```bash
# 备份当前配置
cp pubspec.yaml pubspec.yaml.backup

# 使用优化后的配置
cp pubspec_optimized.yaml pubspec.yaml

# 更新依赖
flutter pub get
```

### 步骤3: 验证应用运行

```bash
# 运行应用
flutter run

# 或运行Web版本
flutter run -d chrome
```

## 📁 重构后的目录结构

```
全球法布施/
├── docs/              # 📚 所有文档（已整理）
│   ├── api/          # API文档
│   ├── architecture/ # 架构文档
│   ├── deployment/   # 部署文档
│   ├── features/     # 功能文档
│   └── guides/       # 使用指南
│
├── scripts/           # 🔧 所有脚本（已整理）
│   ├── build/        # 构建脚本
│   ├── deploy/       # 部署脚本
│   ├── setup/        # 设置脚本
│   └── utils/        # 工具脚本
│
├── lib/               # 💻 源代码
│   ├── core/         # 核心层（新增）
│   │   ├── constants/
│   │   ├── config/
│   │   ├── di/
│   │   ├── errors/
│   │   ├── network/
│   │   └── utils/
│   ├── features/     # 功能模块
│   ├── shared/       # 共享组件
│   └── routes/       # 路由管理
│
├── test/              # 🧪 测试文件
│   ├── unit/
│   ├── widget/
│   └── integration/
│
└── assets/            # 🎨 资源文件
```

## 🎯 下一步重构任务

### 优先级1: 核心层重构（1-2天）

1. **统一配置管理**
```bash
# 使用模板创建配置文件
cp lib/core/config/app_config_template.dart lib/core/config/app_config.dart
cp lib/core/constants/api_constants_template.dart lib/core/constants/api_constants.dart
```

2. **整合现有配置**
- 合并 `lib/config/` 下的配置到 `lib/core/config/`
- 删除旧的配置文件

### 优先级2: 功能模块重构（3-5天）

按以下顺序重构各功能模块：

#### 1. 认证模块
```bash
mkdir -p lib/features/auth/{data/{models,datasources,repositories},domain/{entities,repositories,usecases},presentation/{bloc,pages,widgets}}
```

迁移文件：
- `lib/models/auth_model.dart` → `lib/features/auth/data/models/`
- `lib/services/auth_service.dart` → `lib/features/auth/data/datasources/`
- `lib/screens/login_screen.dart` → `lib/features/auth/presentation/pages/`
- `lib/screens/register_screen.dart` → `lib/features/auth/presentation/pages/`

#### 2. 会员模块
```bash
mkdir -p lib/features/membership/{data,domain,presentation}/{models,datasources,repositories,entities,usecases,bloc,pages,widgets}
```

#### 3. 传输模块
```bash
mkdir -p lib/features/transfer/{data,domain,presentation}
```

#### 4. 其他模块
- dharma（法布施内容）
- profile（个人中心）
- video_feed（视频流）

### 优先级3: 共享组件整理（1-2天）

```bash
mkdir -p lib/shared/widgets/{buttons,cards,dialogs,loading}
```

迁移通用组件：
- `lib/widgets/common_widgets.dart` → 拆分到对应子目录
- 提取可复用的组件

## 🔄 渐进式迁移策略

### 方案A: 模块化迁移（推荐）

每次迁移一个完整模块：

1. 创建新模块结构
2. 复制相关文件到新位置
3. 更新导入路径
4. 测试功能正常
5. 删除旧文件
6. 提交代码

### 方案B: 并行开发

保留旧代码，新功能使用新架构：

1. 新功能直接在新结构中开发
2. 旧功能逐步迁移
3. 最终完全切换到新架构

## 📝 代码迁移示例

### 迁移前
```dart
// lib/screens/login_screen.dart
import 'package:global_dharma_sharing/services/auth_service.dart';
import 'package:global_dharma_sharing/models/auth_model.dart';
```

### 迁移后
```dart
// lib/features/auth/presentation/pages/login_page.dart
import 'package:global_dharma_sharing/features/auth/data/datasources/auth_remote_datasource.dart';
import 'package:global_dharma_sharing/features/auth/domain/entities/user.dart';
```

## ✅ 验证清单

每完成一个模块迁移后检查：

- [ ] 所有导入路径正确
- [ ] 功能测试通过
- [ ] 无编译错误
- [ ] 无运行时错误
- [ ] 代码格式化 `dart format .`
- [ ] 代码分析通过 `flutter analyze`
- [ ] 提交代码并推送

## 🛠️ 常用命令

```bash
# 格式化代码
dart format .

# 分析代码
flutter analyze

# 运行测试
flutter test

# 清理缓存
flutter clean && flutter pub get

# 生成代码
flutter pub run build_runner build --delete-conflicting-outputs

# 查看依赖树
flutter pub deps
```

## 📊 进度跟踪

创建一个进度跟踪表：

| 模块 | 状态 | 负责人 | 完成日期 |
|------|------|--------|----------|
| 文档整理 | ✅ 完成 | - | - |
| 脚本整理 | ✅ 完成 | - | - |
| 核心层 | ⏳ 进行中 | - | - |
| 认证模块 | 📋 待开始 | - | - |
| 会员模块 | 📋 待开始 | - | - |
| 传输模块 | 📋 待开始 | - | - |
| 法布施模块 | 📋 待开始 | - | - |
| 个人中心 | 📋 待开始 | - | - |
| 视频流 | 📋 待开始 | - | - |

## ⚠️ 注意事项

1. **备份重要**：重构前已自动创建备份，如需回滚可使用备份
2. **小步快跑**：每次只迁移一个模块，确保稳定
3. **及时测试**：每次迁移后立即测试
4. **版本控制**：频繁提交，便于回滚
5. **文档同步**：更新相关文档

## 🆘 遇到问题？

### 问题1: 导入路径错误

**解决方案**：使用IDE的重构功能批量更新导入路径

### 问题2: 功能异常

**解决方案**：
1. 检查文件是否完整迁移
2. 检查依赖注入是否正确
3. 查看错误日志定位问题

### 问题3: 构建失败

**解决方案**：
```bash
flutter clean
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

## 📚 参考文档

- [PROJECT_REFACTOR_PLAN.md](PROJECT_REFACTOR_PLAN.md) - 完整重构计划
- [MAINTENANCE_GUIDE.md](MAINTENANCE_GUIDE.md) - 维护指南
- [README.md](README.md) - 项目说明

---

**开始重构**: `./refactor_project.sh`
**查看报告**: `cat REFACTOR_REPORT.md`
