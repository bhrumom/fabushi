# Mahayana 独立产品内核与能力融合

## 目标

Mahayana 不是 Codex 或 Grok Build 的品牌替换层。产品长期目标是拥有自己的：

- 稳定产品协议与会话身份；
- 任务/目标状态机、恢复语义与客观验收门；
- 权限、工具、沙箱与审计模型；
- 模型/供应商无关的 Agent Backend 接口；
- 工作区、检查点、并行代理、MCP/Skills/Plugins/Hooks 等扩展边界；
- Desktop、Mobile、Web、Headless/CI 共用的 Runtime 行为。

Codex 与 Grok Build 都作为经过审计的能力来源和兼容适配器，而不是 Mahayana 的产品身份或核心协议拥有者。

## 两个上游的能力取舍

### OpenAI Codex 值得保留的优势

- 成熟的线程/turn 协议以及流式事件模型；
- App Server / 客户端协议边界，适合桌面端、IDE、远程客户端；
- 沙箱、审批、可信项目与权限模式；
- MCP、Skills、插件与多智能体能力；
- 上下文窗口、compaction、resume、usage 等长会话语义；
- 跨平台 Rust 运行时与完善测试面。

局限：Mahayana 当前大量直接 path dependency 指向 `codex-rs`，并且公共产品契约仍出现 `CodexAi`、`codex:*` 等身份。只要这些仍是产品主协议，Mahayana 就仍然是以 Codex 为中心的派生架构。

### xAI Grok Build 值得吸收的优势

- `/goal` 一类面向目标的长期任务执行与客观 oracle 验证；
- attempt journal、任务恢复、暂停/恢复与后台任务管理；
- 更完整的工作树、checkpoint 和 workspace 生命周期；
- 对重复/相同工具调用循环的提前预警与熔断；
- 会话级权限记忆以及持久 `Never allow`；
- TUI、Headless/CI、ACP 等多入口体验；
- hooks、plugins、skills、自定义模型、主题等产品化扩展体验。

局限：Grok Build 自身也包含从 Codex/OpenCode 等项目移植的代码，因此不能把整个代码树再次复制后仅做重命名；需要按来源保留许可证与 notice，并把能力重构成 Mahayana 自己的协议和状态机。

## Mahayana 自主内核原则

### 1. Kernel 不依赖供应商协议

`mahayana-core` / 后续独立 `mahayana-kernel` 只能依赖 Mahayana 自己的稳定数据结构。不得在 Kernel API 中暴露 `codex_*`、`grok_*` 或供应商 SDK 类型。

### 2. Provider/Adapter 负责翻译

OpenAI、xAI、Responses API、本地模型或以后新增的 Provider 都通过 Adapter 实现 Mahayana `AgentBackend`/Tool/Workspace 协议。上游变化不应直接改变 Mahayana 公共 ABI。

### 3. 产品身份统一为 Mahayana

现有兼容身份如 `codex:agent:assistant`、`PeerKind::CodexAi`、provider key `codex` 必须逐步迁移到 Mahayana 自有命名。旧标识在兼容窗口内只作为 legacy alias 读取，不再作为新数据写入。

### 4. “任务完成”必须有证据

长期任务默认采用 objective-required verification。需要的测试、CI check、命令、artifact 或人工验收未通过时，状态机不得进入 `Succeeded`。

### 5. 权限与安全是 Kernel 能力

权限模式、一次允许、会话允许、一次拒绝、永久拒绝属于 Mahayana 自己的策略；具体 shell/MCP/web/电脑操作只提交风险分类和目标，由 Kernel 决策。

### 6. 可恢复执行是一等能力

每次尝试具有稳定 attempt id、sequence、fingerprint、起止时间和 outcome。输入保留来源（user/steer/queued/resume/automation/agent），compaction 更换 context-window identity，任务可以 paused/resumed。

### 7. 防循环不是 UI 补丁

相同 action fingerprint 连续出现时，Kernel 按双阈值先警告后中断，避免代理在 shell、MCP 或电脑操作中形成不可控循环。

## 第一阶段已经落地

`mahayana-core::capability::kernel` 现在定义了不引用 Codex/Grok 类型的第一批自主原语：

- `PermissionMode` / `PermissionBook` / `DenyAlways`；
- `InputEnvelope` / `InputOrigin` / steer-first queue；
- `ContextWindow` identity + compaction generation；
- `BackendCapabilities`；
- `TaskState` / `TaskSupervisor`；
- `VerificationOracle` / objective-required completion gate；
- `AttemptRecord` / `AttemptOutcome`；
- `LoopPolicy` / repeated-action warn + interrupt。

这一阶段刻意不修改现有 wire ABI，也不更换 Cargo workspace lock，便于先由现有 Mahayana CI 验证新内核，再做身份与 Adapter 迁移。

## 后续迁移阶段

1. **Identity/Protocol**：建立 `mahayana-agent:*` 等 canonical ID，并给旧 `codex:*` 增加只读兼容 alias；把 `PeerKind::CodexAi` 改为供应商中立的 `Agent`。
2. **Adapter boundary**：把直接 Codex 类型限制在兼容 adapter，Runtime/Core 只看 Mahayana 类型；为不同模型后端提供 capability negotiation。
3. **Workspace engine**：统一 filesystem/VCS/process/checkpoint/worktree/sandbox 能力，吸收 Grok Build 的恢复与安全经验。
4. **Goal engine**：把 Kernel task/oracle/attempt 接入真实 agent turn、subagent、CI evidence 和 resume。
5. **Extension plane**：统一 MCP、Skills、Plugins、Hooks、Mini Apps，权限与 entitlement 走 Mahayana policy。
6. **Interfaces**：CLI/TUI、Electron、原生移动端、Web、Headless、IDE/ACP 使用同一 Mahayana Runtime 协议。
7. **Upstream isolation**：逐步减少 `mahayana-rs/Cargo.toml` 的直接 `codex-*` workspace dependencies；任何保留代码都进入明确 adapter/vendor 边界。
8. **Independent acceptance**：核心测试在不启用 Codex adapter 或 Grok adapter 的情况下仍可编译和通过；至少一个非 Codex backend 完成端到端消息、工具、审批、任务恢复与 objective verification。

## 许可证和来源

Codex 与 Grok Build 的第一方公开代码目前均采用 Apache-2.0；Grok Build 还列有其自身移植/第三方来源。Mahayana 的“独立”是产品架构、协议、状态机与演进权独立，不是删除上游 attribution。

任何直接保留或移植的代码都必须：

- 保留适用的 Apache-2.0 LICENSE/NOTICE；
- 保留第三方 notices 和必要的修改说明；
- 记录来源 commit 与后续修改；
- 能重新实现的产品层逻辑优先按 Mahayana 自有 contract 重写，而不是复制后换名。

这使 Mahayana 可以真正自主演进，同时合法吸收两个成熟项目的工程经验。
