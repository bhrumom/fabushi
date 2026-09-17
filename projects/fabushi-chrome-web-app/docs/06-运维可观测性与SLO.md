# 运维可观测性与 SLO

目标：native bridge 500ms 内开始重连、指数退避上限 30s；浏览器请求默认 10s、最大
60s；桌面产品请求默认 30s、最大 60s；每标签 Debugger 操作串行。UI 和 browser
session inventory 展示连接状态、错误、generation、标签数量和 owner。

日志记录 native disconnect/error、拒绝的 origin/ID/secret、陈旧 claim、Debugger
detach、下载超时和平台请求失败，但不记录密码、Cookie、token 或敏感输入。CI 摘要
记录 cache hit/miss、来源 SHA、包校验和、测试与 evidence artifact。运行恢复步骤
见 runbooks/chrome-migration.md；无独立生产 dashboard 时以桌面 Host lifecycle 和
CI evidence 为权威遥测。

userscript recovery 的可观测字段限于 capability grant/deny、lease expiry、检测原因、
原标签 reload/takeover 动作、恢复次数和最终状态；不记录目标正文、prompt、附件字节或
凭证。当前目标为检测到异常后一次有界恢复，连续失败进入可见任务状态并保留 token，禁止
watchdog 无界刷新或重开。精确延迟、成功率和误恢复率在 canonical-main packaged journey
与真实 Chrome 样本后建立基线。
