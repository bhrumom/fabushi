# 2026-09-14 用户脚本并行切页与 Renderer 崩溃需求

- portfolio project_id: FAB-P0001
- project_key: TFI
- source type: 用户最新明确需求 + Chrome 现场截图
- source date: 2026-09-14 Asia/Shanghai
- related task: TFI-USERSCRIPT-RECOVERY-014
- evidence image: /var/folders/4z/gvj_d2ln1w312_z35t6tv9pw0000gn/T/codex-clipboard-c7853c1c-ad7e-4686-9fbc-60c267cd9ab0.png

## 原始需求归纳

1. 两个任务并行监督、页面来回切换时，切回已结束会话必须识别为结束，并开启新的会话继续 Work/验收；不能继续停留在已经结束的旧会话。
2. 如果仅靠网页脚本无法可靠感知宿主标签页/renderer 的崩溃，则由 Fabushi Chrome 插件提供宿主能力，脚本显式请求该能力。
3. 循环切页期间不能快速重复导航、刷新或重放发送；发生 ChatGPT renderer 崩溃、unloaded/error 页面或宿主暂时拒绝时，脚本必须保留任务、轮次、会话 URL、附件元数据和恢复票据，并在安全冷却后继续。
4. 更新当前 Chrome 上的 Fabushi 插件，并发布脚本和插件的新版本。

## 约束与验收边界

- 导航请求必须绑定真实 owner tab、task、phase、round、goalRevision；过期票据不得恢复旧轮次或已完成/暂停任务。
- 导航能力只接收有界元数据，不传输 goal、prompt、附件字节或页面正文。
- 宿主恢复仅在页面不活跃、未发送/上传/审批/草稿/导航等不安全状态时工作；活动页面和有未保存状态时 fail-closed。
- 必须有独立的本地节流作为无插件/插件断连时的安全下限。
- 发布前以 GitHub Actions 完成脚本回归、Chrome 扩展打包与 packaged user journey；不在开发机执行应用构建或重型测试。

## 开源优先调研

- WICG Page Lifecycle：https://github.com/WICG/page-lifecycle，参考页面 hidden/frozen/discarded/terminated 生命周期与恢复时序。
- GoogleChromeLabs page-lifecycle：https://github.com/GoogleChromeLabs/page-lifecycle，参考将页面外生命周期状态归一化为可观察事件的做法。
- Playwright BrowserContext：https://github.com/microsoft/playwright/blob/main/docs/src/api/class-browsercontext.md 与 Playwright frame source：https://github.com/microsoft/playwright/blob/main/packages/playwright-core/src/client/frame.ts，参考跨页面/Frame 生命周期、导航和失效对象应被视为短生命周期句柄。

决策：不直接引入依赖，也不复制上游代码；将生命周期事实、宿主 capability lease、受限导航 permit 和一次性恢复票据适配到 Fabushi 现有 MV3 service worker 与 task workspace。采用上述项目验证过的 fail-closed、短生命周期和重新获取状态的原则。许可证/来源义务：仅使用公开架构与文档作为设计参考，未复制代码或新增第三方依赖。

## 预期结果

- 普通跨会话切换由宿主 tab-navigation-guard 统一做冷却、短窗计数、in-flight 去重和熔断。
- renderer 崩溃/unloaded 由宿主 tabs 生命周期与 recovery watchdog 识别；脚本收到 grant 后只执行一次受控原标签/新文档恢复。
- 页面恢复后按 task/phase/round/goalRevision 重新验证票据；无效票据被清理，不会误发旧任务。
- 脚本版本 2.9.24，Chrome 插件版本 0.6.2；两个发布物均可通过不可变 GitHub 来源校验。
