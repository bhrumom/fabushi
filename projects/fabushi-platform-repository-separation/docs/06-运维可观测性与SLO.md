# 运维可观测性与 SLO

本项目不是单一运行时服务，因此没有统一的用户请求 SLO。迁移过程的可观测对象为：

- 目标仓库创建状态、默认分支、branch protection 和 commit SHA；
- 导出源/目标 refs、路径计数、对象完整性和 artifact checksum；
- 各平台/CLI CI 成功率、耗时、缓存命中、打包产物和部署/Release 状态；
- updater、Cloudflare、Chrome Web Store、App Store、Google Play 和 CLI 下载入口的可达性。

每个运行时平台和 CLI 在自己的仓库维护 SLI/SLO 和 runbook；PRS 只保留链接与迁移期间的
证据索引。
