# 小程序插件与大乘 CLI 一体化架构设计与需求文档 (PRD)

## 1. 核心理念与架构愿景

在现有插件体系与大乘 CLI 的基础上，引入**“插件即 CLI，CLI 即插件 (Plugin-as-a-CLI)”**的第一性原理架构：
每一个小程序/插件（如全球法布施 `global-dharma`、法流记忆卡 `faliu-flashcards`、Hermes 安装器等）在底层都设计与编译为一个**独立、跨端可运行的统一命令行工具（Unified CLI Binary / Module）**。

### 1.1 核心指导原则
1. **统一自包含与多端编译 (Cross-Platform CLI Core)**：
   每个插件工程的核心业务逻辑封装为统一 CLI（例如 `global-dharma-cli`），通过 Rust / 跨平台工具链编译为能够运行在所有终端的产物（桌面 macOS/Windows/Linux 可执行文件、移动端嵌入式模块/FFI、命令行二进制）。
2. **本地高效运行优先 (Local-First High Efficiency)**：
   - CLI 本身集成了该插件的所有子命令（如 `status`, `loop`, `send`, `validate`）与 MCP Tool 服务模式（如 `mcp-serve`）。
   - 当大乘宿主（命令行、桌面端或App）运行插件指令或小程序会话时，**优先直接调用本地 CLI 进程/标准 IO (stdio)**。本地执行具备**零网络延迟、秒级响应、原生性能与高并发吞吐**的极高效率。
3. **非本地自动降级云端 MCP 链接 (Cloud MCP Fallback when Non-Local)**：
   - **只有当非本地运行时**（例如在 Web 端浏览器环境中缺少本地二进制、或移动端精简包未打包该插件、或需调用云端专有资源时），系统才会自动将通信链路通过 MCP (HTTP/SSE) 连接到云端端点（`https://api.ombhrum.com/api/mcp/apps/<plugin-id>`）。
   - 降级对上层交互与小程序界面完全透明，并自动透传宿主的主会话授权 Token。

---

## 2. 第一性原理剖析：插件即 CLI (Plugin-as-a-CLI)

```
                       ┌──────────────────────────────────────────────┐
                       │     Mini-App / Plugin Unified CLI Binary     │
                       │     (e.g., `global-dharma-cli`)              │
                       ├──────────────────────────────────────────────┤
                       │  ├─ --dump-manifest (动态导出指令清单与描述)   │
                       │  ├─ status | loop | send | start (命令行直调)  │
                       │  └─ mcp-serve (以 stdio MCP JSON-RPC 为 AI 运行)│
                       └──────────────────────┬───────────────────────┘
                                              │
                     ┌────────────────────────┴────────────────────────┐
                     ▼                                                 ▼
        【本地运行模式 (Local-First)】                         【非本地 / 云端模式 (Cloud Fallback)】
  运行于 Desktop / CLI / Mobile (具备二进制)                 运行于 Web / 精简端 / 远程资源
  ┌──────────────────────────────────────────────┐       ┌──────────────────────────────────────────────┐
  │ Mahayana Host 直接通过 Process/stdio 调用    │       │ Mahayana Host 通过 HTTP/SSE 连接云端 API       │
  │ ⚡ 零网络消耗、本地文件系统访问、超高执行效率  │       │ ☁️ https://api.ombhrum.com/api/mcp/apps/*     │
  │ ⚡ 支持原生命令直调：`mahayana dharma status`  │       │ 🔐 Header 自动注入：Authorization: Bearer <token> │
  └──────────────────────────────────────────────┘       └──────────────────────────────────────────────┘
```

---

## 3. 详细融合方案设计

### 3.1 改造一：插件 CLI 结构标准化与双态行为规范
所有小程序插件在代码仓库中建立标准的 CLI 出口（以 `global-dharma` 为样板）：
1. **多模式启动参数解析**：
   - **直接命令模式 (Human/Host Command Mode)**：如执行 `global-dharma-cli status` 或 `global-dharma-cli send --content "法流"`，直接以结构化文本或 JSON stdout 返回结果。
   - **自描述元数据模式 (Self-Introspection Mode)**：支持 `global-dharma-cli --dump-manifest`，输出标准的 `.codex-plugin` 和 `.mahayana` 合并 JSON 清单。
   - **MCP 服务模式 (Agent/LLM MCP Mode)**：支持 `global-dharma-cli mcp-serve`，通过标准输入输出（`stdio`）按照 MCP `2025-06-18` 协议处理 `tools/list` 与 `tools/call`。
2. **多端产物编译整合**：
   - 结合 CI 流程，将各插件 CLI 构建为跨平台的轻量可执行文件或通过 `mahayana-ffi` 挂载，使其能在各个宿主环境中被发现与调用。

### 3.2 改造二：大乘 CLI (`mahayana-cli`) 原生指令映射与透传
在 `mahayana-cli/src/main.rs` 及相关路由模块中建立**动态命令映射器 (Dynamic CLI Projection Engine)**：
* **启动自动探测与发现**：
  在 `mahayana-cli` 启动时，扫描本地插件目录及 `discover_mini_apps()` 列表。若本地存在可执行的 `plugin-cli`，直接调用其 `--dump-manifest` 缓存指令集。
* **命令行别名直接展开**：
  支持用户直接在终端输入像原生 CLI 一样的指令。例如：
  - 用户输入 `mahayana global-dharma status` 或别名 `mahayana dharma status`
  - CLI 内部判断：本地是否有 `global-dharma-cli`？
    - **有 (本地运行)**：立即 fork / spawn 执行 `global-dharma-cli status`，毫秒级并高效返回结果。
    - **无 (非本地运行)**：自动通过 `MahayanaProductClient` 发起对云端 `/api/mcp/apps/global-dharma` 的 HTTP RPC 工具调用。

### 3.3 改造三：运行时选型引擎增强 (`mahayana-plugin-host` & `mahayana-agent`)
当 AI 小程序或 Codex 需以 MCP 协议操作插件时（即调用 `open_mcp_app`）：
* **智能自适应决策规则 (`select_runtime`)**：
  ```rust
  // 1. 优先检查本地高优先级 stdio (本地 CLI 模式)
  if let Some(local_cli_path) = find_local_plugin_cli(&plugin.id) {
      if is_executable_and_ready(&local_cli_path) {
          // 本地存在，走高效 stdio MCP 进程通信
          return Ok(SelectedRuntime::LocalStdio(local_cli_path));
      }
  }
  // 2. 本地不存在或为非本地宿主（如 Web / 需云端授权），走 HTTP 云端连接
  return Ok(SelectedRuntime::CloudHttp(plugin.http_endpoint));
  ```
* **云端链路鉴权透传**：
  一旦决定降级进入云端连接，系统自动提取当前大乘宿主的 `Session Token`，并在 HTTP Header 追加：
  `Authorization: Bearer <host_session_token>`
  从而保证非本地运行同样安全、闭环并精确绑定用户租户。

---

## 4. 在现有基础上的具体演进路线 (Roadmap)

我们将本着**KISS 原则**，在不破坏现有业务的前提下分阶段将该架构落地：

| 阶段 | 任务模块 | 核心工作内容 |
| :--- | :--- | :--- |
| **阶段一** | **统一插件 CLI 结构标准化（样板工程与规范）** | 1. 优化 `native/global-dharma/crates/` 下的 `global-dharmactl` 与 `global-dharma-mcp` 统一为一个标准的自描述 `global-dharma-cli`；<br>2. 实现 `--dump-manifest`、子命令直调与 `mcp-serve` 模式；作为后续所有小程序 CLI 的标杆。 |
| **阶段二** | **`mahayana-plugin-host` 双态自适应引擎升级** | 1. 在 `select_runtime` 与 `LocalPlugin` 中增加本地可执行文件 (`plugin-cli`) 的自动探测逻辑；<br>2. 确立“优先本地 CLI stdio 极速运行，非本地自动降级云端 HTTP MCP”的无缝切换规则。 |
| **阶段三** | **`mahayana-cli` 原生动态命令映射与执行重构** | 1. 彻底改造 `mahayana plugin run/info` 等短命令，使其能将插件 CLI 指令映射为顶级/二级 CLI 命令；<br>2. 验证本地极速调起与远程云端降级调起的执行效率与结果一致性。 |
| **阶段四** | **云端降级链路宿主授权闭环** | 对接 `official_mcp_apps.js` 验证从 CLI 降级发起 HTTP 调用时的 `Authorization: Bearer` Token 透传及租户会话隔离。 |

---

## 5. 验证与测试标准

1. **执行效率对比验证**：
   - 本地运行模式下，通过命令行调用 `mahayana dharma status`（触发本地 CLI 进程）的时间消耗需在数十毫秒以内，无网络吞吐。
2. **自动化契约与单元测试**：
   - 运行 Rust CLI 与插件选型用例：
     ```bash
     cargo nextest run --manifest-path third_party/mahayana/mahayana-rs/Cargo.toml -p mahayana-plugin-host -p mahayana-cli
     ```
   - 验证：当通过 mock 环境移除本地二进制时，系统能百分之百精准降级至云端 MCP HTTP URL；当本地二进制存在时，能百分之百优选本地 stdio 启动。

---

## 6. 提请审核 (User Review Required)

目前已根据您关于“**每个小程序都是一个多端 CLI，本地高效运行，非本地降级云端 MCP**”的核心思路，完成了上述 PRD 文档与演进路线。
请您确认本次调整后的第一性原理设计及四阶段实施路线是否完全准确；如无异议，请指示是否正式进入**任务分解（Task List）**，首先开展**阶段一：全局法布施插件 CLI 样板整合与 `--dump-manifest/mcp-serve` 标准化改造**。
