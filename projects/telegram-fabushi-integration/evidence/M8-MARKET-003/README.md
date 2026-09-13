# M8-MARKET-003 — 全平台 GitHub 安装更新证据索引

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task**: `M8-MARKET-003`
- **Branch**: `codex/tfi-miniapp-unified-install-update-20260913`
- **Implementation commit**: `3cd8ba783`
- **Records commit**: `7c95a6f89`
- **Test release target**: `1.2.58`
- **Version commit**: `04a985633`
- **状态**: `IN_PROGRESS`
- **创建日期**: `2026-09-13`

## 目标与证据边界

本目录记录“市场只发布元数据、客户端从不可变 GitHub 版本取包并校验、所有平台共享安装/更新/回滚状态”的实现证据。截图中的 Chrome Marketplace 仅是产品形态参考，不是代码或操作指令。

可执行包的正式路径是：Marketplace release metadata → GitHub commit/release artifact → Host 下载 → SHA-256/size 校验 → staging → active pointer。Web 页面只记录版本、来源和摘要；没有 Native Host 时不得把 metadata 记录宣传为已安装可执行包。Chrome 用户脚本由用户显式点击后从固定 `raw.githubusercontent.com` 地址取回，并在扩展内校验后交给 userscript runtime。

## 已完成的实现面（待 PR/main 验证）

- Node Marketplace：统一发布合同 `fabushi.marketplace.install.v1`，公共 GitHub repository + 40 位 commit `sourceRef`，artifact SHA-256/size/format/entry/runtime/platforms，平台筛选和非 GitHub 拒绝。
- Rust Runtime/Host：合同校验、GitHub 来源约束、下载后二次 SHA-256/size 校验、版本单调更新、`previous-active.json` 和显式 rollback。
- Desktop/Chrome/Web/Android/iOS/CLI：共用 release/install/update 语义；Chrome 用户脚本支持 pinned raw GitHub artifact；Web 执行包安装要求 Host。
- Marketplace UI：显示 GitHub 来源、commit 前缀、版本、权限/发布说明入口，并区分安装、更新、重新安装、当前最新、阻止降级和等待 GitHub 发布。

## 轻量检查

| 检查 | 结果 | 备注 |
|---|---|---|
| `git diff --check` | PASS | 当前工作树差异无空白错误 |
| Chrome JS syntax | PASS | `app.js`、`marketplace-install.js`、`userscript-core.js` |
| Chrome contract/platform tests | PASS `11/11` | Node targeted tests |
| Backend pure marketplace tests | PASS `9/9` | `ai-backend/test/miniapp_marketplace.test.js` |
| Backend HTTP test | NOT RUN | checkout 缺少 `express`，未安装依赖 |
| Rust/Next/Electron/mobile build/E2E | PENDING | 按仓库磁盘安全规则只在 GitHub Actions 执行 |

## 已知发布数据风险

只读核对发现固定 `marketplace/packages` 目录存在需要 CI/release 处理的历史数据问题：`chatgpt-auto-confirm`、`faliu-flashcards`、`hermes-installer` 的 `app.tar.gz` 均未通过 gzip 校验；这三项的 catalog SHA-256/size 也与当前 checked-in bytes 不一致。当前任务没有在本地重打包或替换这些资产；必须由后续受控发布步骤重新生成、校验并提升版本，不能以旧版本元数据发布。

## 待补齐的 GitHub 证据

- PR 编号、最终 PR-head SHA、required checks/job/run 及 exact-head checkout 证据。
- protected merge-group、canonical `main` SHA 和项目记录回读。
- exact accepted `main` 的 Electron、Android、iOS、CLI packaged/simulated-user journeys。
- 每个 required journey 的分步截图、完整操作视频、Playwright/平台 trace、HTML/test report、原生日志；PASS/FAIL 均需 always-upload，且与 SHA、版本、平台、run/job 和时间戳绑定。
- 通过所有 required post-main gates 后的 GitHub Release tag/target SHA/安装包、`latest-mac.yml`、ZIP/DMG/blockmap 等 updater 资产（若该版本发布桌面包）。

## 结果

实现已完成到当前工作树级别，但 `PR → protected main → packaged E2E/evidence → Release` 尚未闭合。因此本任务保持 `IN_PROGRESS`，不得报告为已完成。
