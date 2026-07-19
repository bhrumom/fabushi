# MCP 宿主授权原理与剩余上线阻塞解决方案架构 PRD

## 1. 文档背景与核心目标
本需求文档（PRD）旨在回答并规范 **MCP (Model Context Protocol) 宿主授权架构设计**，同时对系统当前剩下的 **四大核心上线阻塞（Release Blockers）** 提出基于第一性原理的系统化改造与实施构思。
严格遵守“构思方案 → 提请审核 → 分解为具体任务”的渐进式作业流程，为生产上线打下坚实的前期架构基础。

---

## 2. 核心理论剖析：MCP 是否可以实现使用“宿主授权”？

### 2.1 结论与第一性原理
**回答：完全可以，并且这是官方 MCP Authorization 规范与工程实践中最推荐的核心架构模式。**

从第一性原理出发，在 MCP 的通信体系中：
* **MCP Server（受保护资源端）**：负责暴露 Tools、Resources 与 Prompts，它必须验证调用者是否有权操作特定资源或业务身份。
* **Host Application（宿主应用 / Client，例如我们的桌面客户端、IDE、小程序代理、移动端）**：直接承载用户交互。宿主不仅负责管理本地连接，更在 OAuth 2.1 架构中扮演标准的 **OAuth Client（客户端）或安全代理（Delegate）**。

因此，MCP 使用宿主授权主要有两种标准化实施路径：

### 2.2 模式一：符合 MCP 官方 Authorization 规范（OAuth 2.1 + PKCE + 动态发现）
按照最新的官方 MCP HTTP Authorization 规范，当宿主发起 HTTP/SSE 握手而未携带凭证时：
1. **未授权挑战 (Challenge & Metadata Discovery)**：
   MCP Server 返回 `401 Unauthorized` 状态码，并在 HTTP Header 中附带：
   `WWW-Authenticate: Bearer realm="fabushi-mcp", resource_metadata="https://host/api/mcp/.well-known/oauth-protected-resource"`
2. **受保护资源元数据发现 (Protected Resource Metadata, RFC 8414 / RFC 9207)**：
   宿主读取 `.well-known/oauth-protected-resource` 元数据，获取底层的 OAuth 2.1 Authorization Server 的 Discovery URL、Token Endpoint、PKCE 要求以及客户端动态注册端点 (`client_registration_endpoint`)。
3. **宿主委托 PKCE 授权 (Host-Driven Authorization)**：
   宿主应用（作为已注册或动态注册的 OAuth Client）自动生成 `code_verifier` / `code_challenge` (PKCE RFC 7636)，调起用户交互或后台授权，换取范围受限的 `Access Token`。
4. **Token 透传调用**：
   宿主将获取的 Access Token 自动放入后续所有 MCP JSON-RPC 请求的 HTTP Header（`Authorization: Bearer <Token>`）中，完成由宿主驱动与管理的规范授权。

### 2.3 模式二：宿主直连凭证委托与令牌交换 (Pass-through Delegation & Token Exchange)
对于同域、内部网关代理或通过 IPC/进程内通信连接 MCP Server 的场景：
* **Header 透传绑定**：宿主直接在 HTTP 握手或 SSE 建立请求头中，将现有的主账户身份标识（如 `mcp-session-id`、`X-Host-Authorization` 或 Session Token）传给 MCP Server。
* **RFC 8693 Token Exchange**：若安全隔离要求更高，宿主可用已有的用户主会话 Token 到内部鉴权中心交换一个限定于 `mcp:<app_id>` 范围的专属 Token，注入给 MCP Server。

---

## 3. 剩余上线阻塞专项调研与解决方案构思

### 3.1 阻塞一：OAuth 2.1 规范授权体系规范化（去除虚假端点）
* **现状痛点**：目前 MCP HTTP 授权部分存在非规范响应或占位端点，不符合官方规范关于受保护资源（Protected Resource）必须提供授权服务器发现机制（Discovery）、PKCE 和客户端注册信息的要求。
* **解决构思**：
  1. 在 `ai-backend` 中实现并挂载符合 RFC 8414 规范的 `.well-known/oauth-protected-resource` 元数据 JSON 接口。
  2. 搭建标准 OAuth 2.1 Token 端点校验逻辑，强制校验 `PKCE (`code_challenge_method = S256`)` 与 `Resource Indicators` 范围限制。
  3. 实现客户端注册表或静态映射注册清单，支持宿主安全合规地换取合法 Bearer Token。

### 3.2 阻塞二：五个 Node HTTP MCP 插件业务持久化接入
* **现状痛点**：在 `ai-backend/src/official_mcp_apps.js` 中，目前 `global-dharma`、`faliu-flashcards`、`platform-publish`、`hermes-installer`、`bot-father`（及大乘助手）五个插件的业务逻辑与隔离状态全部依赖于内存对象 `stateByScope`（`new Map()`），一旦服务重启或进行分布式部署，所有账户隔离状态、记忆卡复习进度、发布草稿与日志均会丢失。
* **解决构思**：
  1. **存储驱动抽象**：将 `stateFor(scopeId)` 改写为异步存储适配层（或通过持久化数据库/文件引擎如 SQLite/PostgreSQL/Redis 承载）。
  2. **模块化持久接入**：
     - `global-dharma`：循环运行状态与发送日志持久化落地；
     - `faliu-flashcards`：用户专属卡组复习进度与错题库连接至数据库；
     - `platform-publish`：跨平台发布任务与草稿队列持久化；
     - `hermes-installer` 与 `bot-father`：配置参数及打包构建工单记录持久化。

### 3.3 阻塞三：真实 Codex 模型链路配置与 E2E 验证
* **现状痛点**：真实 Codex 跨端模型集成需要部署环境明确开启 `ENABLE_CODEX_SDK_CHAT=true` 环境变量，并且真实注入可用的第三方及自研大模型 API 密钥（如 DeepSeek/Claude/Gemini 等），完成从客户端发起 -> 宿主网关转译 -> Codex 实际执行的 E2E 闭环测试。
* **解决构思**：
  1. 在自动化或者生产 staging 环境配置 `.env` 注入：
     ```bash
     ENABLE_CODEX_SDK_CHAT=true
     CODEX_API_KEY=xxx
     FABUSHI_PLUGIN_MCP_TOKEN=xxx
     ```
  2. 构造自动化或实际交互 E2E 测试用例，验证网关流式响应与工具执行状态返回的稳定性。

### 3.4 阻塞四：Next.js Typecheck 修复与构建产物清理
* **现状痛点**：
  1. **React 类型重复冲突**：仓库中多应用结构存在不同版本的 `@types/react`（例如 `mp-wechat` 使用 `^18.2.0`，而 `web` 使用 `^19.1.4`），导致 `npm run typecheck` 触发 TS 类型不兼容报错。
  2. **`FaliuMeritBenefit` 类型与定义问题**：`faliu-merit-benefit-enhancer.tsx` 与相关解耦分片数据源（`faliu-merit-benefits-*.ts`）间存在导出或类型声明同步问题。
  3. **脏构建产物拦截**：`frontend/apps/web/out` 中保留有未跟踪的旧静态产物，容易引起生产发布混淆与 Git 工作区不洁净。
* **解决构思**：
  1. 梳理并统一仓库级 `package.json` 及 pnpm / npm 依赖中的 `@types/react` 版本声明（或通过 resolutions/overrides 强制统一）。
  2. 针对 `FaliuMeritBenefit` 接口进行完整的类型核查，确保所有被引用的卷/品分片定义完全满足接口契约并在出口统一导出。
  3. 执行 `git rm -r --cached frontend/apps/web/out` 及 `.gitignore` 规范化，确保在执行 `npm run build` 和 `typecheck` 前保持工作区洁净。

---

## 4. 严格执行流程与后续任务分解路线

遵循项目最高作业准则，在您对本方案及要点**审核确认**后，将进一步**分解为以下具体可执行任务列表（Task List）并逐步推进实施**：

| 阶段 | 对应任务 | 具体行动项 |
| :--- | :--- | :--- |
| **阶段一** | **Next.js 构建与类型清洁 (Blocker 4)** | 1. 清理 `web/out` 旧未跟踪构建产物；<br>2. 统一/修复 `React` 类型冲突；<br>3. 修复 `FaliuMeritBenefit` 相关导出与类型问题并验证 `tsc --noEmit` 全量通过。 |
| **阶段二** | **MCP OAuth 2.1 规范与宿主授权就绪 (Blocker 1)** | 1. 落地 `.well-known/oauth-protected-resource` 元数据接口；<br>2. 补充 PKCE 校验流程与客户端发现表，确保符合官方 MCP Authorization 规范。 |
| **阶段三** | **五个 Node HTTP 插件持久化改造 (Blocker 2)** | 将 `stateByScope` 内存存储转接至正式业务核心/存储驱动，完成对五个插件会话状态和业务数据的账户隔离持久化。 |
| **阶段四** | **Codex 链路 E2E 验证部署 (Blocker 3)** | 配置部署环境 `ENABLE_CODEX_SDK_CHAT=true` 及多模型密钥，完成全链路端到端自动化验收与发布。 |

---

## 5. 审核要求 (User Review Required)
请确认上述原理解答及针对四个剩余上线阻塞项的解决方案构思是否符合预期；如无异议，指示下一步从哪一个具体的阻塞任务（例如建议先从**阶段一：Next.js 构建与类型检查清洁**）开始分解与实际代码编程。
