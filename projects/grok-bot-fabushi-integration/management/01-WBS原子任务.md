# 01 WBS 原子任务

状态：`NOT_STARTED / IN_PROGRESS / IMPLEMENTED / TESTED / E2E_VERIFIED / RELEASED`。进度只按达到各任务所需验收状态的 required task 数计算，不手填主观百分比。

| ID | Stage | Action | Dependency | Acceptance | Verification | Evidence | Status | Blocker | Next action |
|---|---|---|---|---|---|---|---|---|---|
| GBF-001 | M0 | 建立企业级项目基线 | none | 标准 scaffold + PR/CI/main 验证 | project audit + GitHub facts | evidence/GBF-001 | RELEASED | none | GBF-101 固定 source/main refs |
| GBF-101 | M1 | 固定 source/main 基线 ref | GBF-001 | 3 个权威 ref/commit 固化 | GitHub ref read | evidence/GBF-101 | RELEASED | none | M2/M3/M5 downstream audit |
| GBF-102 | M1 | 生成来源递归 file manifest | GBF-101 | 来源文件 path/hash/type 100% 入表 | manifest completeness check | evidence/GBF-102 | RELEASED | none | M2/M3/M5 downstream audit |
| GBF-103 | M1 | 建立功能能力矩阵 | GBF-102 | 关键文件全部映射能力域 | zero-unclassified check | evidence/GBF-103 | RELEASED | none | M2/M3/M5 downstream audit |
| GBF-104 | M1 | 建立 main/source 差异矩阵 | GBF-102,103 | 每项有处理分类 | matrix enum validation | evidence/GBF-104 | RELEASED | none | M2/M3/M5 downstream audit |
| GBF-105 | M1 | 建立 provenance ledger | GBF-102 | 来源/许可/复用/重写决策齐全 | zero unknown retained source | evidence/GBF-105 | RELEASED | none | GBF-703 release provenance audit |
| GBF-106 | M1 | 固定并分类 Grok Bot 0.18 reconstructed source | GBF-105 | 2,111 paths 全分类且无 COPY 决策 | deterministic manifest assertions | evidence/GBF-106 | RELEASED | none | 下游由 GBF-307/308/408/506/805 承接 |
| GBF-201 | M2 | 审计 Electron main.cjs | GBF-104 | 生命周期/IPC 独有差异有决策 | file/behavior diff review + post-main | evidence/GBF-201 | RELEASED | none | GBF-301 runtime convergence |
| GBF-202 | M2 | 收敛 preload/IPC contract | GBF-201 | 无通用 IPC；版本化 contract | allow/deny contract + packaged E2E | evidence/GBF-202 | RELEASED | none | GBF-301 runtime convergence |
| GBF-203 | M2 | 收敛 host-process | GBF-201 | 单一 host lifecycle/health/restart | host fault + real Host E2E | evidence/GBF-203 | RELEASED | none | GBF-301 runtime convergence |
| GBF-204 | M2 | 收敛 native capability handlers | GBF-202,203 | 所有高风险 handler 过 gate | capability/security tests | evidence/GBF-204 | RELEASED | none | GBF-701 security closure |
| GBF-205 | M2 | 收敛 native/edge IPC | GBF-202 | schema/error contract 唯一 | schema/version/sender tests | evidence/GBF-205 | RELEASED | none | GBF-301 runtime convergence |
| GBF-206 | M2 | 评估并迁移 Offline ASR | GBF-104 | 产品归属、资源/性能证据清晰 | unit + CI contract | evidence/GBF-206 | RELEASED | none | GBF-604 perf closure |
| GBF-207 | M2 | 迁移有效 Electron E2E | GBF-201..206 | 当前 main 架构可运行 | Host smoke + macOS/Windows/Linux packaged E2E | evidence/GBF-207 | RELEASED | none | GBF-801 final RC |
| GBF-301 | M3 | 盘点 coordinator/supervisor/host 行为 | GBF-103,104 | 重复执行链全部识别 | architecture walk + call graph | evidence/GBF-301 | TESTED | post-main closure records stale | verify canonical main + delivery evidence |
| GBF-302 | M3 | 统一 Agent loop 到 Mahayana | GBF-301 | 唯一正式 agent runtime | integration/call-path tests | evidence/GBF-302 | TESTED | post-main closure records stale | verify canonical main + delivery evidence |
| GBF-303 | M3 | 统一 tool/MCP/extension dispatch | GBF-302 | 同一 policy/result contract | contract + integration tests | evidence/GBF-303 | TESTED | post-main closure records stale | verify canonical main + delivery evidence |
| GBF-304 | M3 | 统一 session/checkpoint/resume/cancel | GBF-302 | crash/resume/cancel 语义唯一 | fault/recovery integration | evidence/GBF-304 | TESTED | post-main closure records stale | verify canonical main + delivery evidence |
| GBF-305 | M3 | 统一 local exec | GBF-303 | 无绕过 capability gate 的执行口 | deny-path + code-path audit | evidence/GBF-305 | TESTED | post-main closure records stale | verify canonical main + delivery evidence |
| GBF-306 | M3 | 统一错误/重试/超时/并发 | GBF-303..305 | 行为确定且可取消 | deterministic integration suite | evidence/GBF-306 | TESTED | post-main closure records stale | verify canonical main + delivery evidence |
| GBF-307 | M3 | Mahayana provider Router 与就绪诊断 | GBF-106,302,303 | Fabushi/Codex/Claude/OpenRouter 共用单一 runtime/policy | provider contract + integration + packaged E2E | evidence/GBF-307 | RELEASED | none | GBF-805 final parity closure |
| GBF-308 | M3 | routed transcript/MCP/usage 连续性 | GBF-307 | provider 切换不破坏 transcript/tool/usage/approval | transcript + MCP + usage integration | evidence/GBF-308 | RELEASED | none | GBF-805 final parity closure |
| GBF-401 | M4 | 定义 computer-control capability schema | GBF-204,305 | versioned target-bound contract | schema/threat review | evidence/GBF-401 | TESTED | post-main closure records stale | current-main target/replay regression |
| GBF-402 | M4 | 实现/验证 macOS adapter | GBF-401 | observe/input/window 能力受控 | macOS E2E | evidence/GBF-402 | TESTED | post-main closure records stale | current-main macOS computer E2E |
| GBF-403 | M4 | 实现/验证 Windows adapter | GBF-401 | observe/input/window 能力受控 | Windows E2E | evidence/GBF-403 | TESTED | post-main closure records stale | current-main Windows computer E2E |
| GBF-404 | M4 | 实现/验证 Linux adapter | GBF-401 | X11/Wayland 能力与降级明确 | Linux E2E | evidence/GBF-404 | TESTED | post-main closure records stale | current-main Linux X11/Wayland E2E |
| GBF-405 | M4 | 浏览器标签页级控制 | GBF-401 | 控制目标 tab 不干扰其它 tab | browser isolation E2E | evidence/GBF-405 | TESTED | post-main closure records stale | current-main browser isolation E2E |
| GBF-406 | M4 | 敏感输入一次性安全通道 | GBF-401 | approve/deny/expire/replay 安全 | security E2E | evidence/GBF-406 | TESTED | post-main closure records stale | current-main sensitive-input security E2E |
| GBF-407 | M4 | computer-control crash/reconnect | GBF-402..406 | 恢复无重复副作用 | fault/idempotency E2E | evidence/GBF-407 | TESTED | post-main closure records stale | current-main reconnect/replay E2E |
| GBF-408 | M4 | 本地容器执行环境 | GBF-106,401,407 | network-none/owner-labelled/digest-pinned/rebuild-safe | container lifecycle security + packaged E2E | evidence/GBF-408 | RELEASED | none | GBF-805 final parity closure |
| GBF-409 | M4 | 全平台账号绑定电脑发现、人工/AI 远控与内置 Computer Use | GBF-401..407 | presence/control 分离；完整私有 MCP；Bot/移动入口；精确 main package/E2E/Release | security + cross-platform packaged user journeys | evidence/GBF-409 | IN_PROGRESS | code review/PR/CI/release pending | 修复策略路径与 fail-closed 后提交 PR |
| GBF-501 | M5 | Grok UI/交互能力盘点 | GBF-103 | UI 能力 100% 有保留/重写/废弃决策 | parity table review + packaged UI contract | evidence/GBF-501 | IN_PROGRESS | current motion/screenshot round pending | merge #2102, inspect packaged visual evidence |
| GBF-502 | M5 | Fabushi 动态头像语义状态机 | GBF-501 | idle/listening/thinking/tool/speaking/result/error | state contract tests | evidence/GBF-502 | TESTED | post-main closure records stale | consume current runtime states in parity surface |
| GBF-503 | M5 | 动画 timeline/composition engine | GBF-502 | 可组合可确定渲染 | deterministic animation tests | evidence/GBF-503 | TESTED | parity tuning in progress | Grok state choreography + screenshot tuning |
| GBF-504 | M5 | 动画性能与无障碍 | GBF-503 | offscreen/reduced-motion/预算可验证 | perf + accessibility tests | evidence/GBF-504 | TESTED | post-main closure records stale | verify current-main motion/energy regression |
| GBF-505 | M5 | 移除生产 Grok 视觉/runtime 依赖 | GBF-501..504 | production dependency audit clean | dependency/source audit | evidence/GBF-505 | TESTED | final provenance audit pending | keep all parity code Fabushi-owned |
| GBF-506 | M5 | Router/usage/local sandbox 设置 parity | GBF-106,307,308,408 | 设置布局、持久化、状态和错误反馈与基准等效 | packaged screenshot/video/trace E2E | evidence/GBF-506 | RELEASED | none | GBF-805 final parity closure |
| GBF-507 | M5 | Mahayana Agent Workbench 与实时动态头像 | GBF-302,501,502 | Bot 多步骤、步骤/工具/审批/结果可见；头像随真实运行状态变化；运行日志重启可恢复 | renderer contract + real Rust Host restart journey + packaged visual E2E + Release | evidence/GBF-507 | RELEASED | none | GBF-601/602 Rust canonical store/recovery; GBF-805 final parity closure |
| GBF-601 | M6 | canonical data model 映射 | GBF-104,302 | 无长期重复会话/tool/permission model | schema review/migration test | evidence/GBF-601 | IN_PROGRESS | GBF-507 renderer projection released; Rust canonical store migration pending | map Workbench run projection to Rust store |
| GBF-602 | M6 | crash/restart 恢复 | GBF-304,601 | 关键状态可恢复且无重复副作用 | fault injection | evidence/GBF-602 | IN_PROGRESS | local journal is conservative cache, not canonical runtime recovery | implement Rust checkpoint/resume matrix |
| GBF-603 | M6 | 统一 correlation/structured logging | GBF-203,303 | renderer->tool 链路可追踪且无秘密 | trace assertions/log audit | evidence/GBF-603 | NOT_STARTED | runtime | 统一 event fields |
| GBF-604 | M6 | 性能基线与 regression gate | GBF-207,407,504 | 真实 baseline 固化并可阻止严重回归 | benchmark + CI gate | evidence/GBF-604 | NOT_STARTED | feature E2E | 收集 baseline |
| GBF-701 | M7 | IPC/host threat model | GBF-201..205 | 威胁/缓解/残余风险齐全 | security review | evidence/GBF-701 | NOT_STARTED | M4 closure evidence stale | 建 threat inventory |
| GBF-702 | M7 | 权限/拒绝路径安全测试 | GBF-401..407,701 | high-risk denial suite green | security test suite | evidence/GBF-702 | NOT_STARTED | M4/M7 | 扩充安全用例 |
| GBF-703 | M7 | 来源/许可证阻塞清零 | GBF-105 + impl | retained source blocking=0 | provenance audit | evidence/GBF-703 | NOT_STARTED | GBF-105 | 审查每个迁移 PR |
| GBF-704 | M7 | secret/log/privacy 审计 | GBF-603,702 | 无秘密泄漏/多余持久化 | log/privacy tests | evidence/GBF-704 | NOT_STARTED | GBF-603/702 | 扫描 telemetry |
| GBF-705 | M7 | SecretRef 凭据保险库与最后一跳注入 | GBF-303,406,704 | 密钥不进入模型/Renderer；仅向显式绑定 HTTPS 目标注入；支持轮换/撤销/元数据审计 | credential gateway unit/security + edge parity + packaged E2E + privacy scan | evidence/GBF-705 | IN_PROGRESS | PR/CI/package/main closure pending | 完成 Agent/Connector 复用入口并通过正式门禁 |
| GBF-801 | M8 | 全平台回归 | M2..M7 | affected suites 全绿 | CI + platform E2E | evidence/GBF-801 | NOT_STARTED | M2-M7 | 启动 release candidate |
| GBF-802 | M8 | 灰度与回滚演练 | GBF-801 | rollback 在目标环境验证 | runbook drill | evidence/GBF-802 | NOT_STARTED | GBF-801 | 执行回滚演练 |
| GBF-803 | M8 | 正式发布 | GBF-801,802 | release/post-release smoke 通过 | GitHub release/deploy evidence | evidence/GBF-803 | NOT_STARTED | GBF-802 | 发布目标版本 |
| GBF-804 | M8 | 历史 Grok 分支归档决策 | GBF-703,803 | 分支不再是运行权威；ADR 完成 | branch/ref audit + ADR | evidence/GBF-804 | NOT_STARTED | GBF-803 | archive/retain policy |
| GBF-805 | M8 | 0.18 reconstructed observable parity closure | GBF-106,307,308,408,506,801..804 | capability matrix 无未实现/未决项 | packaged cross-platform journeys + visual diff + Release | evidence/GBF-805 | NOT_STARTED | downstream tasks | 完成后逐项关闭 parity matrix |
