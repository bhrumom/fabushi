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

## 2026-09-05 — MAINSAFE protected merge / test-release execution

- `TFI-M6-MAINSAFE-001-VERSION-EXACT-HEAD-CHECKOUT-001` — `MERGED / CANONICAL-READBACK-PASS`: reviewed product `#2345@9c46c1d8f030be390995cc78f321aac0d96b7f44` entered the active protected merge queue from `main@dbf22b467d35c8af2a074896c355a41993c8c191`; merge-group run `33939126976` proved actual HEAD equals group SHA `63e49b87d1ca5ad64d988e73769bf4a4ed796a19`, canonical child `101232897597` SUCCESS, required `CI result` `101233054947` SUCCESS; #2345 merged and canonical `main` read back at the same SHA.
- `TFI-M6-MAINSAFE-001-TEST-RELEASE-001` — `BLOCKED / REQUIRED-MAINSAFE-POST-MAIN-PREREQUISITES-NOT-SATISFIED`: exact canonical main does not contain the separately frozen `IOS-FIXTURE-001`, `EVIDENCE-CONTRACT-001`, or `EVIDENCE-JOURNEY-001` prerequisites. Automatic exact-main Electron/native runs are observational evidence only and cannot waive that prerequisite set.
- Evidence: `evidence/TFI-M6-MAINSAFE-001/TEST-RELEASE-2026-09-05.md` and `management/93-2026-09-05-M6-MAINSAFE-001-测试发布合并与阻塞记录.md`.
