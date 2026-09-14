# ADR-20260914：宿主受控导航与 Renderer 崩溃恢复边界

- portfolio project_id: FAB-P0001
- project_key: TFI
- task: TFI-USERSCRIPT-RECOVERY-014
- status: Accepted for implementation, delivery pending
- date: 2026-09-14

## Context

多个 ChatGPT 任务共享一个浏览器标签页时，脚本会在不同会话之间切换。网页脚本不能可靠区分 renderer 崩溃、unloaded/error 页面和普通页面路由切换；同时，快速连续的完整文档导航会放大 ChatGPT renderer 崩溃概率。仅由脚本在页面内自旋无法覆盖页面已经停止执行的窗口。

## Decision

增加一个由 Fabushi MV3 service worker 实现的 tab-navigation-guard capability：

1. content bridge 只转发有界的 ownerTabId、taskId、taskURL、targetURL、phase、round、goalRevision、reason、force/recovery 元数据。
2. service worker 使用真实 sender tab id，并在请求前重新读取 tabs 状态；只允许 ChatGPT origin、根页或单一 conversation route。
3. 普通导航受 per-tab 30 秒冷却、5 分钟 6 次短窗和 60 秒熔断控制；in-flight 请求 20 秒内去重。recovery/force 只用于已存在恢复票据的有限接管。
4. tabs.onUpdated/onRemoved 清理 in-flight/记录；chrome-error://、崩溃标题、discarded、unloaded、loading 视为不可用并拒绝普通切页。
5. userscript 仍保留同等本地节流。permit 返回后必须重新校验 task generation 与 sessionStorage 一次性票据，再执行 location.replace; 拒绝只安排延迟重试，不消费票据。
6. renderer recovery 与 navigation guard 分离：recovery watchdog 可发现页面已失效，但不得代替脚本确认任务仍可恢复；所有恢复最终回到任务/轮次/附件元数据的持久化状态。

## Alternatives

- 仅依赖 userscript：页面崩溃后没有执行上下文，不能检测宿主级 renderer 事实；拒绝。
- 每次切换都 location.reload/assign：会产生无界导航压力，且无法保证任务代次；拒绝。
- 引入通用页面生命周期第三方依赖：当前 MV3 需求只需少量 host-side 状态，增加依赖和更新面收益不足；拒绝。

## Consequences

正面：导航压力受控，crash/unloaded 可以在脚本停止执行后被宿主发现；过期/跨任务票据 fail-closed；没有任务正文或附件字节进入 host state。代价：宿主能力不可用时恢复会按本地节流降级；Web Store 更新和实际现场证明仍需独立验收。
