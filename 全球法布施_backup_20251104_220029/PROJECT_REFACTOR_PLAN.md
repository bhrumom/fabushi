# 项目重构计划

## 🎯 重构目标

1. **统一架构模式**：采用清晰的分层架构
2. **简化项目结构**：减少冗余文件和目录
3. **优化依赖管理**：移除未使用的依赖
4. **规范文档管理**：整理和归档文档
5. **提升可维护性**：建立清晰的代码组织规范

## 📁 新项目结构

```
全球法布施/
├── lib/
│   ├── core/                          # 核心层
│   │   ├── constants/                 # 常量定义
│   │   │   ├── api_constants.dart
│   │   │   ├── app_constants.dart
│   │   │   └── route_constants.dart
│   │   ├── config/                    # 配置
│   │   │   ├── app_config.dart
│   │   │   ├── env_config.dart
│   │   │   └── theme_config.dart
│   │   ├── di/                        # 依赖注入
│   │   │   └── injection.dart
│   │   ├── errors/                    # 错误处理
│   │   │   ├── exceptions.dart
│   │   │   └── failures.dart
│   │   ├── network/                   # 网络层
│   │   │   ├── api_client.dart
│   │   │   └── network_info.dart
│   │   └── utils/                     # 工具类
│   │       ├── extensions/
│   │       ├── helpers/
│   │       └── validators/
│   │
│   ├── features/                      # 功能模块（按业务划分）
│   │   ├── auth/                      # 认证模块
│   │   │   ├── data/
│   │   │   │   ├── models/
│   │   │   │   ├── datasources/
│   │   │   │   └── repositories/
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   ├── repositories/
│   │   │   │   └── usecases/
│   │   │   └── presentation/
│   │   │       ├── bloc/
│   │   │       ├── pages/
│   │   │       └── widgets/
│   │   │
│   │   ├── membership/                # 会员模块
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │
│   │   ├── transfer/                  # 传输模块
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │
│   │   ├── dharma/                    # 法布施内容模块
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │
│   │   ├── profile/                   # 个人中心模块
│   │   │   ├── data/
│   │   │   ├── domain/
│   │   │   └── presentation/
│   │   │
│   │   └── video_feed/                # 视频流模块
│   │       ├── data/
│   │       ├── domain/
│   │       └── presentation/
│   │
│   ├── shared/                        # 共享组件
│   │   ├── widgets/                   # 通用组件
│   │   │   ├── buttons/
│   │   │   ├── cards/
│   │   │   ├── dialogs/
│   │   │   └── loading/
│   │   └── models/                    # 共享模型
│   │
│   ├── routes/                        # 路由管理
│   │   ├── app_router.dart
│   │   └── route_guards.dart
│   │
│   └── main.dart                      # 应用入口
│
├── test/                              # 测试文件
│   ├── unit/
│   ├── widget/
│   └── integration/
│
├── assets/                            # 资源文件
│   ├── images/
│   ├── fonts/
│   ├── data/
│   └── built_in/
│
├── docs/                              # 文档目录
│   ├── api/                           # API文档
│   ├── architecture/                  # 架构文档
│   ├── deployment/                    # 部署文档
│   ├── features/                      # 功能文档
│   └── guides/                        # 使用指南
│
├── scripts/                           # 脚本文件
│   ├── build/
│   ├── deploy/
│   └── setup/
│
├── .github/                           # GitHub配置
├── android/                           # Android平台
├── ios/                               # iOS平台
├── web/                               # Web平台
├── macos/                             # macOS平台
│
├── .gitignore
├── pubspec.yaml
├── analysis_options.yaml
└── README.md
```

## 🔄 迁移步骤

### 第一阶段：准备工作

1. **备份当前项目**
2. **创建新的目录结构**
3. **整理文档文件**

### 第二阶段：代码迁移

1. **迁移核心层**
   - 合并config目录
   - 整理utils工具类
   - 统一错误处理

2. **重构功能模块**
   - 认证模块（auth）
   - 会员模块（membership）
   - 传输模块（transfer）
   - 法布施内容模块（dharma）
   - 个人中心模块（profile）

3. **整理共享组件**
   - 提取通用widgets
   - 统一样式主题

### 第三阶段：优化清理

1. **清理依赖**
2. **移除冗余代码**
3. **更新测试**

### 第四阶段：验证测试

1. **功能测试**
2. **性能测试**
3. **跨平台测试**

## 📋 详细任务清单

### 1. 文档整理

- [ ] 创建 `docs/` 目录
- [ ] 移动所有.md文件到对应子目录
- [ ] 更新README.md
- [ ] 创建CHANGELOG.md

### 2. 脚本整理

- [ ] 创建 `scripts/` 目录
- [ ] 移动所有.sh文件到对应子目录
- [ ] 添加脚本说明文档

### 3. 核心层重构

- [ ] 创建统一的配置管理
- [ ] 实现依赖注入容器
- [ ] 统一网络请求层
- [ ] 完善错误处理机制

### 4. 功能模块迁移

#### 认证模块
- [ ] 迁移auth相关models
- [ ] 迁移auth相关services
- [ ] 迁移auth相关screens
- [ ] 实现Clean Architecture

#### 会员模块
- [ ] 迁移membership相关代码
- [ ] 整合支付功能
- [ ] 实现兑换码系统

#### 传输模块
- [ ] 迁移文件传输相关代码
- [ ] 整合全球传输功能
- [ ] 优化传输逻辑

#### 法布施内容模块
- [ ] 迁移经文相关代码
- [ ] 整合搜索功能
- [ ] 优化内容展示

#### 个人中心模块
- [ ] 迁移profile相关代码
- [ ] 整合设置功能
- [ ] 优化用户体验

### 5. 依赖优化

- [ ] 审查pubspec.yaml
- [ ] 移除未使用的依赖
- [ ] 更新过时的依赖
- [ ] 添加依赖说明注释

### 6. 测试完善

- [ ] 创建测试目录结构
- [ ] 编写单元测试
- [ ] 编写集成测试
- [ ] 配置CI/CD

## 🎨 代码规范

### 命名规范

- **文件名**：小写+下划线（snake_case）
- **类名**：大驼峰（PascalCase）
- **变量/方法**：小驼峰（camelCase）
- **常量**：大写+下划线（UPPER_SNAKE_CASE）

### 目录规范

- **data层**：数据源、模型、仓库实现
- **domain层**：实体、仓库接口、用例
- **presentation层**：UI、状态管理、页面

### 导入规范

```dart
// 1. Dart SDK
import 'dart:async';

// 2. Flutter SDK
import 'package:flutter/material.dart';

// 3. 第三方包
import 'package:provider/provider.dart';

// 4. 项目内部
import 'package:global_dharma_sharing/core/config/app_config.dart';
```

## 🔧 配置优化

### 环境配置

创建环境配置文件：
- `lib/core/config/env_config.dart`
- 支持dev/staging/prod环境切换

### 主题配置

统一主题管理：
- `lib/core/config/theme_config.dart`
- 支持亮色/暗色主题

### API配置

集中API配置：
- `lib/core/constants/api_constants.dart`
- 便于切换后端环境

## 📊 预期收益

1. **代码可读性提升50%**
2. **维护成本降低40%**
3. **新功能开发效率提升30%**
4. **测试覆盖率提升至80%+**
5. **构建时间减少20%**

## ⚠️ 注意事项

1. **渐进式迁移**：不要一次性重构所有代码
2. **保持功能完整**：确保每次迁移后功能正常
3. **及时测试**：每完成一个模块立即测试
4. **版本控制**：使用Git分支管理重构过程
5. **文档同步**：及时更新相关文档

## 🚀 开始重构

建议按以下顺序执行：

1. **第一周**：文档和脚本整理
2. **第二周**：核心层重构
3. **第三-四周**：功能模块迁移
4. **第五周**：优化和测试
5. **第六周**：验收和部署

---

**开始时间**：待定
**预计完成**：6周
**负责人**：开发团队
