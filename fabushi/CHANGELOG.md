# 更新日志

## [1.2.7] - 2026-09-02

### 正式发布渠道闭环
- 将桌面、Android、iOS 正式版本统一提升到 `1.2.7`，Android/iOS repository build identity 提升到 `13`，从新的受保护 `main` exact SHA 重新执行全平台正式发布。
- 新增正式发布渠道编排器：仅在 exact-main Native mobile quality gate 成功且提交带 `[full-platform-release]` 标记时，使用仓库 `GITHUB_TOKEN` 通过 `workflow_dispatch` 调用现有 Apple Store 与 Google Play 交付工作流，不复制签名、构建或上传实现。
- Google Play GitHub 证据使用独立 `google-play-v<version>-<SHA>` 标签，避免与其他 Android Release 标签争用不可变发布名。
- 保留所有现有 exact-SHA release gate、签名、公证、模拟用户 E2E、不可变 Release 与生产部署要求，不用本地重型构建替代 GitHub Actions。

---

## [1.2.6] - 2026-09-02

### 正式发布控制面修复
- 修复全平台正式 Release 控制面错误强制要求 Linux 独立 `AppImage.blockmap` 的问题；electron-builder 的 AppImage 差分块图嵌入 AppImage 本体，不会生成该独立公开资产。
- 保留 Linux `AppImage`、`deb` 与 `latest-linux.yml`，并继续严格要求 macOS/Windows updater 元数据、Android APK/AAB、iOS IPA、发布清单和 SHA256 校验。
- 统一桌面、Android、iOS 正式版本为 `1.2.6`，Android/iOS 构建号提升至 `12`，从新的受保护主线 exact SHA 重新执行完整全平台发布。

---

## [1.2.5] - 2026-09-02

### 发布门禁修复
- 修复原生全平台正式发布工作流中的过期检查名称，改为验证当前主线实际存在且成功的 `Canonical architecture guardrails` 与 `Resolve Worker source and deployment impact` 门禁。
- 统一桌面、Android、iOS 正式版本为 `1.2.5`，Android/iOS 构建号提升至 `11`，避免复用已冻结的 `1.2.4` 发布源。
- 保留 1.2.4 安装升级 E2E 修复，并要求最终 Release 继续从受保护主线的 exact SHA 构建。

---

## [1.2.4] - 2026-09-02

### 发布与升级验证
- 修复 macOS 正式 Release 升级 E2E 中 Playwright 依赖解析路径，确保旧版本客户端能够真实执行新版本发现、点击更新、下载、安装与重启验证。
- 统一桌面、Android、iOS 正式版本为 `1.2.4`，Android/iOS 构建号提升至 `10`。
- 继续以 exact-main SHA、签名/公证产物、GitHub Release、商店投递与安装升级证据作为正式发布验收标准。

---

## [1.0.1] - 2024-11-06

### 代码清理 🧹

#### 移除
- ✅ 移除 `lib/main_refactored.dart`（已合并到main.dart）
- ✅ 移除 `lib/config/` 目录（已迁移到core/config/）
- ✅ 移除重复文档（README_NEW.md, REFACTOR_STATUS.md, REFACTOR_REPORT.md）

#### 更新
- ✅ 更新 `lib/main.dart` 为重构后版本
  - 集成依赖注入
  - 使用 AppConfig 统一配置
  - 优化代码结构

#### 备份
- ✅ 创建备份目录 `.old_code_backup_20251106_084400/`
- ✅ 所有移除的代码已安全备份

#### 文档
- ✅ 新增 `CLEANUP_COMPLETE.md` - 清理完成报告

### 改进
- 项目结构更清晰
- 配置管理更统一
- 代码维护更简单
- 文档更精简

---

## [1.0.0] - 2024-11-04

### 重构完成 🎉

#### 新增
- ✅ Clean Architecture架构实现
- ✅ 核心层完整实现（配置、网络、错误处理、依赖注入）
- ✅ 认证模块完整重构
- ✅ 会员、传输、法布施、个人中心模块基础结构
- ✅ 共享组件库（按钮、卡片、对话框、加载）
- ✅ 工具类库（验证器、格式化、日期处理）
- ✅ 路由管理系统
- ✅ 测试框架建立
- ✅ 完整文档体系

#### 改进
- ✅ 文档整理到 docs/ 目录（60+文件）
- ✅ 脚本整理到 scripts/ 目录（30+文件）
- ✅ 依赖优化（50+ → 45个包）
- ✅ 代码格式化和规范化
- ✅ 项目结构清晰化

#### 技术债务清理
- ✅ 移除临时测试文件
- ✅ 统一配置管理
- ✅ 统一错误处理
- ✅ 统一网络请求

### 架构变更

#### 之前
```
lib/
├── models/
├── services/
├── screens/
├── widgets/
└── config/
```

#### 之后
```
lib/
├── core/           # 核心层
├── features/       # 功能模块（Clean Architecture）
├── shared/         # 共享组件
└── routes/         # 路由管理
```

### 迁移指南

查看以下文档了解如何使用重构后的代码：
- `REFACTOR_COMPLETE.md` - 完整重构报告
- `QUICK_REFACTOR_GUIDE.md` - 快速指南
- `MAINTENANCE_GUIDE.md` - 维护指南

### 备份

原始代码已备份到: `../全球法布施_backup_20251104_220029`

---

## 未来计划

### v1.1.0
- [ ] 完善所有模块的业务逻辑实现
- [ ] 增加单元测试覆盖率到80%+
- [ ] 性能优化
- [ ] 国际化支持

### v1.2.0
- [ ] 离线模式支持
- [ ] 推送通知
- [ ] 社交分享功能
- [ ] 更多支付方式

---

**维护者**: 开发团队
**最后更新**: 2024-11-04
