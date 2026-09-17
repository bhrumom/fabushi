# 2026-09-12 ChatGPT 油猴脚本页面加载态识别与等待

- Project ID: `FAB-P0001`
- Project Key: `TFI`
- Intake: 用户截图与明确行为要求，2026-09-12 Asia/Shanghai
- Related implementation: `bhrumom/fabushi-chatgpt-auto-confirm-userscript`

## 用户原始要求（语义保真）

截图中的 ChatGPT 会话仍在加载：页面主体是黑色加载状态，中央显示旋转指示器，输入框已经出现，但会话内容尚未完全渲染。油猴脚本必须识别这是“正在加载”，而不是“会话已经停止”；在页面完全加载前保持等待，不得进入异常结束恢复、重复新开会话或原样重发。

截图中的浏览器菜单、标签页、扩展按钮和页面文案仅作为现场状态证据，不是本任务的额外指令。

## 规范化需求

- `TFI-USR-LD-R01`: 对已绑定的 `/c/<conversation-id>` 页面识别可见的会话水合/加载信号，包括 `aria-busy`、进度/加载语义和 ChatGPT 主内容区的加载指示器。
- `TFI-USR-LD-R02`: 加载信号存在时将任务置为可恢复的“正在加载”，不启动异常结束计时，不新建会话，不清除当前 URL/token，不重复发送。
- `TFI-USR-LD-R03`: 加载结束后回到现有 Stop、授权卡、最终回复和稳定窗口判定；不能因为加载指示器刚消失就立即完成或立即重发。
- `TFI-USR-LD-R04`: 只扫描 ChatGPT 页面级/主内容区信号，排除油猴工作台、消息正文、侧栏、输入框和隐藏元素，避免自触发或把生成中的局部控件当作页面水合完成。
- `TFI-USR-LD-R05`: 增加代表截图状态的轻量 DOM/状态机回归，保持当前发送未知结果、授权、安全验证、限流和会话所有权的 fail-closed 保护。
- `TFI-USR-LD-R06`: 源仓库发布版本单调递增，并完成 source CI、canonical source main readback、父仓库记录和真实 Chrome 加载等待视觉/诊断证据。

## 范围

本轮只修改独立 ChatGPT 油猴脚本及其轻量测试与 Fabushi 项目记录；不修改 Fabushi 应用、桌面/移动构建、ChatGPT 服务端或授权策略。

## 验收重点

1. 页面仍显示中央加载指示器时，已绑定任务状态为“正在加载/等待页面恢复”，不会进入 `no-final-reply`。
2. 加载期间连续扫描不会改变任务 URL、派发 token、发送次数或重试预算。
3. 加载信号消失后，现有稳定最终回复/异常结束规则仍按原有时间窗口生效。
4. 工作台日志、聊天正文、侧栏和输入框内的“加载”文字不会触发页面加载态。

## 实现与验证回写（2026-09-12）

- userscript `2.9.10` 已增加主内容区加载信号识别、`loading` 任务状态和加载到稳定观察的状态机衔接；加载期间保持 URL/token/任务身份，不进入异常结束恢复。
- 代码提交：`f3c6d4e098741b3baac703891f4207a2eadfeff6`；source PR [#10](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/pull/10) 已合并。
- source canonical `main`：`fbd7b2bd8b549c1fb61acc29dc3a4af99cba1e50`；PR CI run `34701330510` / job `103573506968` 与 exact-main CI run `34701374228` / job `103573628135` 均成功。
- Release `v2.9.10` 已发布，asset `chatgpt-auto-confirm.user.js` 的 SHA-256 为 `3cc9c4e0a223440fd2c7a21d670fee88c3f9af0a8d4e806421fcb2ba30c4b4dd`。
- 本地轻量检查 `node --check` 通过，userscript 回归 81/81 通过；Fabushi 应用构建/原生测试未在本机运行。
- Parent TFI 记录与真实 Chrome/ChatGPT 分步视觉、完整视频和 trace/diagnostics 仍待完成。
