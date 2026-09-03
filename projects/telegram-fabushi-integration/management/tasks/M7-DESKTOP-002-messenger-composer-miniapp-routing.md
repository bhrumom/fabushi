# M7-DESKTOP-002 — Messenger composer visibility and Mini App routing repair

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M7-DESKTOP-002`
- **Stage**: `M7 Bot/Agent 统一联系人体系`
- **Status**: `TESTING`
- **Started**: `2026-08-23`
- **Updated**: `2026-08-23`
- **Branch**: `fix/tfi-m7-messenger-composer-miniapp-routing`
- **Primary PR**: `#2053`

## Objective

修复统一 Messenger 中两个用户可见回归：

1. `Bot Father` 等 Mini App 会话被错误送入普通 Agent conversation backend，产生 `plugin not found` 顶部错误横幅；
2. 联系人会话底部 composer/input 在实际桌面窗口中被布局挤出可视区域。

修复必须保留单一 Messenger Shell、单一 Host/消息产品层，不新增第二套聊天 UI 或第二套运行时。

## Source requirements

- `../../source/2026-08-23-messenger-composer-miniapp-regression.md`
- `../../source/完整telegram融合进fabushi.txt`
- `../wbs/M7.md`：真人、Bot、Agent 使用同一消息产品层，UI 不再分裂。
- 用户 2026-08-23 截图与明确要求：修复顶部错误，并恢复每个联系人会话的消息输入框。

## In scope

- 明确区分普通 conversation 与 `miniapp` conversation 的桌面路由。
- Mini App peer 不得调用普通 `conversation.open`/Agent backend；使用现有 `miniapp.open` Host 能力。
- 修正 Messenger flex/grid 收缩约束，保证 composer 固定保留在聊天区可视底部。
- 增加 Electron Playwright 回归断言：composer 不仅 DOM 存在，而且边界位于 viewport 内；Mini App peer 不走错误的普通 conversation backend。
- 同步 M7 WBS、验收追踪、状态、变更日志和 evidence。

## Out of scope

- 不重写 Rust Messaging Core。
- 不通过隐藏 `operation.failed` 或吞掉错误来伪装修复。
- 不把 Mini App 复制成第二套 Agent runtime。
- 不在本地执行应用构建、Playwright 或重型测试；按仓库规则由 GitHub Actions 验证。

## Dependencies

- `M7-DESKTOP-001` 统一 Messenger 已落入 main。
- `miniapp.open` / `miniapp.opened` Host contract 已存在。
- Electron Messenger CI/E2E workflow 可运行。

## Acceptance criteria

1. `conversation.kind === 'miniapp'` 不再进入普通 Messenger conversation list；Electron edge 会记录其 canonical Mini App route。
2. 若旧路径直接尝试 `conversation.open` 一个已识别 Mini App，会改写为既有 `miniapp.open`，不再送入 Agent backend。
3. 普通联系人/Bot/Agent 会话的 `messenger-input` 位于 viewport 内且可输入。
4. 空会话/长消息区都不能把 composer 挤出 `.chatWorkspace` 的裁剪边界。
5. 新增自动化回归覆盖 Mini App 路由和 composer 几何可见性。
6. 相关 GitHub Actions 通过，PR 经受保护流程合并，并在 canonical `main` 回读确认实现与项目记录一致。

## Verification plan

- Lightweight source/diff inspection only in development session.
- GitHub Actions: Electron typecheck/build-renderer contract as configured by repository CI.
- GitHub Actions: desktop Messenger Playwright/E2E relevant gate.
- Protected merge and canonical-main readback.

## Risks / blockers

- 生产数据中的 Mini App conversation ID 可能带命名空间前缀；实现同时使用已知 title 映射和末段 ID 归一化，避免只依赖 `bot-father` 一个裸 ID。
- 当前安装中的 macOS 客户端不会因为源码合并自动更新；现场验证需要安装包含本次修复的最新正式包。

## Implementation summary

- `frontend/apps/web/src/lib/mahayana-host/electron-transport.ts`
  - 捕获 `conversation.listed` 中 `kind=miniapp` 项并从普通聊天列表剥离；
  - 缓存 conversation → Mini App route；
  - 对历史/直接 `conversation.open` 调用提供 `miniapp.open` fallback，消除错误 Agent backend 路由。
- `desktop/src/messenger-layout-regressions.css`
  - 让 chat workspace 与直接 flex content 使用 `min-height: 0`；
  - composer 使用 `flex: 0 0 auto`，保证不会被 message area 挤出裁剪 viewport。
- `desktop/e2e/messenger-regressions.spec.ts`
  - 使用 fake Electron bridge 验证 Mini App 过滤与 `miniapp.open` 改写；
  - 启动真实 Electron test Host，逐个点击可见 chat peer 并验证 `messenger-input` bounding box 完整处于 viewport 内。

## Evidence

- PR: `#2053`.
- Initial implementation head: `46be6d7268962fe0f682d93efb69f3d29ade8b2a`.
- Initial current-head GitHub Actions:
  - Project portfolio governance `32627390573` — SUCCESS.
  - Host fast E2E `32627390610` — SUCCESS.
  - Messaging Product Gate `32627390565` — running at evidence update time.
  - Electron desktop quality gate `32627390618` — running at evidence update time.
  - CI `32627390630` — running at evidence update time.
- PR #2053 auto-merge enabled; protected merge remains gated on required checks.

## Next action

等待 #2053 最新 head 的 GitHub Actions 全绿；如有失败按失败日志修复。全部 required checks 通过后由 protected auto-merge 落 main，再执行 canonical-main readback 并将任务提升为 `TESTED`。
