# M7-DESKTOP-002 — Messenger composer visibility and Mini App routing repair

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M7-DESKTOP-002`
- **Stage**: `M7 Bot/Agent 统一联系人体系`
- **Status**: `IN_PROGRESS`
- **Started**: `2026-08-23`
- **Updated**: `2026-08-23`
- **Branch**: `fix/tfi-m7-messenger-composer-miniapp-routing`
- **Primary PR**: `TBD`

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

1. `conversation.kind === 'miniapp'` 不再被归类为普通 conversation 并调用 `conversation.open`。
2. 点击 Bot Father 类 Mini App peer 使用既有 Mini App Host 路由；不会产生 `agent backend is unavailable: plugin not found` 错误横幅。
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

- 生产数据中的 Mini App conversation ID 可能带命名空间前缀；实现需避免只依赖一个硬编码 ID。
- 当前安装中的 macOS 客户端不会因为源码合并自动更新；若用户要求现场验证，需要后续构建/发布/安装最新包。

## Implementation summary

Pending.

## Evidence

Pending CI/PR evidence.

## Next action

实现 Mini App peer 分类/路由、composer 布局约束和对应 E2E 回归，然后提交 PR 进入 GitHub Actions 验证。
