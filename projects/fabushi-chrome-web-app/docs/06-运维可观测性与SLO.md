# 运维可观测性与 SLO

目标：native bridge 500ms 内开始重连、指数退避上限 30s；浏览器请求默认 10s、最大
60s；桌面产品请求默认 30s、最大 60s；每标签 Debugger 操作串行。UI 和 browser
session inventory 展示连接状态、错误、generation、标签数量和 owner。

日志记录 native disconnect/error、拒绝的 origin/ID/secret、陈旧 claim、Debugger
detach、下载超时和平台请求失败，但不记录密码、Cookie、token 或敏感输入。CI 摘要
记录 cache hit/miss、来源 SHA、包校验和、测试与 evidence artifact。运行恢复步骤
见 runbooks/chrome-migration.md；无独立生产 dashboard 时以桌面 Host lifecycle 和
CI evidence 为权威遥测。
