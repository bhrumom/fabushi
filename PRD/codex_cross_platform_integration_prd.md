# 大乘全平台集成并使用 Codex 方案：以 Codex 为目标引擎，以 Codex Rust SDK 为统一调用工具 (PRD & Technical Blueprint)

## 1. 文档概述与核心架构逻辑：目标与工具的辩证统一

### 1.1 核心战略定位
立足于 **事实为本** 与 **第一性原理 (First Principles)**，我们要厘清系统架构中“终极目标”与“实施工具”的关系：
* **核心目标（What & Why）**：让大乘平台的**全平台（电脑桌面端、手机移动端 iOS/Android、Web 网页端）都能快速获得并真正使用 Codex 最新版的顶尖 AI 智能体能力**。包括自动上下文感知、多轮复杂推理、多大模型动态切换、工具调度以及赋能“机器人之父 (`official.bot-father`)”全自动对话生成小程序。
* **统一工具（How）**：**每个平台要集成并使用 Codex，必须依赖标准高效的工具，这个唯一的工具就是官方 `codex rust sdk`！** 我们摒弃了跨平台使用不同类库的碎片化方案，创造性地通过在 **`codex rust sdk`** 中引入“传输层接口抽象 (`CodexTransport`)”与“多模型网关抽象 (`CodexModelProvider`)”，然后将其编译为各平台的底层依赖，让各类终端 APP 都能统一通过 **`codex rust sdk`** 去安全、极速地调用和驱动 Codex！

### 1.2 三大战略交付物
1. **全平台统一调用链**：通过改造 `codex rust sdk` 的底层驱动，使其能够同时在电脑命令行、手机内存沙盒和网页 Wasm 环境中运行，全平台应用统一集成该 SDK 来调用 Codex。
2. **SDK 内核多大模型切换**：在 `codex rust sdk` 的配置与网关层中注入多大模型支持，通过 SDK 动态切换至 DeepSeek、Claude、Gemini 及本地私有化模型（Ollama/vLLM），让任何模型都能在 Codex 协议下被 SDK 稳定调用。
3. **赋能机器人之父引擎**：大乘“机器人之父”在代码层直接集成并实例化 **`codex rust sdk`**。通过 SDK 发起的智能体会话与工具调度，调用 Codex 在虚拟沙盒中自动生成、修改小程序代码，并触发即时预览与发布。

---

## 2. 第一性原理一：如何利用 `codex rust sdk` 在全平台调用 Codex？

### 2.1 传统痛点：为什么原来的 SDK 无法在全终端调用 Codex？
现有的开源 `codex rust sdk` 默认硬编码了操作系统的进程调起指令 (`std::process::Command::spawn`)：
* **在移动端（iOS / Android）集成时**：应用调用 SDK 会因为操作系统安全沙盒无 Fork/Exec 进程权限而直接崩溃；
* **在网页端（Web / Wasm）集成时**：浏览器环境毫无底层操作系统命令行，SDK 根本无法启动编译。

### 2.2 破局架构：在 `codex rust sdk` 内部建立传输驱动抽象 (`CodexTransport`)
第一性原理指出：**我们要利用 `codex rust sdk` 来做会话管理、状态维护和工具解析，至于这个 SDK 把指令发往何方以调用 Codex，应该由底层物理环境决定！**

遵循 KISS（简洁至上）原则，我们在 **`codex rust sdk`** 的连接底层建立 Trait 驱动抽象：

```rust
use async_trait::async_trait;
use futures::stream::BoxStream;
use anyhow::Result;

/// 赋予 codex rust sdk 跨端调用能力的底层驱动接口
#[async_trait]
pub trait CodexTransport: Send + Sync {
    /// 通过当前环境的特定驱动，向 Codex 引擎发送会话与工具执行指令
    async fn send_message(&mut self, payload: String) -> Result<()>;
    /// 接收 Codex 引擎返回的实时流式结果并交由 SDK 状态机解析
    async fn receive_stream(&mut self) -> Result<BoxStream<'static, String>>;
    /// 优雅终止当前 SDK 与 Codex 核心的连接
    async fn terminate(&mut self) -> Result<()>;
}
```

### 2.3 三端集成 `codex rust sdk` 调用 Codex 的物理实现

| 平台应用 | 如何集成 `codex rust sdk` | SDK 内部如何调用 Codex (开启的 Feature 驱动) | 用户端实际表现与体验 |
| :--- | :--- | :--- | :--- |
| **💻 电脑桌面端**<br>(macOS/Win/Linux) | 应用直接链接标准 SDK 动态/静态库。 | `feature = "transport-subprocess"`<br>SDK 通过控制台后台管道直接派生调用本地原生的 `codex-app-server` 可执行程序。 | **桌面全能编程**：SDK 直接调用电脑本地 Codex，拥有极致的文件读写、终端命令行执行和大型项目重构能力。 |
| **📱 手机移动端**<br>(iOS/Android) | 通过 `flutter_rust_bridge` 打包 SDK 为原生移动端插件嵌入 APP。 | `feature = "transport-embedded"`<br>SDK 放弃进程派生，直接静态编译内嵌官方 `codex-app-server-core` 库，通过内存级函数调用与回调来驱动 Codex。 | **随身内存级 AI**：手机端集成 SDK 后零沙盒冲突，无进程开销，不被系统杀后台；通过 SDK 调用 Codex 在内存虚拟沙盒中极速工作。 |
| **🌐 Web 网页端**<br>(Wasm32) | 将 SDK 通过 `wasm-pack` 编译为 `codex_sdk.wasm` 模块导入前端。 | `feature = "transport-wasm"`<br>SDK 切换为通过 WebSocket / WebRTC 驱动，调用云端大算力集群或用户个人家中的 PC 电脑端大乘网关。 | **云端轻量协同**：网页集成 Wasm SDK 后，即时建立网络连接调用远端 Codex 算力，实现全平台调用逻辑完整统一。 |

---

## 3. 第一性原理二：在 `codex rust sdk` 中实现多大模型动态切换

### 3.1 为什么通过 SDK 支持多模型是关键？
要让全平台随时能切换使用不同的底层模型（如兼顾高智能与低成本的 DeepSeek R1、UI 美学极其出众的 Claude 3.5、纯离线安全的 Ollama/vLLM），我们**必须让各个平台的应用通过 `codex rust sdk` 去统一配置和发起调用**。

### 3.2 架构实现：在 `codex rust sdk` 中嵌入模型路由与转译网关
我们在 `codex rust sdk` 的客户端配置结构体 (`CodexConfig`) 中新增模型提供商抽象 (`CodexModelProvider`)，由 SDK 内部的网关拦截层负责协议转换：

```rust
use std::collections::HashMap;

/// codex rust sdk 支持动态调用的目标大模型类型
#[derive(Debug, Clone, PartialEq)]
pub enum ModelProviderType {
    OpenAI,
    DeepSeek,
    AnthropicClaude,
    GoogleGemini,
    LocalOllama,
    CustomServer,
}

/// 传递给 codex rust sdk 的动态大模型配置
#[derive(Debug, Clone)]
pub struct CodexModelConfig {
    pub provider: ModelProviderType,
    pub base_url: String,
    pub api_key: String,
    pub model_name: String,
    pub temperature: f32,
    pub custom_headers: HashMap<String, String>,
}

/// SDK 内部协议适配网关：确保所有大模型均能被 SDK 正确调用并发挥 Codex 工具能力
pub trait CodexModelGateway: Send + Sync {
    /// 将 SDK 发起的标准 Prompt 和工具定义格式化为目标大模型的请求格式
    fn format_request(&self, prompt: &str, tools: &[ToolDefinition], config: &CodexModelConfig) -> String;
    /// 将第三方大模型返回的流式分片还原为 SDK 标准的 CodexEvent（尤其是 ToolCall 结构）
    fn parse_stream_chunk(&self, raw_chunk: &str) -> Result<Vec<CodexEvent>>;
}
```

### 3.3 SDK 赋能多模型的卓越效果
通过集成改造后的 `codex rust sdk`，平台只需在初始化客户端时传入不同的 `CodexModelConfig`：
* **当 SDK 配置为 DeepSeek R1 时**：SDK 自动进行 OpenAI 兼容协议映射与 URL 重定向。各个平台的应用立刻通过 SDK 获得 DeepSeek 极其强大的推理逻辑，能精准指挥 Codex 在虚拟沙盒中自动构建复杂项目。
* **当 SDK 配置为 Claude 3.5 时**：SDK 内置网关将 Tool Use 参数双向映射。在需要开发精美交互界面时，SDK 把 Claude 的美学生成能力完美转化为 Codex 对 CSS/UI 文件的工具调用。

---

## 4. 核心应用：“机器人之父”通过集成 `codex rust sdk` 自动生成小程序

### 4.1 业务架构：机器人之父如何使用 SDK 去调用 Codex？
在大乘平台中，**“机器人之父 (`official.bot-father`)”小程序生成器之所以具备强大的自动开发能力，正是因为他在代码中直接集成并调用了 `codex rust sdk`**。
用户对机器人之父发送自然语言需求后，机器人之父利用 SDK 的 `createThread` 和工具注册机制，指挥 Codex 智能体对大乘虚拟文件沙盒进行全自动代码操纵。

### 4.2 机器人之父通过 SDK 调用 Codex 的全自动闭环工作流

```mermaid
sequenceDiagram
    autonumber
    actor User as 全平台用户 (桌面/手机/网页)
    participant BF as 机器人之父 (BotFather UI)
    participant SDK as 集成在 APP 内的 codex rust sdk
    participant Codex as 底层 Codex 引擎 (多模型计算节点)
    participant VFS as 大乘虚拟文件沙盒 (Virtual VFS)
    participant AppHost as 小程序热重载预览容器 (MiniApp Host)

    User->>BF: 输入需求："帮我写一个莫兰迪色系的‘禅修念佛与打卡日记’小程序"
    BF->>SDK: 实例化 CodexClient，传入 DeepSeek-R1 模型配置与开发者提示词
    SDK->>Codex: 通过对应传输驱动，向 Codex 发送带有沙盒工具库 (create_file, patch_code, lint) 的工作指令
    Codex-->>SDK: 深度推理并下发 Tool Call 函数调用分片
    SDK->>VFS: SDK 拦截并解析工具指令，自动在沙盒内存中创建/更改文件：<br>manifest.json, index.tsx, styles.css, storage.ts
    VFS-->>SDK: 返回写入确认与实时语法校验报告
    SDK-->>BF: 将高级结构化事件 (SandboxFileModifiedEvent) 上报至业务层
    BF->>AppHost: 触发热模块重载 (HMR)，右侧小程序预览窗口即时呈现画面！
    User->>BF: 提出修改："把打卡按钮改成金色，增加点击撒花特效"
    BF->>SDK: 调用 sdk.sendMessage() 发送增量调整要求
    SDK->>Codex: Codex 自主推理并发出局部补丁指令 (Patch Code Tool Use)
    SDK->>VFS: 精准更新 styles.css 与动画组件代码
    BF->>AppHost: 预览窗口实时变更为金色撒花效果，用户满意并点击“保存”
    BF->>SDK: 触发 sdk.executeTool("build_package")，导出成品，正式发布到个人小程序应用列表！
```

### 4.3 集成 SDK 的三大决定性优势
1. **多轮记忆与虚拟工程树感知**：通过 SDK 管理会话状态机，机器人之父能够精准知晓整个小程序虚拟目录内各代码文件的关联。
2. **自动化代码除错 (Self-Healing)**：如果在沙盒热加载时遇到语法或编译报错，错误堆栈由大乘容器返回给 `codex rust sdk`。SDK 会自动提交给 Codex 触发反思，自主调用修改文件工具修复 Bug！
3. **彻底替代手写 API 调用**：SDK 帮前端应用屏蔽了 HTTP 链接、SSE 流解析、Tool JSON 校验等复杂脏活，让机器人之父的代码极其纯净优雅。

---

## 5. 全平台统一使用 Codex 与 SDK 集成大一统架构图

```mermaid
graph TD
    subgraph "大乘全平台各应用终端 (Flutter / Dart 业务层)"
        UI_BF["🤖 机器人之父小程序生成器<br>(official.bot-father：一键对话开发小程序)"]
        UI_CHAT["💬 平台通用 AI 编程与会话助手"]
        UI_HOST["📱 小程序热加载预览运行容器<br>(MiniApp Host / Live HMR Preview)"]
        
        UI_BF <-->|代码变更与即时热替换| UI_HOST
    end

    subgraph "全平台集成桥梁：统一的 codex rust sdk (通过 FRB 跨平台导出)"
        SDK_CLIENT["CodexSdk Client API<br>(统一暴露会话创设、多模型配置与事件流监听)"]
        SDK_ENGINE["SDK 核心状态机与工具调度解析器<br>(Session Manager / Tool Call Dispatcher)"]
        
        UI_BF ==>|"集成并调用 SDK"| SDK_CLIENT
        UI_CHAT ==>|"集成并调用 SDK"| SDK_CLIENT
        SDK_CLIENT --> SDK_ENGINE
    end

    subgraph "第一性原理一：SDK 跨端调用 Codex 的传输驱动抽象 (CodexTransport)"
        DRV_SUB["桌面驱动<br>SubprocessTransport"]
        DRV_EMB["移动端驱动<br>InProcessMemoryTransport"]
        DRV_WS["网页驱动<br>WebSocketWasmTransport"]
    end

    subgraph "第一性原理二：SDK 内置多大模型网关层 (CodexModelGateway)"
        GW_OPENAI["OpenAI / DeepSeek R1 / Ollama<br>(OpenAI 兼容协议映射器)"]
        GW_CLAUDE["Anthropic Claude 3.5<br>(Tool Use 转译映射器)"]
        GW_GEMINI["Google Gemini 2.5<br>(Function Calling 转译器)"]
    end

    SDK_ENGINE -->|"cfg(桌面端 macOS/Win/Linux)"| DRV_SUB
    SDK_ENGINE -->|"cfg(移动端 iOS/Android)"| DRV_EMB
    SDK_ENGINE -->|"cfg(网页端 Web/Wasm)"| DRV_WS

    SDK_ENGINE ===>|"SDK 根据模型配置路由"| GW_OPENAI & GW_CLAUDE & GW_GEMINI

    subgraph "真实的 Codex 计算引擎与底层多大模型算力"
        ENGINE_CLI["电脑系统原生的 Codex 命令行程序"]
        ENGINE_CORE["手机端内存内嵌的 Codex 静态核心库"]
        ENGINE_CLOUD["云端大乘分布式网关 / 家庭电脑节点"]
        
        LLM_DEEPSEEK["DeepSeek 官方 API / 高能推理算力"]
        LLM_CLAUDE["Anthropic 官方 API / Vertex AI"]
        LLM_LOCAL["用户本地 PC / 纯离线私有化模型"]
    end

    DRV_SUB ==> ENGINE_CLI
    DRV_EMB ==> ENGINE_CORE
    DRV_WS ==> ENGINE_CLOUD

    GW_OPENAI ---> LLM_DEEPSEEK & LLM_LOCAL
    GW_CLAUDE ---> LLM_CLAUDE
    GW_GEMINI ---> LLM_CLAUDE
```

---

## 6. Dart / Flutter 应用层如何集成与使用 SDK 调用 Codex

各平台的 Flutter 应用在代码中集成 SDK 后，通过极其简明易懂的强类型语法去调用 Codex 智能体：

```dart
import 'package:fabushi/bridge_definitions.dart'; // FRB 一键生成，免除全平台差异判断

void main() async {
  // 1. 在 SDK 中配置我们需要切换的大模型（例如让机器人之父切换使用逻辑推理高超的 DeepSeek R1）
  final modelConfig = CodexModelConfig(
    provider: ModelProviderType.DeepSeek,
    baseUrl: "https://api.deepseek.com/v1",
    apiKey: const String.fromEnvironment('DEEPSEEK_API_KEY'),
    modelName: "deepseek-reasoner",
    temperature: 0.1,
  );

  // 2. 实例化并初始化集成的 codex rust sdk 客户端
  //    (桌面 APP 自动链接后台进程，手机 APP 自动唤起内存桥，Web 端自动建立 WebSocket)
  final codexClient = await CodexSdk.createClient(
    config: CodexConfig.defaultConfig().withModel(modelConfig),
  );

  // 3. 机器人之父利用 SDK 创建一个绑定虚拟沙盒的工作区会话
  final thread = await codexClient.createThread(
    workspaceId: "sandbox.miniapp.user_001",
    systemPrompt: "你是机器人之父(BotFather)，擅长利用Codex工具在虚拟沙盒中极速构建与调试小程序。",
  );

  // 4. 用户对机器人之父说话，通过 SDK 真正调用并驱动底层的 Codex 智能体
  await thread.sendMessage("请帮我写一个带有倒计时和数据图表的‘备考冲刺打卡’小程序。");

  // 5. 监听由 codex rust sdk 为我们实时解析好的高级事件流
  thread.events.listen((event) {
    if (event is ReasoningProgressEvent) {
      print("🧠 机器人之父[通过SDK调用DeepSeek]思考中：${event.reasoningContent}");
    } else if (event is ToolCallTriggeredEvent) {
      print("🔧 SDK驱动Codex自动执行工具 [${event.toolName}] 操作虚拟文件：${event.targetFile}");
    } else if (event is SandboxFileModifiedEvent) {
      print("📝 虚拟沙盒代码写入成功：${event.filePath}");
      // 触发大乘小程序容器，用户在右侧开发区立刻看到备考倒计时的画面渲染！
      MiniAppHostScreen.triggerHotReload(event.filePath, event.newContent);
    } else if (event is TurnCompletedEvent) {
      print("🎉 机器人之父通过 SDK 调用 Codex 完成了本轮开发任务！");
    }
  });
}
```

---

## 7. 极速跟进官方最新演进：全端集成 SDK，秒级同步官方 Codex 进化

如何既能让每个平台通过集成 `codex rust sdk` 调用 Codex，又能确保对 OpenAI 及官方最新的 Codex 迭代做到**“零破损、极速跟进”**？

### 7.1 Git Submodule 与防腐层自适应隔离架构
1. **纯净挂载主干**：将官方最新的 Codex 及 SDK 主干仓库以只读 Git Submodule 形式引用至 `third_party/codex` 与 `third_party/codex-sdk`。
2. **防腐适配桥接层 (Anti-Corruption Layer)**：我们在独立的桥接工程中实现 `CodexTransport` 与 `CodexModelGateway` Trait。所有关于跨平台物理驱动与第三方多模型切换的逻辑均在外部防腐层完成，**绝不侵入修改官方 SDK 内部的业务状态机代码**！
3. **上游官方更新发版时的标准极速升级 SOP**：
   ```bash
   # Step 1: 秒级拉取 OpenAI 与官方社区最新的 SDK 核心与智能体协议代码
   git submodule update --remote --merge third_party/codex
   git submodule update --remote --merge third_party/codex-sdk
   
   # Step 2: 运行防腐层契约回归测试，验证本地驱动与虚拟沙盒的兼容性
   cargo test --manifest-path native/codex-wrapper/Cargo.toml
   
   # Step 3: 一键更新 Dart 跨平台绑定接口
   flutter_rust_bridge_codegen --config frb_config.yaml
   ```

**真正的全平台能力同频升级**：因为所有客户端都是统一集成这个防腐包靠 `codex rust sdk` 调用底层，当官方发布更聪明的思维链协议、新增 MCP 插件支持或优化会话结构时，只需执行这条自动化构建指令，**大乘平台电脑桌面端、iPhone移动端、Android移动端与Web网页端集成的 SDK 会立刻更新，所有应用中的 AI 助手与“机器人之父”瞬间获得官方最新的尖端能力！**

---

## 8. 渐进式落地实施路线图与具体任务清单 (Roadmap & Task List)

按照“构思方案 → 提请审核 → 分解为具体任务”的渐进式作业流程，落地工程围绕 **`codex rust sdk`** 的跨端集成展开，分为四大阶段：

| 实施阶段 | 核心任务与交付成果 | 战略验证准则 | 责任区域 |
| :--- | :--- | :--- | :--- |
| **Phase 1<br>集成官方 SDK 与桌面端驱动回归** | 1. 以只读 Submodule 导入官方 `codex rust sdk`<br>2. 在 SDK 桥接层构建 `CodexTransport` 异步 trait 驱动接口<br>3. 封装桌面标准进程驱动 `SubprocessTransport` | 在 macOS 与 Linux 桌面工程中集成 SDK，运行单元测试，验证 SDK 能完美调用本地 Codex 进程执行文件操作与终端命令。 | Rust Core / CI |
| **Phase 2<br>在 SDK 中构建多模型切换网关** | 1. 在 SDK 中增加 `CodexModelConfig` 与多 Provider 枚举<br>2. 实现 `OpenAI-Compatible` 协议转译层（支持 DeepSeek-R1 / Ollama）<br>3. 实现 Claude / Gemini 函数调用 (`Tool Use`) 映射网关 | 验证应用向 SDK 传入 DeepSeek R1 或 Claude 3.5 配置后，SDK 能准确将第三方模型思考流转译为对 Codex 工具的调用。 | Rust Gateway |
| **Phase 3<br>移动/Web端集 SDK 与虚拟沙盒对接** | 1. 研发**大乘内存虚拟文件沙盒系统 (Virtual VFS)**<br>2. 在 SDK 内部实现移动端内存函数驱动与 Web 端 WebSocket 驱动<br>3. 运行 FRB 打包，把 SDK 导出为全平台通用的 Flutter 原生插件 | iOS / Android 移动端及网页 APP 成功嵌入 SDK；应用能通过 SDK 唤醒 Codex 在虚拟沙盒内存中完成代码编辑与构建。 | Flutter / Native |
| **Phase 4<br>机器人之父集成 SDK 实现小程序闭环** | 1. 在 `official.bot-father` 代码中集成并实例化 `CodexSdk` 客户端<br>2. 把 SDK 解析出的沙盒工具调用事件直接绑定大乘小程序工程树<br>3. 打通对话改代码 -> 实时 HMR 热重载预览 -> 自动打包发布的全闭环 | 演示：在手机、电脑、网页任一平台打开机器人之父对话，机器人之父通过 SDK 调用 Codex，几秒内完成小程序开发与热预览上架！ | BotFather / MiniApp |

---

## 9. 任务完成输出与研发踩坑实践总结 (Implementation & Troubleshooting Record)

在严格遵循第一性原理和 KISS 简洁至上原则下，开发团队完成了全阶段架构落地与自动测试闭环，记录如下：

### 9.1 已落地的工程制品清单
1. **跨平台底层 SDK 防腐桥接库 (`native/codex-wrapper`)**：
   - `src/transport.rs`：实现了 `CodexTransport` 异步连接驱动契约，内置对原生桌面标准管道 `SubprocessTransport` 与手机/网页内存通道 `InProcessMemoryTransport` 的无缝适配。
   - `src/model.rs`：构建了支持 OpenAI、DeepSeek-R1、Claude 3.5、Gemini 与本地 Ollama 的 `CodexModelConfig` 与多模型转译网关 (`UniversalModelGateway`)，准确剥离思维链并映射 Tool Calling 函数。
   - `src/sandbox.rs`：自研**大乘内存虚拟文件系统沙盒 (`VirtualVfs`)**，提供线程安全的 `create_file`、`update_file`、`patch_code`、`read_file` 和 `export_package`，为无终端环境的小程序构建保驾护航。
   - `src/client.rs`：统一封装会话线程 `WorkspaceThread` 与 `CodexClient`，自动监听流式响应，并在触发工具调用时自动执行沙盒操作与事件分发。
2. **Flutter/Dart 端对客户端能力的高阶封装**：
   - `fabushi/lib/services/miniapp/codex_sdk_service.dart`：构建了全平台一体化的 `CodexSdk` 单例，暴露流式 `sendMessage`、热修改以及调试自我修复接口。
3. **机器人之父 (`official.bot-father`) 业务对接**：
   - `fabushi/lib/screens/social_feature_chat_screen.dart`：在 `_startBotFather()` 中无缝挂载 `CodexSdk` 虚拟沙盒驱动；当生成或修改小程序发生异常时，自动拦截编译/解析错误并触发 `CodexSdk.instance.sendMessage(..., isSelfHealing: true)` 实现自动化自我修复调试（Self-Healing Debugging）。
4. **跨端持续集成自动化流水线**：
   - `.github/workflows/ci_codex_sync.yml`：配置多系统矩阵（Ubuntu、macOS、Windows）上的 Rust 代码校验与单元回归测试及 Dart 静态分析。
5. **UI 自定义 API 与多模型配置面板（响应用户对‘软件里面自己配置 api’的需求）**：
   - `fabushi/lib/services/app_settings.dart`：新增 `getCodexApiKey`、`getCodexBaseUrl`、`getCodexModelName`、`getCodexProvider` 等持久化读写方法。
   - `fabushi/lib/screens/settings_screen.dart`：在系统设置的高级 AI 模块和移动端常规设置中新增了“自定义大模型与 Codex API”面板，支持用户自由切换 DeepSeek R1/V3、OpenAI、Ollama 本地部署等模型接口并保存，实时同步刷新 `CodexSdk` 实例。

### 9.2 研发中遇到的技术难题与解决方案 (Troubleshooting)

| 遇到的难题/现象 | 第一性原理分析原因 | 最终采用的解决方案 |
| :--- | :--- | :--- |
| **错误 E0603：enum import `CodexEvent` is private** | 在 `lib.rs` 中使用 `pub use client::{..., CodexEvent, ...};` 时，由于 client 模块中 `CodexEvent` 是仅从 model 引入的私有引用，导致编译器拒第二个外二次暴露。 | 直接把导出来源订正为定义该枚举的根源模块：`pub use model::{CodexEvent, ...};`，保证模块可见性契约清晰简洁。 |
| **单元测试运行异常 panic：`Failed to send message: channel closed`** | 在创建测试会话线程 `WorkspaceThread` 时，为了测试内联内存驱动，初始化了 `(transport, tx_in, _rx_out) = InProcessMemoryTransport::new()`。但由于返回的 `_rx_out` 变量未在结构体或作用域中被持久持有，在构造完成后立即被 `Drop` 销毁。导致后端再尝试发数据给前端管道时因为消费端退出而报错。 | 在 `WorkspaceThread` 结构体中新增字段 `pub mock_rx: Option<tokio::sync::mpsc::Receiver<String>>` 来持续持有接收通道的所有权，确保在整个会话测试闭环期间生命周期存活，彻底解决通道意外中断的问题。 |
| **异步事件流 `stream.next().await` 无限期卡住挂起超 60 秒** | 底层的异步消息流依赖对接收通道的监听 `while let Some(res) = raw_stream.next().await`。由于 `mock_tx` 发动完数据后仍在宿主内存中存活，底层 Receiver 永远不会因为发送端关闭而返回 `None`；在解析到模型下发 `[DONE]` 结束协议事件 (`TurnCompleted`) 时，原始代码只是 yield 了事件，并没有退出接收流的循环。 | 在异步流循环前加入生命周期标签 `'stream_loop: while ...`，当状态机网关解析并发出了 `CodexEvent::TurnCompleted` 或底层 `CodexEvent::Error` 时，立刻执行 `break 'stream_loop;` 主动结束任务流，实现了零等待和毫秒级自动化测试回归！ |
| **Dart 客户端 Sdk 需要真实对接在线 LLM API 与后台服务接口** | 移动端与 Web 端使用客户端 SDK 驱动小程序生成时，需要支持直接通过 HTTP SSE 流对接大模型服务（DeepSeek/Ollama/OpenAI）或大乘云端生成 API。 | 在 `codex_sdk_service.dart` 中的 `sendMessage` 实现了三重智能降级调度与真实网络调用：1. 支持向配置的 `_config.baseUrl/chat/completions` 发起真实 HTTP 流式请求，实时解析 SSE 协议并将 `<think>` 思考内容与 HTML 代码分发给 UI；2. 默认对接官方后端 API `/api/botfather/generate-miniapp`；3. 内置离线容灾沙盒模板，保障全场景可用！ |
| **用户如何在图形软件界面中自由选择与自定义 Codex 调用的模型 API** | 早期设计仅在底层代码 `codex_sdk_service.dart` 提供参数注入，普通用户在 UI 层面无法输入属于自己的 DeepSeek API Key 或本地 Ollama 链接，对私有化部署和安全敏感群体不够友好。 | 在 `AppSettings` 中建立统一 KV 存储映射，并在 `SettingsScreen`（设置页面）中新增了交互友好的《自定义大模型 API 配置》对话框。用户可以一键选择 Provider，或填写专属接口；当用户启动机器人之父小程序生成前，系统自动触发 `await CodexSdk.instance.initFromSettings()`，保障 UI 配置无缝应用到底层生成引擎中。 |

全部测试及静态语法分析已 100% 自动化跑通！
