# 更新日志

## [1.2.15] - 2026-09-04

### Mahayana 智能对话流程修复
- 将 Mahayana/DeepSeek 的 Responses 链路接入真实 SSE 增量输出，前端按独立消息气泡收敛每一条公开回复，并保留模型推理、工具调用和完成状态。
- 增加面向多步骤任务的公开消息边界；`send_message` 只显示真实里程碑或最终回复，不再把多条回复覆盖成一条或伪造进度。
- 在退出登录、切换账号和生产消息边界清理运行时会话、凭据解析和持久化状态，避免历史消息跨账号泄漏。
- 桌面、Android 与 iOS 产品版本统一提升到 `1.2.15`，Android `versionCode` 与 iOS `CURRENT_PROJECT_VERSION` 统一提升到 `21`。

## [1.2.14] - 2026-09-03

### 全新正式版本发布
- 以当前 canonical `main` 为唯一来源启动全新 `1.2.14` 正式发布列车；当前开放 PR #2287 已审阅，但仍为 Draft，且其 iOS marketplace live-official 安装门禁缺少兼容 `global-dharma` artifact，因此按仓库验收约束继续隔离，不提前并入正式主线。
- 桌面、Android 与 iOS 产品版本统一提升到 `1.2.14`，Android `versionCode` 与 iOS `CURRENT_PROJECT_VERSION` 统一提升到 `20`，确保所有正式渠道使用全新且严格递增的发布身份。
- 继续使用仓库现有 `[full-platform-release]` exact-main GitHub Actions 完成 macOS/Windows/Linux 桌面产物、Android/iOS、Apple/Google Play 渠道、生产部署、不可变 GitHub Release、全新安装与上一正式版本升级验收；重型构建和测试仅在 GitHub Actions 执行。

---

## [1.2.13] - 2026-09-03

### 生产依赖安全修复与全平台正式重发
- 将 `chatgpt-vps-control` 生产依赖树中的 `fast-uri` 从受当前高危主机混淆/SSRF 公告影响的 `3.1.5` 更新到已修复的 `3.1.6`，并要求 GitHub Actions 重新执行 `npm audit --omit=dev` 安全门禁。
- 桌面、Android 与 iOS 产品版本统一提升到 `1.2.13`，Android `versionCode` 与 iOS `CURRENT_PROJECT_VERSION` 统一提升到 `19`，确保所有正式渠道使用全新且严格递增的发布身份。
- 本轮已审阅当前开放 PR #2287；该 RustDesk 融合开发线仍由自身 WBS 标记为未完成，继续隔离在专用分支，不提前并入正式发布主线。正式发布仅以 canonical `main` 为来源。
- 继续使用仓库现有 exact-main GitHub Actions 完成桌面 macOS/Windows/Linux、Android/iOS、Apple/Google Play 渠道、生产部署、不可变 GitHub Release、全新安装与上一正式版本升级验收；重型构建和测试仅在 GitHub Actions 执行。

---

## [1.2.12] - 2026-09-02

### 生产依赖安全修复与正式重发
- 将 `chatgpt-vps-control` 生产依赖树中的 `qs` 从受 GHSA-x5fp-wj9c-mxmx / GHSA-4mjr-xmp4-gh2g 影响的 `6.15.2` 更新到 `6.16.0`；`npm audit --omit=dev` 重新达到 0 vulnerabilities。
- 桌面、Android 与 iOS 产品版本统一提升到 `1.2.12`，Android `versionCode` 与 iOS `CURRENT_PROJECT_VERSION` 统一提升到 `18`，避免复用已经开始验证的 1.2.11 发布身份。
- 继续使用修复后的 check-runs 全量分页门禁，从受保护 `main` 重新执行桌面 macOS/Windows/Linux、Android/iOS、商店交付、生产部署、不可变 GitHub Release、全新安装与上一正式版本升级验收。

---

## [1.2.11] - 2026-09-02

### 正式发布门禁分页修复
- 修复 `post-main-delivery` 在同一主线提交拥有超过 100 个 check-runs 时只读取第一页、从而漏掉已成功的 `Native mobile result` / `Native iOS` 并错误等待的问题；现通过 GitHub API 分页聚合全部检查后再执行 exact-SHA 门禁。
- 将桌面、Android 与 iOS 产品版本统一提升到 `1.2.11`，Android `versionCode` 与 iOS `CURRENT_PROJECT_VERSION` 统一提升到 `17`，避免复用已经启动外部交付的 `1.2.10` 发布身份。
- 重新从修复后的受保护 `main` 执行桌面 macOS/Windows/Linux、Android/iOS 商店交付、生产部署、不可变 GitHub Release、安装及上一正式版本升级验证；重型构建和测试继续仅由 GitHub Actions 执行。

---

## [1.2.10] - 2026-09-02

### 全新正式版本发布
- 以受保护 `main@cf41861f7f274af792dc451d62a4a1d0052ebff9` 为唯一发布源，纳入当前主线最新的 iOS 浏览器认证回跳登录门禁修复，并在审阅当前全部开放 PR 后启动新的正式发布列车。
- 桌面、Android 与 iOS 产品版本统一提升到 `1.2.10`，Android `versionCode` 与 iOS `CURRENT_PROJECT_VERSION` 统一提升到 `16`，不复用已经发布且不可变的 `1.2.9` 身份。
- 本版本继续通过仓库现有 exact-main GitHub Actions 执行桌面 macOS/Windows/Linux 打包、Android/iOS 商店交付、生产部署、不可变 GitHub Release、安装与上一正式版本升级验证；重型构建和测试仅在 GitHub Actions 执行。

---

## [1.2.9] - 2026-09-02

### 全新正式版本发布
- 从受保护 `main@868122cfa8ed2490053af5ed99117d93349ec022` 切出新的正式发布列车，完成本轮开放 PR 审阅后，将产品版本统一提升为 `1.2.9`。
- Android `versionCode` 与 iOS `CURRENT_PROJECT_VERSION` 统一提升到 `15`，保证商店与客户端升级身份严格递增，不复用不可变的 `1.2.8` 发布身份。
- 继续复用仓库现有 exact-main GitHub Actions、桌面签名/公证、移动商店交付、生产部署、不可变 GitHub Release 与安装/升级验证链路；重型构建和测试仅在 GitHub Actions 执行。

---

## [1.2.8] - 2026-09-02

### 全新正式版本发布
- 从已经完成桌面、Android、iOS、Apple Store、Google Play 与生产部署验收的受保护 `main` 重新切出正式发布，统一桌面与原生移动端产品版本为 `1.2.8`。
- Android `versionCode` 与 iOS `CURRENT_PROJECT_VERSION` 统一提升到 `14`，确保商店与客户端升级比较严格单调递增，不复用已有的 `1.2.7` 发布身份。
- 继续复用已验证的 exact-main 正式商店编排器、签名/公证、模拟用户 E2E、不可变 GitHub Release、生产部署与安装/升级验证链路；所有重型构建和测试仍只在 GitHub Actions 执行。

---

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
