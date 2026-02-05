# 贡献指南

感谢您考虑为全球法布施项目做出贡献！

## 开发流程

1. **Fork项目**
2. **创建分支**: `git checkout -b feature/your-feature`
3. **开发功能**
4. **提交代码**: `git commit -m 'feat: add some feature'`
5. **推送分支**: `git push origin feature/your-feature`
6. **创建Pull Request**

## 代码规范

### 命名规范
- 文件名: `snake_case.dart`
- 类名: `PascalCase`
- 变量/方法: `camelCase`
- 常量: `UPPER_SNAKE_CASE`

### 提交信息规范
```
feat: 添加新功能
fix: 修复bug
docs: 更新文档
style: 代码格式
refactor: 重构
test: 测试
chore: 构建/工具
```

### 代码检查
提交前运行：
```bash
dart format .
flutter analyze
flutter test
```

## 架构规范

### 添加新功能模块

1. 创建模块结构：
```bash
mkdir -p lib/features/[module]/{data/{models,datasources,repositories},domain/{entities,repositories,usecases},presentation/{pages,widgets}}
```

2. 实现Clean Architecture分层：
   - **Domain层**: 实体、仓库接口、用例
   - **Data层**: 模型、数据源、仓库实现
   - **Presentation层**: 页面、组件

3. 注册依赖：
```dart
// lib/core/di/injection.dart
getIt.registerLazySingleton<YourRepository>(() => YourRepositoryImpl());
```

## 测试要求

- 新功能必须包含单元测试
- 测试覆盖率不低于80%
- 关键功能需要集成测试

## 文档要求

- 公共API必须有文档注释
- 复杂逻辑需要添加说明
- 更新相关的README和文档

## Pull Request检查清单

- [ ] 代码遵循项目规范
- [ ] 通过所有测试
- [ ] 添加必要的测试
- [ ] 更新相关文档
- [ ] 提交信息清晰明确

## 问题反馈

发现bug或有建议？请创建Issue并包含：
- 问题描述
- 复现步骤
- 预期行为
- 实际行为
- 环境信息

## 行为准则

- 尊重他人
- 建设性反馈
- 专注于代码质量
- 保持友好沟通

---

感谢您的贡献！🙏
