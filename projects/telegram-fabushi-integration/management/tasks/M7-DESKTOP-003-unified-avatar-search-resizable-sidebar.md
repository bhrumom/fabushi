# M7-DESKTOP-003 — Unified avatar, resizable sidebar and global categorized search

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M7-DESKTOP-003`
- **Stage**: `M7 Bot/Agent 统一联系人体系`
- **Status**: `IMPLEMENTED`
- **Started**: `2026-08-23`
- **Updated**: `2026-08-23`
- **Branch**: `feat/tfi-m7-unified-search-resizable-sidebar`
- **Primary PR**: `#2057`

## Objective

按照用户 2026-08-23 提供的 6 张 UI 参考图，继续把桌面 Messenger 收敛成一套 Fabushi/Grok 风格产品界面：移除常驻功能 rail，把导航收进个人头像菜单；支持左侧会话栏拖拽到头像-only 窄态；所有身份和 Mini App 共用 BotMark；点击搜索进入分类全局搜索，并把线上 Mini App Marketplace 融合进应用搜索结果。

## Source requirements

- `../../source/2026-08-23-unified-avatar-search-resizable-sidebar.md`
- `../../source/完整telegram融合进fabushi.txt`
- `../../docs/07-客户端架构与交互.md`
- `../wbs/M7.md`
- `M7-DESKTOP-001`：单一 Messenger Shell 与 Motion v2 identity。
- `M7-DESKTOP-002`：Mini App canonical routing 与 composer viewport regression guard。

## In scope

- 删除常驻 `navRail`，功能入口进入左下角个人 BotMark 菜单。
- 会话栏宽度可拖拽并持久化；窄态隐藏标题/摘要等，只保留 BotMark 身份图标。
- 真人、Agent/Bot、群组、频道、收藏/系统 peer 与 Mini App 全部使用统一 `BotMark` identity primitive。
- 新增全局搜索 mode 与分类 tabs：聊天、频道、应用、贴文、图片、视频、下载、链接、文件、音乐、声音。
- “应用”分类直接复用在线 Marketplace 数据与 install/update/open/uninstall actions。
- 保持现有 Fabushi/Grok dark-glass material，并强化 sidebar/search 的统一视觉层级。
- 增加 Electron Playwright 契约覆盖导航菜单、sidebar collapse、全局搜索与应用 marketplace 搜索。

## Out of scope

- 不新增第二套聊天、Agent、Host、Marketplace runtime。
- 不恢复 Grok vendor runtime/品牌资产。
- 不改写 Rust Messaging Core。
- 不把 Mini App 重新打包进主程序。
- 不在本地执行 Electron build、Playwright、Cargo 或其他重型测试。

## Acceptance criteria

1. Electron authenticated surface 不再渲染常驻联系人/Bots/收藏等功能 rail；这些入口可由左下角个人头像菜单打开。
2. sidebar 可由 pointer drag 在宽/窄范围调整；窄态只显示身份头像，workspace 明显扩展；宽度刷新后保持。
3. 所有 peer identity 和 Marketplace Mini App card/row 使用 `BotMark`，不存在 Agent-only avatar split。
4. 搜索框 focus/click 打开 global search surface，并可在 11 个分类 tab 间切换。
5. “应用”分类使用同一 `marketplaceApps` 数据，可搜索并执行安装/更新/打开/卸载。
6. 聊天/频道分类基于当前 canonical peer 数据；贴文/链接/媒体分类基于当前已加载 message/media 数据，不伪造后端索引结果。
7. Playwright 覆盖 personal navigation、sidebar resize/collapse、search tabs 与 Marketplace app result。
8. GitHub Actions relevant desktop/Messaging/portfolio gates 通过，protected merge 完成，并在 canonical `main` 回读确认后才提升为 `TESTED`。

## Verification plan

- 本地仅做源码/diff/静态文本检查，不构建、不运行应用或 E2E。
- GitHub Actions 运行 Electron typecheck/renderer、Messenger Playwright、Messaging Product Gate 与 Project portfolio governance（按 workflow path classifier 实际触发为准）。
- protected merge + canonical-main readback。

## Risks / blockers

- 现有部分媒体分类只对已加载会话消息有数据，完整跨会话索引仍属于 M12 search domain；本任务只提供真实可用 UI 与当前数据结果，不制造虚假全库搜索。
- 用户本机安装版本不会随源码合并自动升级；最终视觉验收仍需安装 canonical main 产出的最新正式包。

## Implementation summary

- authenticated Messenger 已删除常驻 `navRail`；所有原 rail 功能进入左下角个人 `BotMark` 菜单。
- sidebar 新增 pointer drag、宽度 localStorage 持久化与 <=112px avatar-only collapse；双击 separator 可在 88/330px 快速切换。
- peer list、chat header、empty/profile、Story、forward/new-dialog/call 与 Mini App marketplace identity 全部使用 `BotMark`。
- 搜索框进入独立 `GlobalSearchWorkspace`，实现 11 个分类 tab；聊天/频道使用 canonical peer，贴文/媒体使用当前真实已加载 message 数据。
- 应用 tab 直接复用 `marketplaceApps`、installed state 与 install/update/open/uninstall callbacks，不新增第二套插件市场。
- Messenger/Smoke/Surfaces E2E 已切换到个人导航模型，并新增 sidebar collapse、global search tabs、应用搜索打开 Mini App 的回归覆盖。
- 本地仅执行 `git diff --check` 与源码 marker inspection，均通过；按仓库策略未执行本地重型测试。

## Evidence

`../../evidence/M7-DESKTOP-003/README.md`.

## Next action

提交 branch/PR，等待 GitHub current-head relevant checks；失败则按 CI 证据修复，全部通过后 protected merge，并回读 canonical `main` 后再提升为 `TESTED`。
