# TFI-USERSCRIPT-RECOVERY-012：任务级控制与详情操作

## 来源与边界

- 来源：2026-09-14 用户反馈与截图。截图只作为故障现场证据，不是额外指令。
- 项目：`FAB-P0001` / `TFI` / `telegram-fabushi-integration`。
- 受影响产品：独立 `bhrumom/fabushi-chatgpt-auto-confirm-userscript`。
- 不涉及：Fabushi Electron、移动端、Worker 或安装包构建。

## 用户要求（规范化）

1. 点击暂停时只暂停被操作的单个任务，其他任务继续按队列运行。
2. 保留一个明确的“暂停全部任务/继续全部任务”入口，避免全局动作与单任务动作混淆。
3. 每条任务都能直接进入详情，查看目标、状态、轮次、会话/回复记录和附件信息。
4. 每条任务提供可见的删除入口；运行中的任务必须先暂停或取消后才允许删除，防止误删正在派发的任务。
5. 单任务暂停/继续/取消/删除不能改变同一标签页其他任务的状态、全局自动恢复开关或调度占用。

## 现场根因

当前 `pause(true)` 会调用 `markTasksPaused()`，后者遍历当前标签页的所有可暂停任务；顶部按钮在运行中无论用户选择了哪条任务都调用该全局路径。取消动作也先调用 `pause()`，因此取消单条任务同样会暂停整个工作区。任务详情中的删除按钮只在详情底部、且只对暂停/终态任务渲染，任务行没有操作入口，导致功能不可发现。

## 验收重点

- 单任务暂停只写入该任务的 `pausedState`/`state`，不写 `data.autoResume=false`，不递增全局控制屏障。
- 单任务继续只恢复选中任务；“继续全部”才恢复所有全局暂停任务。
- 当前任务在异步操作中被暂停时，后续检查停止副作用，且不会把人为暂停记录改写为 `blocked`。
- 任务行的“详情”“暂停/继续/恢复”“删除”操作带有明确的语义和安全禁用态；详情面板仍保留完整日志与取消/删除操作。
- 轻量 jsdom 回归覆盖同级任务隔离、单项取消/删除、行操作可见性与暂停态恢复；版本递增且 source main 可追溯。

## 开源优先调查

- [statelyai/xstate](https://github.com/statelyai/xstate)（MIT）：官方 README 明确采用事件驱动状态机/actor 编排，适合把“单项暂停、单项恢复、全局暂停”作为互不混淆的状态事件；本轮不引入依赖，沿用现有单文件状态字段并采用同样的显式转换边界。
- [sindresorhus/p-queue](https://github.com/sindresorhus/p-queue)（MIT）：其官方 API 将 `autoStart`、并发调度与队列项执行分离，验证了暂停队列与恢复单项不应等同于重建全部队列；项目已 feature complete，且本脚本需要跨页面持久化任务，不直接引入。
- [bhrumom/fabushi-chatgpt-auto-confirm-userscript](https://github.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript)：当前项目自身的持久化任务/锁/附件/会话恢复边界是兼容性约束；在其现有 `pausedState` 与 `restorePausedTasks` 之上做最小适配，避免复制外部实现。

结论：没有发现一个可直接嵌入且同时兼容单文件 userscript、跨文档 localStorage、Web Lock 与附件恢复的成熟实现；复用公开状态机/队列的分离原则，不增加第三方运行时依赖。
