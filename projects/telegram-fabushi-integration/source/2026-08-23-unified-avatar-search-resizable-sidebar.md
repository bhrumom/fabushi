# 2026-08-23 — 统一头像、可伸缩侧栏与全局分类搜索

## 用户原始要求

基于用户提供的 6 张界面参考图，将 Fabushi 桌面 Messenger 继续收敛为单一 Grok/Fabushi 风格 UI：

1. 将当前侧边栏中的联系人、Bots、群组、频道、通话、收藏、归档、文件夹、Mini Apps、支付、设置等入口收进左下角个人头像菜单，不再常驻第二条功能导航栏。
2. 左侧会话栏支持像参考图 2/3 一样拖拽改变宽度；拖到窄宽度时只显示统一头像，右侧聊天区域自动扩大。
3. 所有身份头像，包括真人联系人、Agent/Bot、群组/频道以及 Mini App，统一使用 Fabushi `BotMark` / `fabushi-motion-v2` 身份系统，不再混用圆形文字头像、应用图标和 Agent 专属头像系统。
4. 整体采用现有 Fabushi/Grok 深色、玻璃、动态状态反馈视觉语言，但不恢复 Grok vendor 视觉 runtime 或品牌资产。
5. 点击搜索框进入独立全局搜索界面，按“聊天、频道、应用、贴文、图片、视频、下载、链接、文件、音乐、声音”分类展示结果。
6. 现有线上 Mini App / 插件市场必须融合进“应用”搜索结果，同一搜索入口即可发现、安装、更新、打开、卸载 Mini App。

## 参考关系

- 图 1：Grok Bot/FPU 深色材质、消息气泡、左侧头像 rail 的视觉质感。
- 图 2/3：左栏宽窄拖拽、窄态仅头像、右侧内容随之扩大。
- 图 4：Fabushi 现有三栏信息架构作为产品骨架。
- 图 5：需要从常驻侧栏搬入个人头像菜单的导航项。
- 图 6：全局搜索页面和分类 tab 的交互参考。

## 架构约束

- 继续使用唯一 `DesktopShellV2` / Messenger product surface。
- 继续使用现有 `MahayanaHostTransport`、Rust Messaging Core 与 Marketplace contracts，不新增第二套 runtime/state machine。
- Grok 视觉参考只用于 Fabushi 自研视觉语言；统一身份系统以当前 canonical `BotMark` / `fabushi-motion-v2` 为准。
- Mini App 继续采用线上 Marketplace 安装模型，不回退为内置应用。
