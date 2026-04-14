# App Store 审核被拒修复需求文档 (PRD)

## 核心目标
解决 App Store 拒绝原因，通过 Playwright CLI 自动化操作 App Store Connect 更新应用元数据并重新提交审核。

## 修复内容概要
1. **Guideline 3.1.2(c) - Subscriptions**: 在 App Store 描述中添加包含使用条款 (EULA) 的有效链接，或在 App Store Connect 中配置自定义 EULA。
2. **Guideline 1.2 - Safety - User Generated Content**: 将评级修改为 18+ 并在设置中启用相关的安全申明。
3. **Guideline 2.1 - Information Needed**: 在中国大陆出版物许可设置处，上传《网络出版服务许可证》扫描件。
4. **Guideline 2.3.6 - Accurate Metadata**: 在应用的年龄分级中，务必选择“包含用户生成内容 (User-Generated Content)”为“是 (Yes)”。

## 执行方案 (Implementation Plan)
自动化流程分以下步骤：
1. **浏览器启动与登录状态保存**：目前系统已利用 Playwright CLI 启动在后台（但可见的）基于 `appstore` session 的浏览器。待用户完成登录后，脚本将自动抓取凭证 `$ playwright-cli -s=appstore state-save .appstore-auth.json`。
2. **填写分级与合规信息**：
   - 导航至应用的「App 信息 (App Information)」页面。
   - 编辑**年龄分级 (Age Rating)**，选择“包含用户生成内容 (Yes)”，确保综合评级变为 18+。
   - 在「中国大陆出版的可用性 (Publication Availability in China mainland)」一栏，使用选择的《网络出版服务许可证》扫描件进行上传和填写。
3. **填写 EULA 链接**：
   - 在当前审核版本信息的 App 描述后追加 EULA 链接，或进入 EULA 特定字段进行配置。
4. **回复苹果审核人员 (可选)**：如果需要，我们将把处理好的说明附上一段操作录屏，并回复反馈。

## 遗留问题与依赖 (Dependencies needing User Input)
执行前需用户协助提供以下前置条件：
1. **《网络出版服务许可证》照片或扫描件**存放在工作区的具体「文件路径」。
2. **EULA / 用户协议 的具体直达 URL 链接**，或者是否需要创建自定义说明。
3. 用户在启动的浏览器窗口中**人工结束 Apple 登录流程**并确认。

## 执行结果记录与方案转型 (Execution Report - 2026.04)

在执行过程中遇到了以下重要转变：

### 遇到的问题
1. App 内的功能涉及“文献阅览”（对应“法流”模块），按要求在中国大陆分发必须拥有《网络出版服务许可证》。
2. 团队确认**应用并没有出版物许可证**，无法按照原计划通过 Playwright 上传证书，面临被下架国区或大幅删改代码的两难境地。

### 解决方案与代码转变
经团队决策，我们采用了“保护中国大陆区市场，彻底删除隐藏风险功能”的 **【方案 B】**：
1. **代码精简**：通过 Flutter 代码重构，不仅在底层将 `VideoFeedScreen` 彻底断出底部导航 (`main_navigation_screen.dart`)，还在个人中心 (`my_profile_screen.dart`) 里根除了含有“作品/UGC”性质的标签页，从源头上抹除了具有违规风险的所有 UI 入口。
2. **后台自动化重连**：不需要单独提供许可证，通过 playwright-cli 进入了后台审核页面。因为移除了所有用户生成模块（作品与法流动态），因此年龄限制要求 `1.2` 也同时自动得到符合（不再必须评级 18+）。
3. **EULA 配置完成**：通过注入 Javascript 代码调用 Playwright，自动向长描述区域中添加了苹果的《标准最终用户协议 (EULA)》，补齐了订阅规范的遗漏。

此时代码变更完成且已向控制台保存，等待人工确认和最后点击“提交审核”即可闭环问题。
