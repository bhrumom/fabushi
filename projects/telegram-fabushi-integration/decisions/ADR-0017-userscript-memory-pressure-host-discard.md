# ADR-0017 — Userscript 内存压力由宿主安全回收非活动标签页

- 状态：Proposed
- 日期：2026-09-14
- 项目：`FAB-P0001 / TFI`
- 相关任务：`TFI-USERSCRIPT-RECOVERY-013`

## 背景

普通 userscript 可以释放自己持有的数组、Map、Blob URL 和监听器，但不能读取 Chrome 标签页进程 RSS、强制 V8 GC 或调用 Chrome 的标签页 discard API。当前 ChatGPT 页面自身的 React/对话 DOM、媒体/附件资源与 userscript 累积可能共同导致高内存。

## 决策

1. userscript 使用可选 Chromium `performance.memory` 作为“网页 JS 堆估算”诊断，不能把它当作整个标签页进程内存；不支持时明确标记。
2. userscript 对日志消息和瞬态资源做有界清理；不清除任务目标、附件元数据、恢复 token 或当前调度所需状态。
3. userscript 通过页面 `postMessage` 发出最小 `tab-memory.request`，仅包含压力级别、JS heap 数值、页面可见性、是否安全等布尔/数值诊断，不包含任务文本或附件内容。
4. MV3 宿主从 `sender.tab.id` 得到真实标签页，验证已安装/启用的 `chatgpt-auto-confirm` 记录、批准的 ChatGPT URL、非活动/非 discarded/安全状态和冷却；通过 `chrome.tabs.discard(tabId)` 回收。
5. discard 只适用于隐藏且安全的标签页。激活后由 Chrome 重载页面，既有 localStorage/IndexedDB、workspace heartbeat、recovery ticket 和 pagehide/pageshow 机制负责恢复；危险窗口由脚本 fail-closed，不做自动重载。
6. host capability is local-only and cannot become a generic remote code or arbitrary tab-control endpoint.

## 备选方案

- 只调用 `performance.memory`：拒绝，无法释放 ChatGPT renderer。
- 在网页里调用 `window.gc()` 或依赖 DevTools：拒绝，非生产权限且无法作用于整个进程。
- 自动 `location.reload()`：拒绝作为默认高压动作，会打断活动任务/上传并不能保证释放 renderer 进程。
- 引入 Great Suspender：拒绝，GPL-2.0、维护/安全风险和产品边界不合适。
- 直接复制 Drowzy：拒绝；只吸收保护、冷却和非活动标签页 discard 原则。

## 结果

优点：实际 renderer 回收能力位于有权限的宿主；活动/危险任务不被打断；script/host 责任清晰；回收后现有持久化恢复链可复用。

代价：Chrome 只允许 discard 非活动标签页；页面指标不完整；重新激活存在一次加载成本；真实 Chrome 和 packaged evidence 仍需验证。
