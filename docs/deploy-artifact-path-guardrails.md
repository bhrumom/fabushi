# Deploy Artifact Path Guardrails

本文档沉淀这轮主控在 `CD #128` / `issue #220` 里踩中的一条长期规则：**下游 deploy job 需要的 helper、脚本或配置，不能只放在 release artifact 的隐藏目录路径里。**

## 事故信号

这次主线失败发生在：

- Workflow: `CD - Staging API gated production deploy #128`
- Source SHA: `65dc9c7ebbb7465f3f456b512ba9e667fc201a77`
- 首个失败步骤：`Deploy staging environment -> Apply development D1 migrations`
- 直接报错：`bash: ../../.github/scripts/run-wrangler-d1-migrations.sh: No such file or directory`

根因不是 Cloudflare D1 本身，而是 deploy 依赖的 helper 虽然在 build job 里被复制了，但落在了 artifact 内的隐藏目录 `.github/scripts`。下载后的 artifact 没有把这条路径稳定带到下游 job，导致 deploy 在真正执行迁移前就先失败。

## 默认规则

对任何需要跨 job 传递到 release artifact 的脚本、helper、配置或元数据，默认遵循以下规则：

- 不依赖 artifact 内的隐藏目录路径，例如 `.github/`、`.something/`。
- 下游 job 需要直接执行的脚本，优先放到显式非隐藏目录，例如 `github-scripts/`、`release-metadata/`、`deploy-assets/`。
- build job 的复制路径和 deploy job 的运行路径要成对出现，并在同一轮改动里一起更新。
- workflow guardrail 必须同时检查：
  - 期望的非隐藏 artifact 路径存在
  - deploy job 的实际调用路径与打包路径一致
  - 旧隐藏路径没有继续残留在 workflow 中

## 适用场景

这条规则至少适用于：

- D1 migration retry helpers
- deploy 前后置 shell scripts
- release note / TestFlight / summary 生成脚本
- 任何不是由 checkout 重新取回，而是依赖 artifact 透传给后续 job 的仓库文件

## Fabushi 当前仓库的落地方式

当前仓库已按以下方式收口：

- build job 把 helper 放到 `release-artifact/github-scripts`
- deploy job 从 `../../github-scripts/run-wrangler-d1-migrations.sh` 调用 helper
- `.github/scripts/check-publish-cd-release.sh` 明确要求新路径存在，并拦截旧的 `.github/scripts` artifact / runtime 路径

## 何时复查

当出现以下任一信号时，优先先查这条规则，而不是立刻把问题归因为 Cloudflare、D1 或业务代码：

- deploy job 报 `No such file or directory`
- build job 明明打包了脚本，但下游 job 看不到
- workflow 新增 helper 后，build 阶段成功，deploy 却在 helper 启动前失败
- 同一个脚本在仓库工作目录可见，但在下载后的 artifact 目录不可见

## 主控处理要求

主控在遇到这类问题时，默认按以下顺序处理：

1. 先确认失败发生在脚本装箱/落盘路径，还是脚本执行本身。
2. 如果是 artifact 路径问题，优先修正 build/deploy 路径配对，不把它误判成外部平台故障。
3. 修复后把 guardrail 一起补上，避免同类问题再次靠主线红灯暴露。
4. 只有在 helper 真正进入目标执行路径后，才继续判断下游的 D1、Cloudflare 或其他外部系统是否仍有阻塞。
