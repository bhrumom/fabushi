# 01 WBS 原子任务

状态只使用 `NOT_STARTED / IN_PROGRESS / IMPLEMENTED / TESTED / E2E_VERIFIED / RELEASED`。

| ID | Stage | Atomic task | Acceptance | Status |
|---|---|---|---|---|
| GBF-001 | M0 | 建立完整项目治理基线 | 项目必备文档存在；PR/CI/main 证据回写 | IN_PROGRESS |
| GBF-101 | M1 | 固定 source branch 与 main 基线 commit | evidence 记录三个 ref/commit | NOT_STARTED |
| GBF-102 | M1 | 递归生成来源文件 manifest | 所有来源文件有 path/hash/type | NOT_STARTED |
| GBF-103 | M1 | 建立功能能力矩阵 | 所有关键文件映射至少一个能力域 | NOT_STARTED |
| GBF-104 | M1 | 建立 main/source 差异矩阵 | 每项标记 MAIN_HAS/SOURCE_BETTER/MAIN_SUPERSEDES/MIGRATE_REWRITE/DEPRECATE/PROVENANCE_BLOCKED | NOT_STARTED |
| GBF-105 | M1 | 建立 provenance ledger | 每类来源有许可/授权/处理决策 | NOT_STARTED |
| GBF-201 | M2 | 审计 Electron `main.cjs` | IPC/窗口/生命周期差异清单与目标 PR | NOT_STARTED |
| GBF-202 | M2 | 审计 `preload.cjs` 和 IPC contract | 无通用 IPC 暴露；contract test | NOT_STARTED |
| GBF-203 | M2 | 收敛 `host-process.cjs` | 单一 host lifecycle/health/restart | NOT_STARTED |
| GBF-204 | M2 | 收敛 native capability handlers | capability allow/deny tests | NOT_STARTED |
| GBF-205 | M2 | 收敛 native/edge IPC | 版本化 schema + error contract | NOT_STARTED |
| GBF-206 | M2 | 评估并迁移 Offline ASR | 功能/性能/资源证据与产品归属 | NOT_STARTED |
| GBF-207 | M2 | 迁移来源分支有效 Electron E2E | E2E 在当前 main 架构运行 | NOT_STARTED |
| GBF-301 | M3 | 盘点 coordinator/supervisor/host 行为 | 行为规格与重复链清单 | NOT_STARTED |
| GBF-302 | M3 | 统一 Agent loop 到 Mahayana | 单一正式 agent runtime | NOT_STARTED |
| GBF-303 | M3 | 统一 tool/MCP/extension dispatch | 同一权限与结果 contract | NOT_STARTED |
| GBF-304 | M3 | 统一 session/checkpoint/resume/cancel | crash/resume 集成测试 | NOT_STARTED |
| GBF-305 | M3 | 统一 local exec | 无绕过 capability gate 的执行口 | NOT_STARTED |
| GBF-306 | M3 | 统一错误/重试/超时/并发 | deterministic integration tests | NOT_STARTED |
| GBF-401 | M4 | 定义 computer-control capability schema | versioned contract + threat model | NOT_STARTED |
| GBF-402 | M4 | macOS adapter | observe/input/window E2E | NOT_STARTED |
| GBF-403 | M4 | Windows adapter | observe/input/window E2E | NOT_STARTED |
| GBF-404 | M4 | Linux adapter | X11/Wayland 能力与降级 E2E | NOT_STARTED |
| GBF-405 | M4 | 浏览器标签页级控制 | 目标 tab 隔离 E2E | NOT_STARTED |
| GBF-406 | M4 | 敏感输入安全通道 | approve/deny/expire/replay tests | NOT_STARTED |
| GBF-407 | M4 | computer-control recovery | crash/reconnect/idempotency E2E | NOT_STARTED |
| GBF-501 | M5 | Grok UI/交互能力盘点 | feature parity table | NOT_STARTED |
| GBF-502 | M5 | 实现 Fabushi 动态头像状态机 | semantic state contract tests | NOT_STARTED |
| GBF-503 | M5 | 实现动画 timeline/composition engine | deterministic animation tests | NOT_STARTED |
| GBF-504 | M5 | 动画性能/无障碍 | frame budget + reduced-motion evidence | NOT_STARTED |
| GBF-505 | M5 | 移除运行时 Grok 视觉依赖 | production dependency audit clean | NOT_STARTED |
| GBF-601 | M6 | canonical data model 映射 | schema/migration spec | NOT_STARTED |
| GBF-602 | M6 | crash/restart 恢复 | fault-injection tests | NOT_STARTED |
| GBF-603 | M6 | 统一 correlation/structured logging | trace 跨层贯通 | NOT_STARTED |
| GBF-604 | M6 | 性能基线与 regression gate | baseline report + CI threshold | NOT_STARTED |
| GBF-701 | M7 | IPC/host threat model | STRIDE-like review + mitigations | NOT_STARTED |
| GBF-702 | M7 | 权限/拒绝路径安全测试 | high-risk denial suite green | NOT_STARTED |
| GBF-703 | M7 | 来源/许可证阻塞清零 | provenance ledger 无未处理 blocking | NOT_STARTED |
| GBF-704 | M7 | secret/log/privacy 审计 | 无凭证泄漏/多余持久化 | NOT_STARTED |
| GBF-801 | M8 | 全平台回归 | affected desktop/native suites green | NOT_STARTED |
| GBF-802 | M8 | 灰度/回滚演练 | rollback evidence | NOT_STARTED |
| GBF-803 | M8 | 正式发布 | release evidence | NOT_STARTED |
| GBF-804 | M8 | 历史 Grok 分支归档决策 | ADR + branch policy | NOT_STARTED |
