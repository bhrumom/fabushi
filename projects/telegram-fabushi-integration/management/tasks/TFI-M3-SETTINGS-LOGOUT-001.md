# TFI-M3-SETTINGS-LOGOUT-001 — General 顶部退出登录入口

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `TFI-M3-SETTINGS-LOGOUT-001`
- **Stage**: `M3 桌面聊天完整交互`
- **Status**: `IMPLEMENTED`
- **Started**: `2026-09-07`
- **Updated**: `2026-09-07`
- **Branch**: `fix/tfi-settings-logout-top-20260907`
- **Source**: `source/2026-09-07-settings-logout-placement.md`
- **Baseline main**: `c12711073221f2137c99351648c10cc2aa9ee8fb`
- **Target version**: `1.2.56`

## Objective

让桌面端 Settings → General 的“退出登录”成为账户资料区的一等入口：紧跟资料卡片，位于 Theme 和其它通用偏好之前；保持现有退出语义、缓存清理、自动化标识和单一账户状态机不变。

## Open-source first check

先检查 Telegram Desktop 的 Settings 实现。上游 `Telegram/SourceFiles/settings/sections/settings_main.cpp` 把 Log Out 暴露为 Settings 的稳定动作，并通过 `showLogoutConfirmation()` 触发退出；本任务只吸收“退出是清晰、稳定的一等设置动作”的成熟产品模式，不复制其代码、品牌、样式或资产。现有 Fabushi `onLogout` / `settings-logout` 仍为唯一实现。

## Acceptance criteria

1. `Settings → General` 中现有 `settings-logout` 入口紧跟账户资料卡片，并在 `settings-theme` 之前直接可见。
2. 保留 `data-agent-id="settings-logout"`、`data-testid="settings-logout"` 和现有 `onLogout` 行为。
3. 真实 Messenger E2E 断言退出入口的纵向位置在 Theme 之前。
4. 现有退出 E2E 继续证明退出后进入 login gate，并清除 Messenger projection、draft 和 Mahayana conversation journal 等账户作用域缓存。
5. canonical 版本从 `1.2.55` 严格递增到 `1.2.56`，现有版本策略文件保持一致。
6. current-head CI 通过、受治理 PR 合并、canonical main 回读通过。
7. exact-main Electron/native 门禁完成，并发布对应 `1.2.56` 新版资产；在这些证据完成前不得标记 `RELEASED`。

## Verification

- `git diff --check`。
- 依赖无关的 canonical/version contract。
- GitHub Actions Electron desktop quality gate。
- GitHub Actions Native mobile quality gate（版本策略同步触发）。
- post-main exact-SHA delivery / Release。

## Current evidence

- 用户截图与要求：2026-09-07。
- Baseline main：`c12711073221f2137c99351648c10cc2aa9ee8fb`。
- Implementation：退出行从 General 底部移动到 profile 之后 / Theme 之前；没有新增退出业务逻辑。
- Regression：`desktop/e2e/messenger.spec.ts` 新增 logout-top < theme-top 断言，原有账户缓存清理退出 E2E 保持。
- Local lightweight validation：`git diff --check`、canonical architecture guard、desktop architecture guard 均 `PASS`。
- Merge/Release：`PENDING`。
