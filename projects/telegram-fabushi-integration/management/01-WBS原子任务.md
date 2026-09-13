# WBS 原子任务

- **项目**：Fabushi Telegram 全量融合
- **文档 ID**：MGMT-01
- **版本**：v1.1
- **状态**：BASELINE
- **基线日期**：2026-08-22
- **源计划**：`../source/完整telegram融合进fabushi.txt`

> 本文档由源计划结构化拆分而来。源计划未明确的管理字段会标记为“项目管理补充/待确认”，避免把推导内容冒充既有事实。

## 使用规则

每一项任务都必须具备稳定 ID、交付物、验收标准、客观验证、状态、证据位置和下一步。这里先根据源计划建立基线任务；代码审查后可以继续细分，但禁止用模糊“大任务”替换可验证原子任务。

## 分卷索引

为便于 GitHub 长期维护，原子任务按阶段拆分；各分卷共同构成完整 WBS。

- [M0 现状清点与边界固定](wbs/M0.md)
- [M1 Rust Core 骨架](wbs/M1.md)
- [M2 自建实时网络 + 1:1 文本消息](wbs/M2.md)
- [M3 桌面聊天完整交互](wbs/M3.md)
- [M4 媒体与文件](wbs/M4.md)
- [M5 联系人 + 群组](wbs/M5.md)
- [M6 频道 + Topic + 管理能力](wbs/M6.md)
- [M7 Bot/Agent 统一联系人体系](wbs/M7.md)
- [M8 Mini Apps](wbs/M8.md)
- [M9 支付](wbs/M9.md)
- [M10 语音/视频通话](wbs/M10.md)
- [M11 移动端共享 Rust Core](wbs/M11.md)
- [M12 高级 IM 能力](wbs/M12.md)
- [M13 安全强化 + E2EE](wbs/M13.md)
- [M14 全量替换旧通信栈](wbs/M14.md)
- [项目治理任务](wbs/governance.md)

状态变更必须同时更新对应分卷、验收追踪矩阵、状态报告与任务记录。

## 2026-08-24 — M3-DESKTOP-002 Telegram local-first + Settings

- `M3-DESKTOP-002` — `TESTING`: returning-user fast-start projection, first sync 20 / cursor background 100, responsive zero-width absent info panel, Telegram-inspired Settings IA, supported desktop preference bindings, and Playwright regression coverage implemented in PR #2079. GitHub Actions + protected merge + canonical-main verification remain the completion gate.

## 2026-08-24 — M3-DESKTOP-002 closed

- `M3-DESKTOP-002` — `COMPLETED`: PR #2079 passed CI, Messaging Product Gate, self-hosted messaging, and Electron desktop quality gate, then merged through the protected merge queue as `01b33d60f7d7d9add41a5fba84d21014094cb5dc`. Canonical `main` was re-read at the merge SHA.

## 2026-08-24 — M3-DESKTOP-002 performance continuation

- `M3-DESKTOP-002` — `TESTING`: canonical-main full-relaunch E2E exposed a renderer-projection durability gap. Follow-up adds an existing native client-persistence mirror/fallback and durable-preclose assertion; `< 1000 ms` packaged timing + exact-main Release remain blocking.

## 2026-08-24 — M3-DESKTOP-002 returning-session continuation

- `M3-DESKTOP-002` — `TESTING`: durable projection restore is proven on canonical main; deterministic Rust test account persistence is the remaining full-restart blocker. Follow-up persists only UI-safe test identity in configured Host runtime data, deletes it on logout, and adds a post-auth-poll Messenger-stability E2E assertion. `< 1000 ms` exact-main packaged timing and Release remain blocking.

## 2026-08-25 — M8-MARKET-001 Telegram-style Mini Apps marketplace

- `M8-MARKET-001` — `IMPLEMENTED`: M8.T06 app registry 与 M8.T07 developer flow 已落 feature branch；包含 searchable/reviewed marketplace、external-source release metadata、default bot、slash/natural-language routing、BotFather/Mahayana generation workflow 与 HTTP/MCP contracts。
- 市场后端不托管或代理包；package release 指向 immutable GitHub/HTTPS source，并携带 SHA-256/size 供 Mahayana installer 验证。
- 完成门禁：current-head GitHub Actions → protected merge → canonical-main readback → exact-main packaged/E2E → strictly newer GitHub Release。

## 2026-08-26 — M8-DL-001 抖音批量无平台水印下载小程序

- `M8-DL-001` — `IMPLEMENTED`: 新增官方 `douyin-batch-downloader`，复用现有 Marketplace seed、Bot identity 和 Web Mini App surface；支持 jingxuan/modal_id、canonical video URL、短链接和作品 ID。
- clean-source contract：只选择 `bit_rate.play_addr` / `video.play_addr`，明确不把 `download_addr` 当无平台水印源；批量上限 50、并发 4、逐项错误隔离。
- 下载代理仅允许抖音/字节 CDN HTTPS Host并转发 Range，避免任意 URL SSRF；UI 明示仅用于拥有、获授权或法律允许保存的公开内容。
- 任务记录：`management/tasks/M8-DL-001-douyin-batch-downloader.md`；证据索引：`evidence/M8-DL-001/README.md`。
- 完成门禁：current-head CI → protected merge → canonical-main readback → exact-main packaged/E2E evidence → verified GitHub Release。

## 2026-08-26 — M8-DL-001 independent package continuation

- `M8-DL-001` — `TESTING`: 用户要求把 Downloader 从 `ai-backend` 内置功能提升为独立可安装、可迁移 Mini App。当前 branch 已删除 Downloader 专属 backend runtime/routes，保留通用 Marketplace；应用改由 versioned `app.tar.gz` + immutable release metadata + Mahayana shared runtime 分发。
- 独立 surface 已具备 GUI、`.mcp.json` stdio MCP、`.mahayana/plugin.json` CLI，以及 Rust `official-miniapps` provider 的 `resolve` / `download` 工具；portable boundary 由 dedicated CI 断言。
- 并行 PR #2136 的 package/runtime 实现已作为 feeder 合入当前 branch；错误引入的重复 `FAB-P0009 / DBD` 与 `projects/douyin-batch-downloader-miniapp/**` 已移除，唯一 canonical project 仍为 `FAB-P0001 / TFI`。
- 客观验证：package digest、MCP/CLI descriptors、无 `ai-backend/src/douyin_downloader.js`、Rust fmt/test/build、Marketplace search/install tests；全部 current-head checks + protected merge + exact-main packaged E2E/Release 完成前不得晋级 `COMPLETED`。

## 2026-08-27 — M8-WEBMCP-001 全量 MiniApp WebMCP Runtime

- `M8-WEBMCP-001` — `TESTING`: WebMCP 已设为所有 MiniApp 的统一前台 Agent 接口，Rust/Native 保持持久后台 Runtime；Tool Contract 为 WebMCP/MCP/slash/Bot/CLI 的单一事实源。
- Hosted MiniApp 已实现 `tools/list → WebMCP → tools/call`；本地安装 MiniApp 在 Electron/Android/iOS 使用受控 WebMCP surface，并通过 Rust `runtime.call` 执行 active local runtime Tool。
- Marketplace/BotFather 新增 WebMCP admission policy；桌面 Tool inventory 与当前 MiniApp contract 取交集，移动端 Hosted 页面不得调用本地 Native bridge，写/破坏性调用保持宿主原生确认。
- 目标版本统一为 `1.0.4`；实现 head `b965db5686521fc3dcc4592a293950aa35e542a7` 的 CI、Electron、Mahayana fast、Messaging、移动 catch-all、治理、安全等工作流均已通过。
- 任务仍未完成：PR #2169 必须以最终治理 head 再次全绿并经 protected `main` 合并；随后 exact-main packaged Electron/Android/iOS E2E、视觉/trace evidence 与 GitHub Release 1.0.4 仍是硬门禁。

## 2026-08-27 — M8-AEO-001 AEO / AI 应用发现

- [x] 固化用户需求、task、ADR 与开源调研。
- [x] 从 canonical Marketplace catalog 派生稳定 `#app` entity、aggregate/per-app/content/answer feeds。
- [x] 实现 8 个 intent answer pages、`llms.txt` / `llms-full.txt` 与 sitemap。
- [x] WebMCP 增加 `recommend_fabushi_app` / `get_app_capabilities`，保持只读发现边界。
- [x] robots 明确允许 OAI-SearchBot、ChatGPT-User、Googlebot、Bingbot。
- [x] 增加 AI discovery contract 并接入 Frontend CI。
- [x] current-head GitHub Actions 全绿（PR-head CI 33052057013）。
- [x] protected merge queue、canonical-main readback（merge SHA `a9f7c8e8a98a17fdbd2358232048607198069a0b`）。
- [x] production Cloudflare HTTP/runtime/crawler probes 与 exact-main web delivery evidence（Worker 33052308128；Mini Apps 33052308170）。

## 2026-09-05 — MAINSAFE exact-head checkout defect replanning — authoritative latest

- `TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001` — `REVIEW-FAILED / PROVENANCE-ONLY`: product PR #2343 final head `bf62cd9769cc24ae29fcf03c16a1f662bc7019aa` has green CI metadata, but raw run `33930830358` / job `101208897330` checked out synthetic merge SHA `265ceea6496b21ffdbd53d4fa8fc0b3374edd3ac` before the canonical script ran. Independent review #2344 / comment `5547912758` therefore returned `REVIEW-FAIL-VERSION-BOOTSTRAP-001`; #2343 is not merge/test/release evidence.
- `TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001` — `FROZEN / NEXT-ONLY-EXECUTABLE`; Requirement `M6-PM-VEHC-R01`, Acceptance `M6-PM-VEHC-A01`.
- A new product PR must start from freshly re-read canonical main. Implementation/config allowlist remains exactly `.github/workflows/ci.yml` plus `mobile/ios/project.yml` `CURRENT_PROJECT_VERSION 28 -> 29`, with only task-specific TFI records in addition.
- `pull_request` acceptance requires raw proof that actual checkout HEAD equals the final product head before the unchanged canonical script runs. `merge_group` acceptance separately requires actual checkout HEAD equals the current merge-group SHA. Required `CI result` must remain fail-closed on exact child `success`.
- Historical #2341/#2342/#2343/#2344 remain immutable provenance in this architecture round; no merge/rebase/retarget/force-push/close is authorized. Test release and stable release remain blocked.

## 2026-09-07 — TFI-M3-SETTINGS-LOGOUT-001 General 顶部退出登录入口

- `TFI-M3-SETTINGS-LOGOUT-001` — `IMPLEMENTED`: 将既有 `settings-logout` 从 General 底部移动到账户资料卡片之后、Theme 之前；保留原退出/缓存清理语义，新增真实 Messenger E2E 位置断言并将版本策略递增至 `1.2.56`。current-head CI、protected merge、exact-main delivery 与新版 Release 完成前不晋级 `RELEASED`。

## 2026-09-11 — TFI-USERSCRIPT-RECOVERY-001 关闭标签页后的任务记录恢复

- [x] `TFI-USR-001` 复现 2.9.2：任务数组仍在 `localStorage`，但新标签页因新的 session identity 看不到旧 `ownerTabId` 记录。
- [x] `TFI-USR-002` 将“恢复任务记录”提升为工作台顶部的一等入口。
- [x] `TFI-USR-003` 空白新标签页在 Web Lock 互斥确认后原地接管已关闭工作区。
- [x] `TFI-USR-004` 将已完成/已取消/已暂停/进行中记录纳入恢复范围，保留显式删除语义。
- [x] `TFI-USR-005` 增加当前标签页恢复、终态历史恢复和原标签页仍存活拒绝的回归覆盖；本地轻量检查 66/66 PASS。
- [x] `TFI-USR-006` source PR #1 review/CI/merge 与 `source main@9ace3f40858e0c8b56e87b39971f8b6741441200` readback；exact-main CI `34582579268` PASS。
- [x] `TFI-USR-007` 发布 2.9.3 到官方 raw-main 更新源和 GitHub Release `v2.9.3`；用户浏览器安装仍待点击一次更新。
- [ ] `TFI-USR-008` 在真实 Chrome/ChatGPT 记录 create → close → reopen → recover → open conversation 的截图、完整视频及 trace/diagnostics。
- [x] `TFI-USR-009` 父仓库 TFI 记录 PR #2509 经 merge queue 合并，并回读 `main@4363f07b186b9bee85004a3a2d6a5f0c5e9ef4f1`。

当前状态：`SOURCE_RELEASED / LIVE_INSTALL_AND_E2E_PENDING`，不得标记完成。

## 2026-09-11 — TFI-USERSCRIPT-RECOVERY-002 会话异常结束自动重发

- [x] `TFI-USR-AR-001` 持久化用户截图与“无 Stop、无最终回复、无授权卡即为异常结束”的恢复要求。
- [x] `TFI-USR-AR-002` 定位 2.9.3 只在亲眼观察 `Stop -> no Stop` 时启动 15 秒倒计时的晚观察缺口。
- [x] `TFI-USR-AR-003` 先增加晚观察回归，再修复稳定 clear 状态的短倒计时起点。
- [x] `TFI-USR-AR-004` 验证四次有限重试、新会话原样重发和全部误判保护；67/67 PASS。
- [x] `TFI-USR-AR-005` source PR #2、PR CI `34599085499`、`main@db663373e88b603350c24a73aedb991835509b2a`、exact-main CI `34599239366` 与 Release `v2.9.4`。
- [ ] `TFI-USR-AR-006` 真实 Chrome 异常结束→新会话→重发视觉/诊断证据。
- [x] `TFI-USR-AR-007` 父仓库 PR #2511 经 merge queue 合并，回读 `main@2e5151ed38a29130f6f1165639430a825dc2f2ab`。

当前状态：`SOURCE_RELEASED / LIVE_INSTALL_AND_E2E_PENDING`。

## 2026-09-11 — TFI-USERSCRIPT-RECOVERY-003 连接中断刷新与左侧任务分组

- [x] `TFI-USR-DS-001` 识别页面级“连接已中断。正在等待完整回复。”，排除消息正文和插件面板自触发。
- [x] `TFI-USR-DS-002` 保留任务/会话归属并有限刷新当前网页，不产生重复派发。
- [x] `TFI-USR-DS-003` 把当前与可恢复工作区按标签页分组展示在左侧任务列表。
- [x] `TFI-USR-DS-004` 每条任务展示状态、轮次和运行指示，并在可恢复组内提供恢复动作。
- [ ] `TFI-USR-DS-005` 完成轻量回归、source PR/exact-main CI、单调版本 Release 与真实 Chrome 证据。
- [ ] `TFI-USR-DS-006` 父仓库治理记录经 protected main 合并并回读。

当前状态：`SOURCE_RELEASED / LIVE_INSTALL_AND_E2E_PENDING`；范围仅限油猴脚本，不涉及 Fabushi 应用构建。

## 2026-09-11 — TFI-USERSCRIPT-RECOVERY-004 热更新工作区交接

- [x] `TFI-USR-HR-001` 固化真实 Work 已完成但新实例丢失 owner、未进入验收的现场证据。
- [x] `TFI-USR-HR-002` 让同文档旧实例 shutdown/lock release 可等待，新实例继承原 tab identity。
- [x] `TFI-USR-HR-003` 保持真实复制标签页隔离，并清理全部重复 root/style。
- [x] `TFI-USR-HR-004` 覆盖热更新后持续目标自动恢复并进入 review 的回归。
- [x] `TFI-USR-HR-005` 完成 source CI/merge/release（2.9.6）证据。
- [x] `TFI-USR-HR-006` 完成父记录 protected-main 合并与 canonical readback（PR #2518）。
- [ ] `TFI-USR-HR-007` 完成 live Chrome 安装版本、one-root 和 Work → 新验收会话的完整视觉/诊断证据。

当前状态：`SOURCE_RELEASED / LIVE_INSTALL_AND_E2E_PENDING`；仅限独立油猴脚本。

## 2026-09-12 — TFI-USERSCRIPT-RECOVERY-005 发送超时后的自动恢复

- [x] `TFI-USR-ST-001` 固化“自动重发次数用尽 → 自动暂停”与页面“消息发送超时，请重试”的现场证据。
- [x] `TFI-USR-ST-002` 完成现有状态机与发送/异常重试路径的根因分析，并完成 Retry/backoff 开源方案调查。
- [x] `TFI-USR-ST-003` 识别页面级发送超时并接入不重复点击的恢复路径（2.9.7）。
- [x] `TFI-USR-ST-004` 将快速预算耗尽转换为持久化有界退避，避免自动转为 `blocked`/`paused`（2.9.7）。
- [x] `TFI-USR-ST-005` 增加空闲调度器终态保护、轻量回归、source Release 和 parent-main 记录；父记录已通过 protected merge queue 并回读。
- [ ] `TFI-USR-ST-006` 完成真实 Chrome 安装版本与异常 → 新会话 → 原样重发 → 新验收会话的完整视觉/诊断证据。

当前状态：`SOURCE_RELEASED / PARENT_READBACK_COMPLETE / LIVE_INSTALL_PENDING`；仅限独立油猴脚本。

## 2026-09-12 — TFI-USERSCRIPT-RECOVERY-006 页面加载态识别与等待

- [x] `TFI-USR-LD-001` 固化用户截图语义：中央 spinner 是页面尚未完成渲染，不是生成已停止。
- [x] `TFI-USR-LD-002` 在独立 userscript 增加主内容区 loading detection 与可恢复 `loading` 状态，加载期间保持会话 URL/token 与当前调度占用。
- [x] `TFI-USR-LD-003` 加载期排除 `no-final-reply` 异常观察、重发、刷新和重复发送；加载信号消失后重新开始 clear observation。
- [x] `TFI-USR-LD-004` 增加 spinner、`aria-busy`、范围隔离和加载到稳定状态的 jsdom 回归；本地 81/81 PASS。
- [x] `TFI-USR-LD-005` source PR #10、source PR CI、exact source-main CI、canonical source readback 和 `v2.9.10` Release 已完成。
- [ ] `TFI-USR-LD-006` 父仓库记录 PR 经 protected main 合并并 canonical readback。
- [ ] `TFI-USR-LD-007` 已登录 Chrome 安装 `v2.9.10` 后保留加载中 → 完全加载 → 继续监督的截图、完整视频、trace/diagnostics。

当前状态：`SOURCE_RELEASED / PARENT_RECORD_PENDING / LIVE_EVIDENCE_PENDING`；仅限独立油猴脚本，不触发 Fabushi 应用构建门禁。

## 2026-09-13 — TFI-USERSCRIPT-RECOVERY-007 任务目标附件输入

- [x] `TFI-USR-FILE-001` 固化用户新增要求：任务目标支持图片、视频和其他文件；截图仅作为页面状态证据，不作为脚本指令。
- [x] `TFI-USR-FILE-002` 完成 open-source-first 调查，采用原生文件输入优先、`DataTransfer` paste 兜底和 IndexedDB local-first 设计，不引入私有上传 API 或外部运行时。
- [x] `TFI-USR-FILE-003` source `2.9.11` 完成多文件选择、元数据/Blob 分离、上传确认、超时 fail-closed、任务恢复/持续轮次衔接和删除清理。
- [x] `TFI-USR-FILE-004` source PR #11、PR CI、exact source-main CI、canonical source readback 与 Release `v2.9.11` 已完成；轻量回归 84/84 PASS。
- [ ] `TFI-USR-FILE-005` 父记录 PR 经 protected main 合并并 canonical readback。
- [ ] `TFI-USR-FILE-006` 已登录 Chrome 使用无敏感图片、短视频、普通文件完成选择 → 上传确认 → 发送的完整分步截图、视频、trace/diagnostics。

当前状态：`SOURCE_RELEASED / PARENT_RECORD_PENDING / LIVE_EVIDENCE_PENDING`；仅限独立油猴脚本，不触发 Fabushi 应用构建门禁。
