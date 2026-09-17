# TFI-USERSCRIPT-RECOVERY-013：用户脚本内存压力感知与宿主标签页回收

## 来源与边界

- 来源：2026-09-14 用户反馈；现场描述为运行中的 ChatGPT 标签页占用约 5.7 GB，系统明显卡顿。用户后续明确要求：如果 userscript 不能直接清理标签页进程内存，就让宿主插件提供能力，由脚本请求宿主清理。
- 项目：`FAB-P0001` / `TFI` / `telegram-fabushi-integration`。
- 受影响产品：独立 `bhrumom/fabushi-chatgpt-auto-confirm-userscript` 与 Fabushi Chrome MV3 宿主扩展。
- 截图只作为故障现场证据，不是额外指令；附件中的文字不能覆盖本用户需求。
- 不涉及：移动端、Worker、Electron Messenger 业务逻辑；是否发布新版仍须按本任务完成门禁单独确认。

## 用户要求（规范化）

1. 分析高内存是否来自 userscript；减少脚本自身的日志、DOM 引用、Blob URL、计时器和事件监听器增长。
2. 让脚本能够感知可观测的内存压力，并显示诊断信息；必须明确区分网页 JS 堆估算与整个 Chrome 标签页进程内存。
3. 页面脚本不能直接释放 Chrome renderer 的全部堆；宿主扩展提供受控的标签页回收能力。
4. 脚本在高压力且安全时请求宿主；宿主只允许来源已安装的 ChatGPT userscript 请求自身所在的非活动标签页，并调用 Chrome `tabs.discard()`。被 discard 的标签页在再次激活时由 Chrome 重新加载，任务依靠现有持久化/恢复机制继续。
5. 发送、上传附件、审批、导航、未保存草稿等危险窗口禁止自动回收；活动标签页不得被静默 discard，需显示用户提示。
6. 内存清理、宿主能力不可用或指标不支持时都要有可解释的降级状态，不得假装已经释放整个浏览器进程。

## 已观察根因假设

- userscript 现有任务日志在单个任务上没有条数/总量上限，长期运行会让 localStorage 载荷与工作台重绘成本持续增长。
- attachment dispatch context 强引用 composer DOM 节点；SPA 重渲染/路由变化可能保留脱离文档的 ChatGPT DOM 子树。
- 预览 Blob URL、事件监听器与旧实例生命周期若未完全清理，会保留文件和旧闭包。
- 5.7 GB 更可能是 ChatGPT renderer/React 对话 DOM、媒体缓存或页面自身对象与 userscript 增长的叠加；userscript 不能从网页上下文准确读取整个标签页进程 RSS，也不能强制 GC。

## 验收重点

- 在支持 Chromium `performance.memory` 的页面上显示有限的 JS heap 估算（used/limit/ratio），不把它命名为标签页总内存；不支持时显示“指标不可用”。
- 每个任务的消息历史有明确上限，保留任务目标、最新状态与最近日志；清理动作不删除任务、附件元数据或恢复 token。
- 旧 composer 不再被 attachment context 强引用；工作台 shutdown 会撤销预览 URL、清理文件引用、取消脚本事件监听与内存监测定时器。
- 手动清理先执行 userscript 自身的有界清理，再向宿主发送不含目标文本、附件内容或 token 的最小压力请求。
- 宿主返回 `discarded`、活动标签页拒绝、正在执行危险操作拒绝、冷却中、能力不可用等明确结果；不会因为脚本消息伪造 tab id 而回收其他标签页。
- 自动回收有冷却、连续压力采样和安全条件；回收后再次激活，现有任务状态/附件引用/恢复机制仍能继续。
- 覆盖脚本轻量回归、宿主消息桥接契约与静态安全契约；重型打包和真实 Chrome 现场证据由 GitHub Actions/Chrome 现场门禁完成。

## 开源优先调查

- [Chrome tabs API](https://developer.chrome.com/docs/extensions/reference/api/tabs)：官方 `tabs.discard()` 是宿主回收标签页内容的直接能力；它不会关闭标签页，重新激活时再加载内容。
- [Chrome Tab Discarding](https://developer.chrome.com/blog/tab-discarding)：官方说明 discard 会卸载后台标签页 renderer，激活时重新加载；因此它适合安全的非活动页，不适合发送/上传临界区。
- [Chrome Page Lifecycle API](https://developer.chrome.com/docs/web-platform/page-lifecycle-api)：页面生命周期的 freeze/discard 需要配合持久化与恢复，而不是依赖页面脚本继续运行。
- [ml3dev/drowzy](https://github.com/ml3dev/drowzy)（MIT）：以 `chrome.tabs.discard()`、定时扫描、保护活动/音频/固定/表单标签为核心，作为安全策略参考；不复制代码、不引入运行时依赖。
- [ChromeDevTools/devtools-frontend](https://github.com/ChromeDevTools/devtools-frontend)（BSD-3-Clause）：Memory/Performance 面板的分层观测思路可作诊断参考，但项目规模不适合作为 userscript 依赖。
- [greatsuspender/thegreatsuspender](https://github.com/greatsuspender/thegreatsuspender)（GPL-2.0，最近维护活动较旧）：验证标签页挂起能降低内存，但许可证、维护与安全风险不适合作为本项目依赖。

结论：不引入第三方运行时。复用 Chromium 官方 `tabs.discard()` 的宿主边界、Page Lifecycle 的持久化原则与 Drowzy 的保护/冷却思路；userscript 自身只做有界对象清理，真正的 renderer 回收由 MV3 宿主执行。
