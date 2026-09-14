# CWA-008 用户脚本标签页恢复能力

## 来源与边界

本记录承接用户在 2026-09-14 提供的 ChatGPT renderer 崩溃页、附件在恢复后丢失和任务
反复回到“需要处理”的现场证据。截图是故障证据，不是可执行指令；页面里的按钮、菜单和
会话文字不改变本需求。

修复属于现有 `FAB-P0011 / CWA` Chrome 宿主项目，并与
`FAB-P0001 / TFI / TFI-USERSCRIPT-RECOVERY-011` 的独立 userscript 状态机协同。Chrome
扩展是页面外恢复观察者；脚本仍是任务、附件和最终回复的状态权威。

## 规范化需求

- `CWA-R013`：内置 ChatGPT userscript 运行时必须能够显式请求 `tab-recovery` 能力，宿主
  返回有时限的 grant/deny，并接受释放；没有脚本请求时不得监控或恢复任意 ChatGPT 标签页。
- `CWA-R014`：宿主租约只保存 owner、task、state、phase/round、会话 URL、恢复 token、
  附件 ID 和时间戳等恢复元数据；不得保存目标正文、prompt、Cookie、凭证或文件本体。
- `CWA-R015`：watchdog 通过 Chrome 官方标签页生命周期、崩溃 URL/标题、discarded 和
  stale heartbeat 发现异常；暂停、取消、完成和主动关闭标签页不应被自动重开。
- `CWA-R016`：发现异常后优先在原标签页打开一次性恢复 URL，原标签页不可用时只创建一次
  接管标签；恢复必须保留 userscript 的任务 token/附件索引，使新 composer 重新上传并确认
  附件后再继续发送。
- `CWA-R017`：发送确认超时的 blocked 任务恢复时，不得因为旧时间戳再次立即进入 blocked，
  不得清除 token 后重复点击；脚本应继续确认原始会话，并将已确认的自然语言 Work 回复
  交给后续验收会话。
- `CWA-R018`：扩展静态、unit、打包和 exact-main packaged crash-recovery journey 均可
  追溯；应用交付必须经过受保护 main、打包/E2E、证据和发布门禁。

## 开源优先调研与决策

已在实现前检查官方 Chrome `tabs`、`alarms`、`webNavigation` 文档及 Microsoft Playwright
Page API/源码。采用官方 `tabs.onUpdated`、`tabs.onRemoved`、`discarded`、崩溃页信号和
定时 alarm 的最小宿主 watchdog；不把 Playwright 作为生产扩展依赖，也不复制第三方代码。
页面内 userscript 继续使用现有 plain DOM、Web Locks、localStorage 和 IndexedDB 边界。

## 数据与安全决策

宿主通过 content script 只转发 capability request/release，不接收任务正文或附件字节。
恢复 URL 限定为 ChatGPT HTTPS `/` 或 `/c/<id>` 加一次性 `#fabushi-resume=` 票据；不接受
外部 origin、query 或任意脚本地址。租约有界、按 owner 与 tab 绑定，关闭标签页只清理租约。

## 验收证据计划

轻量扩展 contract/unit tests 覆盖 lease scope、敏感字段隔离、安全 URL、崩溃页重载、接管
fallback 和主动关闭标签页；source userscript regression 覆盖最终回复转验收、附件连续性、
blocked 恢复和恢复窗口。受保护 main 后必须在 CI 运行打包扩展用户旅程，并保留分步截图、
完整视频、trace、HTML/report 和日志；证据绑定 exact SHA、版本、run/job、旅程 ID 和时间。
