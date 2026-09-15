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

## 2026-09-14 — TFI-USERSCRIPT-RECOVERY-011 标签页崩溃/卡住自动恢复

- [x] `TFI-USR-CRASH-001` 固化 renderer 崩溃页、卡住页和 stale heartbeat 的页面外恢复边界，采用 source `v2.9.20` 与宿主 `tab-recovery` capability lease。
- [x] `TFI-USR-CRASH-002` 保持 Work/验收/下一轮的 URL、token、phase/round 和 IndexedDB attachment IDs 连续，恢复后的当前 composer 重新注入并确认附件后才发送。
- [x] `TFI-USR-CRASH-003` 修复“最终回复被误判成停止回答”的交接：识别自然语言 Work final，向下一轮验收会话传递完整 final reply，不重复派发。
- [x] `TFI-USR-CRASH-004` 修复需要处理状态的恢复计时复用，恢复后使用独立确认窗口；不确定发送保留 token/附件，明确唯一 URL 后不重复点击 Send。
- [x] `TFI-USR-CRASH-005` source PR #15、exact-main CI、Release `v2.9.20` 及 parent PR #2594、packaged/post-main/Release 证据已完成；records PR #2603 合并后当前 canonical main 为 `387ae731c3677d9d3023d400f1da60d7ac958a4f`。
- [x] `TFI-USR-CRASH-006` Chrome Web Store 受保护凭据/API 已配置；既有 `0.6.0` 草稿已通过已登录 Developer Dashboard 提交，后台当前为“待审核”。
- [ ] `TFI-USR-CRASH-007` 完成已登录 Chrome 的崩溃/error page → 原标签或单次接管 → 附件连续 → final→验收完整截图、视频、trace/diagnostics。
- [ ] `TFI-USR-CRASH-008` 将自动 Web Store 发布流程改为识别已有同版本草稿并幂等复用，避免 HTTP 400 被误判为上传成功。

当前状态：`IN_PROGRESS / WEBS_STORE_PENDING_REVIEW / LIVE_CHROME_EVIDENCE_PENDING`；GitHub Release 已完成，Chrome Web Store 外部审核和真实现场证据仍是退出门禁。

## 2026-09-13 — TFI-USERSCRIPT-RECOVERY-010 恢复/继续附件连续性

- [x] `TFI-USR-ATTACH-001` 将附件确认绑定到 task token、当前 route 和当前 composer，context 变化时失效旧确认并保留 metadata/Blob。
- [x] `TFI-USR-ATTACH-002` Work、验收、下一轮 Work、暂停/取消恢复和异常重发均在当前 composer 重新注入/确认，未确认时 fail-closed。
- [x] `TFI-USR-ATTACH-003` 增加连续轮次、DOM/document 重建、暂停/取消恢复和失败重试回归；source `98/98` PASS。
- [x] `TFI-USR-ATTACH-004` source PR #14、exact source-main CI、canonical source readback 和 Release `v2.9.19` 已完成。
- [x] `TFI-USR-ATTACH-005` 父仓库记录 PR #2587/#2588 已经 merge queue 合并并最终 canonical readback，main `baf1311363ddb03470e9ec14bd04de52d1141662`。
- [ ] `TFI-USR-ATTACH-006` 已登录 Chrome 安装 `v2.9.19` 后完成首次带附件 → 恢复/继续 → 下一轮仍带附件的分步截图、完整视频、trace/diagnostics。
- [ ] `TFI-USR-ATTACH-007` 现场证据确认缺 Blob/上传失败/超时不会发送无附件目标，并记录可重试状态。

当前状态：`SOURCE_RELEASED / PARENT_READBACK_COMPLETE / LIVE_EVIDENCE_PENDING`；仅限独立油猴脚本，不触发 Fabushi 应用构建门禁。

## 2026-09-13 — M8-MARKET-003 全平台 GitHub 安装更新

- [x] `M8-MARKET-003-R01` 将用户的 GitHub-first 要求持久化为源需求和受治理 task record，并完成开源优先调查。
- [x] `M8-MARKET-003-R02` 后端/Rust/Host 统一 `fabushi.marketplace.install.v1`，固定 public GitHub commit，校验 artifact SHA-256/size，禁止市场托管包字节和静默降级，保留 previous-active/显式回滚。
- [x] `M8-MARKET-003-R03` 桌面、Chrome、Web、Android、iOS、CLI 接入同一安装/更新状态；Web 的可执行包路径明确要求 Native Host，Chrome 用户脚本仅接受 pinned raw GitHub artifact。
- [x] `M8-MARKET-003-R04` Marketplace 卡片与 WebMCP 暴露来源、版本、权限、发布说明/状态；新增 Node Chrome `11/11` 与 backend pure marketplace `9/9` 轻量回归。
- [x] `M8-MARKET-003-R05` PR-head CI、protected main、canonical-main readback、packaged Electron/mobile/CLI E2E 和完整视觉/调试证据；准确主线 `f6a0d99c…` 的 Electron、Native mobile、Chrome 与 post-main 运行全部通过，证据 90 天保留。
- [x] `M8-MARKET-003-R06` 修复或重新发布固定 catalog 中 hash/size 不一致或损坏的历史包，并绑定 strictly newer GitHub Release；三项历史包以 CI 重建为 `1.0.1`，桌面测试版为 `1.2.65`。

当前状态：`RELEASED`；产品交付证据绑定 `main@f6a0d99c85a481999298a18cada6a9f10718a360` 与 [desktop-1.2.65](https://github.com/bhrumom/fabushi/releases/tag/desktop-1.2.65)。本地只做轻量检查，构建、打包、E2E 和 Release 均由 GitHub Actions 完成。

## 2026-09-13 — TFI-USERSCRIPT-RECOVERY-007 任务目标附件输入

- [x] `TFI-USR-FILE-001` 固化用户新增要求：任务目标支持图片、视频和其他文件；截图仅作为页面状态证据，不作为脚本指令。
- [x] `TFI-USR-FILE-002` 完成 open-source-first 调查，采用原生文件输入优先、`DataTransfer` paste 兜底和 IndexedDB local-first 设计，不引入私有上传 API 或外部运行时。
- [x] `TFI-USR-FILE-003` source `2.9.11` 完成多文件选择、元数据/Blob 分离、上传确认、超时 fail-closed、任务恢复/持续轮次衔接和删除清理。
- [x] `TFI-USR-FILE-004` source PR #11、PR CI、exact source-main CI、canonical source readback 与 Release `v2.9.11` 已完成；轻量回归 84/84 PASS。
- [ ] `TFI-USR-FILE-005` 父记录 PR 经 protected main 合并并 canonical readback。
- [ ] `TFI-USR-FILE-006` 已登录 Chrome 使用无敏感图片、短视频、普通文件完成选择 → 上传确认 → 发送的完整分步截图、视频、trace/diagnostics。

当前状态：`SOURCE_RELEASED / PARENT_RECORD_PENDING / LIVE_EVIDENCE_PENDING`；仅限独立油猴脚本，不触发 Fabushi 应用构建门禁。

## 2026-09-14 — TFI-USERSCRIPT-RECOVERY-012 任务级控制与详情

- [x] `TFI-USR-TASK-001` 固化用户反馈、根因与开源优先调查；截图只作为故障证据。
- [x] `TFI-USR-TASK-002` 单任务暂停/继续/取消与全局暂停分离，异步暂停不会误转为需要处理。
- [x] `TFI-USR-TASK-003` 任务行增加详情、暂停/继续/恢复和安全删除入口；详情保留目标、日志、会话和附件信息。
- [x] `TFI-USR-TASK-004` 新增任务隔离与 UI 回归，source 2.9.21 轻量回归 108/108 通过。
- [ ] `TFI-USR-TASK-005` source PR #16 的 CI、protected main、Release `v2.9.21` 与 canonical source readback。
- [ ] `TFI-USR-TASK-006` 登录态 Chrome 完成单项暂停/继续、其他任务连续运行、详情和删除的分步截图、完整视频、trace/diagnostics。

当前状态：`IN_PROGRESS / SOURCE_PR_OPEN / LIVE_EVIDENCE_PENDING`；仅限独立 userscript，不触发 Fabushi 应用构建门禁。

## 2026-09-14 — TFI-USERSCRIPT-RECOVERY-013 内存感知与宿主标签页回收

- [x] `TFI-USR-MEM-001` 记录 5.7GB 现象、JS heap 与 renderer/RSS 边界，并完成 Chromium/成熟开源方案调查。
- [x] `TFI-USR-MEM-002` userscript 增加任务日志有界化、弱引用附件输入、监听器/临时 URL 生命周期清理与内存压力诊断。
- [x] `TFI-USR-MEM-003` userscript 增加连续高压采样、手动清理入口、脱敏 `tab-memory.request` 与 `memory_status/cleanup_memory` 工具。
- [x] `TFI-USR-MEM-004` MV3 host 增加能力校验、真实 sender tab 校验、安全状态屏障、冷却和 `chrome.tabs.discard()`。
- [x] `TFI-USR-MEM-005` source PR #17、host PR #2607 与任务证据索引已建立；source 111/111 本地轻量回归通过。
- [ ] `TFI-USR-MEM-006` source/host CI、protected main 与 canonical readback。
- [ ] `TFI-USR-MEM-007` exact-main packaged/Chrome 现场证据及按授权执行的发布回读。

当前状态：`IN_PROGRESS / SOURCE_PR_OPEN / HOST_PR_OPEN / LIVE_EVIDENCE_PENDING`；不运行本地重型构建或应用 E2E。

## 2026-09-14 — TFI-USERSCRIPT-RECOVERY-013 merge/readback update

- [x] source PR #17 已合并；canonical source main `882cadf0cc35d00a29b93450990d758b4034a5c0`，版本 2.9.22。
- [x] host PR #2607 已合并；canonical host main merge SHA `f7f9871b153efbe26d040e68e8d28eea46af2130`。
- [x] 发现并修复 host runner 未分发 `fabushi.userscript.memory.request` 的接线遗漏，并同步 `0.6.1` 校验/打包/E2E/测试版本契约。
- [ ] host follow-up PR #2608 CI/protected merge 与 canonical readback。
- [ ] exact-main packaged/Chrome 证据、公开发布授权及 Release/Web Store 回读。

当前状态：`IN_PROGRESS / SOURCE_MERGED / HOST_FOLLOWUP_OPEN / LIVE_EVIDENCE_PENDING`。


## 2026-09-14 — TFI-USERSCRIPT-RECOVERY-013 发布/主线回读

- [x] source exact-main CI 与 source main readback：`faf68931dfa5c915feb316ea2a8da1de45384b96` / `34813245918` / userscript `2.9.23`。
- [x] 按明确授权发布 source Release `v2.9.23`，资产 SHA-256 `80bea8ea03d18bd258bd4a326d150786b01cb52d2a731db7a04c7d4ffcaee7e4`。
- [x] host package preflight 与 canonical-main Chrome packaged journey：main `13188628da46b88db843c9c5b4d59100233e3a21`，workflow `34817384069` 成功，证据 artifact `10337146244`。
- [ ] Electron/mobile/security 其余 post-main 门禁与最终任务回读。
- [ ] 官方 MCP remote Runner 手测：连接器内部错误恢复后，用同一测试账号完成 list → describe → `ci_session_status` → 手动内存验收 → note → finish。

当前状态：`IN_PROGRESS / SOURCE_RELEASED / HOST_CHROME_EXACT_MAIN_PASSED / REMOTE_MANUAL_PENDING`。

## 2026-09-14 — 新增 WBS 原子任务

| Task ID | Project | 原子目标 | 状态 | 当前证据 | 下一步 |
|---|---|---|---|---|---|
| TFI-USERSCRIPT-RECOVERY-014 | FAB-P0001 / TFI | 宿主受控导航、renderer 崩溃恢复、source 2.9.24 与 Chrome 0.6.2 发布 | IN_PROGRESS | source main 71a2279b；source CI run 34838068938 114/114；parent branch codex/release-0.6.2-renderer-guard-20260914 | parent PR/保护主线、exact-main Chrome package/journey、Web Store 与安装版本回读 |

## 2026-09-14 TFI-USERSCRIPT-RECOVERY-014 交付回读

| 原子任务 | 状态 | 证据 |
| --- | --- | --- |
| 脚本会话结束后创建新验收路由 | 已实现/已验证 | 源码 PR #19、canonical source main 71a2279、CI 34838068938（114/114） |
| 宿主 tab-navigation-guard 与 renderer crash/unloaded 防护 | 已实现/已验证 | 父 PR #2623 → main b4d2d85；Chrome run 34839358565 |
| 精确主 SHA 打包、证据与发布物 | 已通过 | post-main run 34840407940；Chrome 0.6.2 包含截图、视频、trace、HTML/report、日志 |
| Web Store 提交与当前 Chrome 更新 | 进行中 | publisher runs 34840738917/34841285781：条目已有审核中提交；当前 Chrome 0.4.1 待确认重载 |

## 2026-09-14 TFI-USERSCRIPT-RECOVERY-014 最终发布与本机回读

- [x] source v2.9.24、host Chrome 0.6.2、parent protected-main 与 exact-main packaged journey 完成。
- [x] final canonical main `396a842c7e00b8ad7c236d84cabc9230ed88d391` 的 Chrome package run `34842044140` 与 post-main run `34843041788` 完成；Release 含 Chrome ZIP/manifest/checksum。
- [x] 当前 Chrome 未打包扩展已重载并回读 v0.6.2；旧版备份可回滚。
- [ ] Web Store 现有审核提交仍锁定 item，公开 0.6.2 发布等待审核完成或单独明确的取消决定。

当前状态：`IN_PROGRESS / LOCAL_CHROME_0.6.2_VERIFIED / WEB_STORE_REVIEW_PENDING`。


## 2026-09-14 TFI-USERSCRIPT-RECOVERY-014 最新反馈跟进

| 原子任务 | 状态 | 证据/下一步 |
| --- | --- | --- |
| assistant 错误卡片中的发送超时识别 | 已实现/待主线回读 | source v2.9.26、source PR #21、source CI 34849096867；parent PR #2628 待 Merge Queue |
| 发送超时进入新派发队列且不自动暂停 | 已实现/待主线回读 | `inspect → queueNoFinalReplyRetry` 回归；Chrome 0.6.4 packaged journey 待 exact main |
| 人工打开历史会话时明确暂停原因 | 已实现/待主线回读 | source v2.9.26 manual inspection log regression；待 Chrome 包含该源码 |
| Chrome 宿主与 bundled userscript 版本一致 | 进行中 | parent PR #2628：Chrome 0.6.4，固定 source commit/hash/size；等待 protected main |
| exact-main 发布/现场安装回读 | 未开始 | 待 parent merge 后运行 Chrome package、packaged journey、证据归档与 Release |


## 2026-09-14 — TFI-CI-OPT-015 按变更范围选择自动化检查

| Task ID | Project | 原子目标 | 状态 | 当前证据 | 下一步 |
|---|---|---|---|---|---|
| TFI-CI-OPT-015 | FAB-P0001 / TFI | 为安全、桌面、GBF 与 Global Dharma 工作流增加 changed-path scope，跳过未受影响的重矩阵并保留稳定检查名 | IN_PROGRESS | task record；开源调查 dorny/paths-filter；workflow implementation branch | PR Actions 验证 scope、skipped 聚合、merge_group 与 main push 行为 |

验收约束：Chrome-only 变更不启动 Computer Control Rust/platform-worker/Linux desktop、Electron PR journey、GBF closure 与无关 Global Dharma 依赖；workflow/scope/security boundary 变更保守全量；main 发布路径不变。

## 2026-09-15 — TFI-USERSCRIPT-RECOVERY-016 公平持续调度

| Task ID | Project | 原子目标 | 状态 | 当前证据 | 下一步 |
|---|---|---|---|---|---|
| TFI-USERSCRIPT-RECOVERY-016 | FAB-P0001 / TFI | 按任务 eligibility/最早唤醒点公平轮换；区分限流、导航保护和普通退避；查看会话不中断；旧 runner lock 有界接管 | IN_PROGRESS / LIVE_CHROME_CONFIRMATION_PENDING | source main `480ebe61` / v2.9.30 / PR #22/#23；parent PR #2638/#2639 已合并至 `main@80ef6f15`；Electron `34880495486`、Chrome `34881462209`、post-main `34881675501` 成功；Release 已发布 | 当前 Chrome Tampermonkey 更新确认与登录态双任务连续轮换证据；Web Store 状态独立跟踪 |

- `TFI-USR-SCHED-R01..R06` 已在 source 侧实现并有 focused/full regression；Chrome 0.6.5 packaged journey 与完整 evidence bundle 已由 artifact `10362084424` 验证。
- 本任务继续保留单页前台写操作互斥，不以并行任务为由允许同一 composer 的发送、上传、授权或未确认派发并发。

## 2026-09-15 — TFI-USERSCRIPT-RECOVERY-017 Marketplace 线上 userscript 发现

| Task ID | Project | 原子目标 | 状态 | 当前证据 | 下一步 |
|---|---|---|---|---|---|
| TFI-USERSCRIPT-RECOVERY-017 | FAB-P0001 / TFI | 让旧 Chrome 扩展从公开控制面发现 userscript v2.9.30，同时保持桌面/CLI Mini App release 不变 | IN_PROGRESS / PR_PENDING | source v2.9.30 Release 与 parent bundled pin 已验证；Worker Chrome-only projection 已实现并加入单测 | Platform Control Plane CI、protected main、生产部署和线上 catalog/direct-release 回读 |

| TFI-USERSCRIPT-RECOVERY-017-AUTO | FAB-P0001 / TFI | Service Worker 启动/安装/30 分钟 alarm、Marketplace 打开/5 分钟目录刷新和持久化更新提示 | IMPLEMENTED / CI_PENDING | `marketplace-update-check.js`、`app.js`、manifest 0.6.6 与纯比较回归已写入分支 | Chrome package/packaged E2E 与 protected main 交付证据 |
- 第一版 PR #2641 已进入 `main@4f484be2…`，Chrome package `34922024248` 和 Worker deploy `34922024310` 已通过；follow-up PR #2642 的状态保持修复仍待合并。

## 2026-09-15 — TFI-USERSCRIPT-RECOVERY-017 主线修复与商店门禁

| Task ID | Project | 原子目标 | 状态 | 当前证据 | 下一步 |
|---|---|---|---|---|---|
| TFI-USERSCRIPT-RECOVERY-017 | FAB-P0001 / TFI | 让 Chrome 插件在后台自动识别线上 userscript 更新 | IN_PROGRESS / WEB_STORE_REVIEW_BLOCKED | PR #2646 → `main@05297b21…`; Chrome run `34925924905`, artifact `10379573729`, 0.6.7 packaged journey/evidence 通过；线上 catalog v2.9.30 | 等待现有 Chrome Web Store 审核结束后重新提交 0.6.7；不取消或覆盖审核中的提交 |
| TFI-USERSCRIPT-RECOVERY-017-AUTO | FAB-P0001 / TFI | 启动/安装/30 分钟后台检查、5 分钟页面刷新、持久化徽章与更新提示 | VERIFIED / MAIN_PACKAGE_GREEN | `marketplace-update-check.js`, `app.js`, manifest 0.6.7；exact-main artifact `10379573729` 含截图/视频/trace/report/log | Web Store 公开版本回读 |

| TFI-USERSCRIPT-RECOVERY-017-LIVE-CATALOG | FAB-P0001 / TFI | Chrome popup 优先读取实时 Marketplace，Host 仅网络失败兜底；并发目录请求按序提交 | VERIFIED / MAIN_PACKAGE_GREEN | `app.js` 的 live-catalog-first 与 `marketplaceRequestId`；`main@05297b21…`、Chrome run `34925924905`、artifact `10379573729` 的 0.6.7 packaged journey 通过 | Web Store 审核结束后公开发布 0.6.7 |
