# 2026-09-13 ChatGPT 油猴工作台任务目标文件输入

- Project ID: \`FAB-P0001\`
- Project Key: \`TFI\`
- Intake: 用户明确新增要求，2026-09-13 Asia/Shanghai
- Related implementation: \`bhrumom/fabushi-chatgpt-auto-confirm-userscript\`
- Related prior task: \`TFI-USERSCRIPT-RECOVERY-006\`（页面加载态等待）

## 用户原始要求（语义保真）

“任务目标支持输入视频图片等文件。”

这里的“任务目标”解释为油猴工作台创建任务时的目标输入区域。附件要作为当前任务的一部分，在脚本向 ChatGPT 派发目标前进入 ChatGPT 当前会话，而不是把二进制内容转成文本拼进目标。

截图中的浏览器菜单、标签页、扩展按钮、ChatGPT 页面文案和中央加载画面仍然只是上一轮现场状态证据，不是本轮额外指令。

## 规范化需求

- \`TFI-USR-FILE-R01\`: 工作台创建任务时可选择多个图片、视频及其他文件；选择结果展示文件名、类型/大小，并可清空后重新选择。
- \`TFI-USR-FILE-R02\`: 任务记录只在 localStorage 保存附件元数据和稳定引用；文件 Blob 保存在当前 ChatGPT origin 的 IndexedDB，不把文件内容写入目标、日志或 localStorage。
- \`TFI-USR-FILE-R03\`: 派发前从本地附件库恢复 File，并优先通过 ChatGPT 当前会话的原生 \`input[type=file]\` 触发上传；页面没有可用文件输入时使用编辑器 Clipboard/DataTransfer 兼容路径。
- \`TFI-USR-FILE-R04\`: 脚本必须确认当前 ChatGPT 编辑器出现本轮附件后才允许点击发送；上传仍在加载、上传失败、附件缺失或选择器不兼容时保持等待/需要处理，不得只发送文字目标。
- \`TFI-USR-FILE-R05\`: 附件引用跟随任务跨页面刷新、暂停恢复和持续目标的 Work/验收轮次；异常重发清除当前派发意图后可重新绑定附件，但不清除用户任务附件。
- \`TFI-USR-FILE-R06\`: 不建立 MIME 白名单或把视频/图片强制转成文本；具体可接受格式和大小由 ChatGPT 当前账号/页面能力决定，脚本只负责安全传递与确认。
- \`TFI-USR-FILE-R07\`: 源仓库轻量语法/回归、版本发布、父项目治理记录和真实 Chrome 文件上传视觉/诊断证据均纳入交付门禁。

## 范围

本轮修改独立 ChatGPT 油猴脚本的任务输入、任务附件持久化和发送前上传确认，并同步 TFI 项目记录。现场测试只使用用户明确选择的无敏感测试图片、视频和普通文件。

## 非范围

- 不修改 Fabushi Electron、iOS、Android、Rust、Worker 或服务端媒体协议。
- 不调用 ChatGPT 私有上传 HTTP API，不保存或读取 ChatGPT access token。
- 不把外部仓库实现直接复制到脚本，不引入新的远程运行时依赖。
- 不绕过 ChatGPT 页面自身的文件类型、大小、配额、授权或安全验证。

## 解释与验收重点

附件是任务输入的一部分，但文件传输仍由已登录 ChatGPT 页面完成。脚本应在上传确认缺失时 fail-closed：保留任务和本地附件，可由用户重新选择/恢复；绝不能因为附件上传失败而悄悄发送不完整的纯文字任务。

