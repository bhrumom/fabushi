# 全球法布施小程序聊天框数字交互与模式选择需求文档 (PRD)

## 1. 调研背景与核心问题
当前在法布施宿主聊天窗口与“全球法布施”小程序进行对话交互时，存在以下体验痛点：
1. **感知脱节**：聊天界面提示“正在调用小程序运行”，但用户感知上不明确小程序当前处于什么发包状态，且直接发包时依赖小程序页面的默认配置。
2. **缺乏模式控制权**：当用户在聊天框直接发送链接或经文正文时，系统此前会直接按照默认参数（`loop: false`）执行单次即时发包，用户无法在聊天框中直接选择是“单次即时发送”还是“开启常驻后台长久循环发送”。
3. **交互反馈单一**：聊天框作为 AI 助手核心交互界面，应当像智能化 Bot 一样具有“问答反馈”与“分支选择”机制，而不是生硬地单向接收文字。

## 2. 核心需求与设计目标 (第一性原理与 KISS 原则)
遵循 **KISS（简洁至上）** 与 **第一性原理**，优化小程序的指令处理逻辑，使得聊天界面真正成为控制系统级发包引擎的交互终点：
1. **素材接收与暂存**：当用户在聊天框发送网页链接或正文内容时，小程序不再立即触发发包，而是将内容暂存至 `pendingChatContentRef`，同时同步渲染到小程序页面的文本框中。
2. **数字菜单引导**：收到素材后，小程序通过 `bot.postMessage` 主动向聊天窗口推送清晰的**编号选择选项**：
   - `1`：🚀 **立即启动常驻后台循环发包**（每 30 秒自主执行，脱离 UI 长久运行，系统底层守护）
   - `2`：⚡ **执行一次即时单次发包**（完成一轮投递后立刻结束，用于快速测试网络）
   - `3`：❌ **取消本次发包**（重新发送新链接或素材）
3. **数字指令决断**：当用户在聊天框回复数字 `1`、`2` 或 `3` 时，小程序捕获并解析该指令：
   - 输入 `1`：提取暂存内容，强制开启 `loopEnabled: true`，提交至底层 `POST /jobs/start` 接口，进入脱离宿主 UI 的 OS 级常驻后台循环。
   - 输入 `2`：提取暂存内容，强制设为 `loopEnabled: false`，提交至底层 `POST /send` 接口，执行即时单发。
   - 输入 `3`：清空暂存内容并提示操作已取消。

## 3. 技术改造方案
### 3.1 状态隔离与缓存
在 `frontend/apps/web/src/app/miniapps/[id]/GlobalDharmaApp.tsx` 中增设：
```ts
const pendingChatContentRef = useRef<string | null>(null);
```

### 3.2 升级 `onAnyCommand` 指令监听
修改命令解析回调函数，针对传入的指令 (`command`) 或内容 (`incoming`) 进行智能路由：
1. **数字指令识别**：通过正则/字符串匹配判断用户输入是否为纯数字 `1`、`2`、`3`。
2. **分支处理**：
   - 若匹配数字 `1`：检查是否有待发包内容（`pendingChatContentRef.current || text`），如果有，调用 `handleStart(content, commandId, { overrideLoop: true })`。
   - 若匹配数字 `2`：调用 `handleStart(content, commandId, { overrideLoop: false })`。
   - 若匹配数字 `3`：将 `pendingChatContentRef.current = null`，并通过 `postBotMessage` 回写取消确认提示。
3. **新素材捕获与菜单推送**：
   - 若用户输入的不是预设命令（如 `/stop`、`/status`）也非数字选项，则视为新的待发包素材。
   - 更新暂存：`pendingChatContentRef.current = incoming; setText(incoming);`
   - 推送菜单：调用 `postBotMessage` 输出带有数字编号的引导提示文字。

### 3.3 `handleStart` 参数与行为优化
支持传入可选配置 `{ overrideLoop?: boolean }`，当指定了 `overrideLoop` 时，发包操作优先级高于页面复选框状态，并同步更新状态：
```ts
if (overrideLoop !== undefined) {
  setLoopEnabled(overrideLoop);
}
const effectiveLoop = overrideLoop !== undefined ? overrideLoop : loopEnabled;
```
随后调用 `runRealSend` 时将 `effectiveLoop` 作为 `loop` 参数下发。

## 4. 实施工作流与任务分解
严格遵循“构思方案 → 提请审核 → 分解为具体任务”的作业顺序：
- **阶段一：需求调研与设计确认（当前阶段）**
  - 生成本 PRD 文档并提交用户审核确认。
- **阶段二：代码实现与逻辑改造**
  - 任务 2.1：在 `GlobalDharmaApp.tsx` 增加素材暂存 Ref 与 `handleStart` 支持模式覆盖参数。
  - 任务 2.2：改造 `onAnyCommand`，实现数字命令匹配（1/2/3）与数字选项菜单回写。
- **阶段三：自动化编译与测试验证**
  - 任务 3.1：执行类型检查与构建测试，验证 TypeScript 语法与打包。
  - 任务 3.2：更新文档与交付。

## 5. 验收标准
1. 在聊天窗口发送一段经文或链接后，小程序不立即发包，而是迅速回复选项 1、2、3。
2. 回复数字 `1` 后，立刻看到“常驻循环已交由后台守护进程执行”的确认回写。
3. 回复数字 `2` 后，执行即时单次发送。

## 6. 自动化测试验证与异常解决记录 (更新至 2026-07-08)
### 6.1 遇到的问题与分析
1. **闭包过时与状态竞争**：在聊天命令监听器中直接获取 `loopEnabled` 等组件状态容易导致捕获旧的闭包状态。
   - **解决方案**：利用已有的 `latestCmdRef` 实时同步闭包变量，并将 `text` 与 `pendingChatContentRef` 统一接入上下文。在发包函数 `handleStart` 和 `runRealSend` 中支持显式传入 `{ overrideLoop: boolean }` 覆盖当前勾选框状态。
2. **构建验证**：
   - 运行自动化构建 `npm run build`，成功通过页面及模块打包验证（耗时 2.5s，生成全量静态及服务端页面）。
   - 代码零回归，数字菜单交互逻辑已完全落地就绪。
