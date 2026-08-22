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
| GBF-201 | M2 | 审计 Electron main.cjs | GBF-104 | 生命周期/IPC 独有差异有决策 | file/behavior diff review | evidence/GBF-201 | TESTED | GitHub CI/merge pending | PR + Actions + merge queue |
| GBF-202 | M2 | 收敛 preload/IPC contract | GBF-201 | 无通用 IPC；版本化 contract | allow/deny contract tests | evidence/GBF-202 | TESTED | GitHub CI/merge pending | PR + Actions + merge queue |
| GBF-203 | M2 | 收敛 host-process | GBF-201 | 单一 host lifecycle/health/restart | host integration/fault tests | evidence/GBF-203 | TESTED | GitHub CI/merge pending | PR + Actions + merge queue |
| GBF-204 | M2 | 收敛 native capability handlers | GBF-202,203 | 所有高风险 handler 过 gate | capability unit/security tests | evidence/GBF-204 | TESTED | GitHub CI/merge pending | PR + Actions + merge queue |
| GBF-205 | M2 | 收敛 native/edge IPC | GBF-202 | schema/error contract 唯一 | schema/version tests | evidence/GBF-205 | TESTED | GitHub CI/merge pending | PR + Actions + merge queue |
| GBF-206 | M2 | 评估并迁移 Offline ASR | GBF-104 | 产品归属、资源/性能证据清晰 | unit + runtime benchmark | evidence/GBF-206 | TESTED | GitHub CI/merge pending | PR + Actions + merge queue |
| GBF-207 | M2 | 迁移有效 Electron E2E | GBF-201..206 | 当前 main 架构可运行 | Playwright/Electron E2E | evidence/GBF-207 | IN_PROGRESS | GitHub packaged E2E pending | PR + Electron Actions/Playwright |
| GBF-301 | M3 | 盘点 coordinator/supervisor/host 行为 | GBF-103,104 | 重复执行链全部识别 | architecture walk + call graph | evidence/GBF-301 | TESTED | GitHub CI/merge pending | stacked PR + Mahayana/CI gates |
| GBF-302 | M3 | 统一 Agent loop 到 Mahayana | GBF-301 | 唯一正式 agent runtime | integration/call-path tests | evidence/GBF-302 | TESTED | GitHub CI/merge pending | stacked PR + Mahayana/CI gates |
| GBF-303 | M3 | 统一 tool/MCP/extension dispatch | GBF-302 | 同一 policy/result contract | contract + integration tests | evidence/GBF-303 | TESTED | GitHub CI/merge pending | stacked PR + Mahayana/CI gates |
| GBF-304 | M3 | 统一 session/checkpoint/resume/cancel | GBF-302 | crash/resume/cancel 语义唯一 | fault/recovery integration | evidence/GBF-304 | TESTED | GitHub CI/merge pending | stacked PR + Mahayana/CI gates |
| GBF-305 | M3 | 统一 local exec | GBF-303 | 无绕过 capability gate 的执行口 | deny-path + code-path audit | evidence/GBF-305 | TESTED | GitHub CI/merge pending | stacked PR + Mahayana/CI gates |
| GBF-306 | M3 | 统一错误/重试/超时/并发 | GBF-303..305 | 行为确定且可取消 | deterministic integration suite | evidence/GBF-306 | TESTED | GitHub CI/merge pending | stacked PR + Mahayana/CI gates |
| GBF-401 | M4 | 定义 computer-control capability schema | GBF-204,305 | versioned target-bound contract | schema/threat review | evidence/GBF-401 | TESTED | cross-platform CI/merge pending | stacked PR + platform matrix |
| GBF-402 | M4 | 实现/验证 macOS adapter | GBF-401 | observe/input/window 能力受控 | macOS E2E | evidence/GBF-402 | IMPLEMENTED | target-platform CI pending | macOS/Windows/Linux matrix |
| GBF-403 | M4 | 实现/验证 Windows adapter | GBF-401 | observe/input/window 能力受控 | Windows E2E | evidence/GBF-403 | IMPLEMENTED | target-platform CI pending | macOS/Windows/Linux matrix |
| GBF-404 | M4 | 实现/验证 Linux adapter | GBF-401 | X11/Wayland 能力与降级明确 | Linux E2E | evidence/GBF-404 | IMPLEMENTED | target-platform CI pending | macOS/Windows/Linux matrix |
| GBF-405 | M4 | 浏览器标签页级控制 | GBF-401 | 控制目标 tab 不干扰其它 tab | browser isolation E2E | evidence/GBF-405 | TESTED | cross-platform CI/merge pending | stacked PR + platform matrix |
| GBF-406 | M4 | 敏感输入一次性安全通道 | GBF-401 | approve/deny/expire/replay 安全 | security E2E | evidence/GBF-406 | TESTED | cross-platform CI/merge pending | stacked PR + platform matrix |
| GBF-407 | M4 | computer-control crash/reconnect | GBF-402..406 | 恢复无重复副作用 | fault/idempotency E2E | evidence/GBF-407 | TESTED | cross-platform CI/merge pending | stacked PR + platform matrix |
| GBF-501 | M5 | Grok UI/交互能力盘点 | GBF-103 | UI 能力 100% 有保留/重写/废弃决策 | parity table review | evidence/GBF-501 | TESTED | frontend CI/merge pending | avatar PR + frontend gates |
| GBF-502 | M5 | Fabushi 动态头像语义状态机 | GBF-501 | idle/listening/thinking/tool/speaking/result/error | state contract tests | evidence/GBF-502 | TESTED | frontend CI/merge pending | avatar PR + frontend gates |
| GBF-503 | M5 | 动画 timeline/composition engine | GBF-502 | 可组合可确定渲染 | deterministic animation tests | evidence/GBF-503 | TESTED | frontend CI/merge pending | avatar PR + frontend gates |
| GBF-504 | M5 | 动画性能与无障碍 | GBF-503 | offscreen/reduced-motion/预算可验证 | perf + accessibility tests | evidence/GBF-504 | TESTED | frontend CI/merge pending | avatar PR + frontend gates |
| GBF-505 | M5 | 移除生产 Grok 视觉/runtime 依赖 | GBF-501..504 | production dependency audit clean | dependency/source audit | evidence/GBF-505 | TESTED | frontend CI/merge pending | avatar PR + frontend gates |
| GBF-601 | M6 | canonical data model 映射 | GBF-104,302 | 无长期重复会话/tool/permission model | schema review/migration test | evidence/GBF-601 | TESTED | CI/merge pending | M6 PR + benchmark/contract gates |
| GBF-602 | M6 | crash/restart 恢复 | GBF-304,601 | 关键状态可恢复且无重复副作用 | fault injection | evidence/GBF-602 | TESTED | CI/merge pending | M6 PR + benchmark/contract gates |
| GBF-603 | M6 | 统一 correlation/structured logging | GBF-203,303 | renderer->tool 链路可追踪且无秘密 | trace assertions/log audit | evidence/GBF-603 | TESTED | CI/merge pending | M6 PR + benchmark/contract gates |
| GBF-604 | M6 | 性能基线与 regression gate | GBF-207,407,504 | 真实 baseline 固化并可阻止严重回归 | benchmark + CI gate | evidence/GBF-604 | TESTED | CI/merge pending | M6 PR + benchmark/contract gates |
| GBF-701 | M7 | IPC/host threat model | GBF-201..205 | 威胁/缓解/残余风险齐全 | security review + closure validator | evidence/GBF-701 | TESTED | GitHub CI/merge pending | M7 security PR + Actions |
| GBF-702 | M7 | 权限/拒绝路径安全测试 | GBF-401..407,701 | high-risk denial suite green | security test suite | evidence/GBF-702 | TESTED | GitHub CI/merge pending | M7 security PR + Actions |
| GBF-703 | M7 | 来源/许可证阻塞清零 | GBF-105 + impl | retained production source blocking=0; historical ambiguous source remains reference-only | provenance audit | evidence/GBF-703 | TESTED | GitHub CI/merge pending | M7 provenance gate + Actions |
| GBF-704 | M7 | secret/log/privacy 审计 | GBF-603,702 | 无秘密泄漏/多余持久化 | log/privacy tests + closure validator | evidence/GBF-704 | TESTED | GitHub CI/merge pending | M7 security PR + Actions |
| GBF-801 | M8 | 全平台回归 | M2..M7 | affected suites 全绿 | CI + platform E2E | evidence/GBF-801 | NOT_STARTED | M2-M7 | 启动 release candidate |
| GBF-802 | M8 | 灰度与回滚演练 | GBF-801 | rollback 在目标环境验证 | runbook drill | evidence/GBF-802 | NOT_STARTED | GBF-801 | 执行回滚演练 |
| GBF-803 | M8 | 正式发布 | GBF-801,802 | release/post-release smoke 通过 | GitHub release/deploy evidence | evidence/GBF-803 | NOT_STARTED | GBF-802 | 发布目标版本 |
| GBF-804 | M8 | 历史 Grok 分支归档决策 | GBF-703,803 | 分支不再是运行权威；ADR 完成 | branch/ref audit + ADR | evidence/GBF-804 | NOT_STARTED | GBF-803 | archive/retain policy |
