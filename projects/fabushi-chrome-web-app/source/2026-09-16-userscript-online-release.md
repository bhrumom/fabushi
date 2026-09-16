# 2026-09-16 用户需求：先发布线上脚本版本

用户要求先把已经存在的 ChatGPT 自动确认油猴脚本 `v2.9.32` 发布到线上市场，
使客户端能够检测到严格递增的新版本。GitHub 仍是代码和安装包的唯一来源；市场
Worker 只发布经过固定提交、资产大小和 SHA-256 绑定的 GitHub Release 资产。

本轮明确约束：不运行、不新增脚本或插件 E2E。只执行轻量静态检查、受保护主分支
部署链路允许的非 E2E 校验，以及部署后的市场 API 只读回读。脚本源代码和 GitHub
Release 不在本任务中重复生成。

## 线上安装失败反馈：URL 必须绑定 commit

用户回读线上目录后安装 `chatgpt-auto-confirm@2.9.32` 时收到：
“GitHub 用户脚本 URL 没有固定到合同声明的仓库 commit。”

原因是目录的 `deploymentUrl` 和 userscript artifact URL 使用了 GitHub
`releases/download/v2.9.32/...` 地址；它能定位 Release 资产，但没有把 URL 路径固定到
安装合同声明的 40 位仓库 commit。扩展安装器要求 raw GitHub URL 的路径包含相同的
`sourceRef`，然后才会下载并校验 size/SHA-256。

修复目标：保留 GitHub Release 作为发布/说明链接，把实际 userscript artifact URL 改成
`https://raw.githubusercontent.com/<owner>/<repo>/<sourceRef>/<entry>`，并在生产目录回读
确认 `deploymentUrl`、`install.artifacts[0].source.url`、`releaseManifest.artifacts[0].source.url`
都绑定 `50569be0ab88909408ed8880a24c185906d760eb`。本轮仍不运行、不新增脚本/插件 E2E。
