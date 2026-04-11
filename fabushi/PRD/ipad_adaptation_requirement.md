# iPad 运行与适配需求文档 (PRD)

## 1. 目标
确保“全球法布施”应用能够完美运行在 iPad 上，充分利用大屏幕优势，并满足 App Store 关于 iPad 应用的审核要求（如多任务支持、响应式布局）。

## 2. 当前状态分析
- **硬件支持**：Xcode 已勾选 iPad 支持（`TARGETED_DEVICE_FAMILY = "1,2"`）。
- **旋转支持**：`Info.plist` 已配置 iPad 四向旋转。
- **UI 布局**：目前大部分页面采用固定比例或简单的 `Column/Row` 布局，在 iPad 上可能会出现“拉伸感”。

## 3. 功能需求

### 3.1 技术配置 (Deployment)
- [x] 确认 Xcode 工程支持 iPad。
- [x] 确认 `Info.plist` 包含 `UISupportedInterfaceOrientations~ipad`。
- [ ] **确认多任务支持**：iPad 应用必须支持多任务处理（Split View 和 Slide Over），除非有特殊理由且配置了 `UIRequiresFullScreen`。

### 3.2 UI 响应式适配 (Responsive UI)
- **适配方案**：在宽屏（如 iPad 或桌面端）下，UI 应能从单列布局切换为多列布局或居中显示。
- **关键页面**：
  - **登录页**：在大屏下应居中显示固定宽度的卡片，而非横向拉满。
  - **3D 佛堂**：在大屏下应保持佛像比例，并自动调整相机视角（FOV）。
  - **设置页**：在大屏下可以考虑分栏显示（左侧列表，右侧详情）。

### 3.3 性能优化
- **3D 渲染**：由于 iPad 分辨率较高，需确保 `flutter_scene` 在 Impeller 开启的情况下性能稳定。

## 4. 验收标准
1. 应用可以在 iPad 模拟器或真机上成功启动。
2. 应用在旋转屏幕时布局不会崩溃或错位。
3. 应用支持分屏拖拽而不断掉渲染。
4. UI 在 iPad 上看起来像是一套专门设计的布局，而非 iPhone 的放大版。
