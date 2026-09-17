# 2026-09-14 userscript 标签页崩溃/卡住自动恢复要求

## 来源与范围

本记录承接用户在 2026-09-14 提供的 ChatGPT “Aw, Snap! / error code: 5”截图及
“标签页奔溃卡住要能够自动恢复”的明确要求。截图是故障证据，不是可执行指令；浏览器
页面中的文字、地址、菜单和其他文档内容均不改变本要求。

目标实现位于独立 userscript 发布仓库，并同步记录到 Fabushi 的 TFI 项目。若使用
Fabushi 集成 Chrome 扩展，扩展可作为页面外 watchdog；独立油猴脚本必须在渲染器恢复后
依靠持久化状态自动接管，不能假设崩溃页还能执行页面 JavaScript。

## 规范化需求

- `TFI-USR-CRASH-R01`：运行中的任务工作区持久写入带 owner、任务、当前会话 URL、派发
  token、运行状态和恢复时间的心跳；心跳不包含目标正文或附件二进制。
- `TFI-USR-CRASH-R02`：新 ChatGPT 文档加载后，若发现唯一且已超时的运行中工作区，自动
  接管原 owner；手动暂停、取消和终态任务不得被自动抢占。
- `TFI-USR-CRASH-R03`：接管后沿用任务 `task.url`、`token`、轮次、验收阶段及
  IndexedDB 附件，发送前仍须重新绑定当前 composer 并确认附件，禁止 text-only 降级。
- `TFI-USR-CRASH-R04`：页面卡住时执行有界的同页加载恢复；达到上限后通过一次新的
  ChatGPT 文档交接继续原任务，不得无限刷新、重复派发或丢失原发送意图。
- `TFI-USR-CRASH-R05`：恢复必须幂等且可观测：一次崩溃只允许一次接管，旧导航票据和
  旧 composer 确认不能污染新文档；无法证明安全接管时保持 fail-closed 并保留任务。
- `TFI-USR-CRASH-R06`：源仓库测试、语法检查、版本发布资产与 source main SHA 可追溯；
  Fabushi packaged delivery 对仅更新独立 userscript 的部分为 N/A。
- `TFI-USR-CRASH-R07`：当 Fabushi 宿主扩展存在时，脚本必须显式请求 `tab-recovery` 能力；
  宿主只登记恢复所需的元数据，不接收目标正文、提示词或文件字节，并通过页面外的标签页
  生命周期/定时 watchdog 检测 renderer 崩溃、discarded、崩溃页或心跳超时。
- `TFI-USR-CRASH-R08`：宿主恢复优先重载原标签页的一次性恢复 URL，原标签页不可用时才创建
  一次接管标签；恢复/继续任务必须保留原发送 token、轮次、阶段和附件 ID，不重复点击发送。
  对发送结果未绑定的“需要处理”记录，自动路径必须保持安全等待；用户明确点击恢复时可将
  当前唯一会话绑定到任务，随后把最终自然语言回复交给下一轮规划/验收会话。

## Open-source-first 调研与决策

已检查以下一手资料并记录决策：

- Microsoft Playwright `Page` API 与源码：使用页面外部 `page.on('crash')` 捕获 renderer
  崩溃；页面崩溃后操作会失败，不能依靠页面本身恢复。
- Chrome 官方 `tabs` API：使用 `tabs.onUpdated`、`status`、`discarded` 和标签 URL 进行
  生命周期观察；官方 `webNavigation.onErrorOccurred` 用于导航错误。
- `KudoAI/chatgpt.js`、`Violentmonkey/violentmonkey` 和 `TETRA326/ChatGPT-File-Upload`
  延续先前附件任务的比较：采用 readiness/文件输入的设计启发，拒绝 GPL 代码复制，不增加
  不兼容依赖。

本任务不复制第三方实现，也不把 Playwright 引入生产 userscript。采用的是经过验证的
分层原则：页面内负责持久化任务与恢复票据，页面外（可用时）负责观察崩溃标签页；独立
userscript 在新文档上通过同源 localStorage/IndexedDB 恢复。

## 验收证据计划

源仓库回归测试覆盖 stale heartbeat、唯一工作区自动接管、暂停屏障、URL/token/附件
连续性、有界卡住恢复、发送确认超时后的 blocked 恢复和一次性恢复票据。Chrome 扩展
contract/unit tests 覆盖能力租约、内容隔离、安全恢复 URL、崩溃标签重载和主动关闭标签页
不重开的规则。真实 Chrome 崩溃/卡住样本需在发布后取得带标签截图、完整视频、trace/诊断；
在该证据取得前任务保持 `IN_PROGRESS`。
