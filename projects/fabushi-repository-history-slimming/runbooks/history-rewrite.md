# History rewrite runbook

## Prepare

1. 从 GitHub 实时获取 heads/tags，保存 `name -> old OID`；同时读取并保存 branch/ruleset/tag protection 状态。
2. 在新的 bare/sparse 隔离目录执行分析；不使用当前开发工作树，不读取或输出浏览器 cookies/token。
3. 运行已审核的 git-filter-repo 路径规则，保留产品资产清单。
4. 对比 old/new refs、关键路径、对象可达性和 pack/LFS 体积；任何意外删除都停止。

## Migrate

1. 向维护者展示迁移前后清单和回滚方案。
2. 仅在动作前确认后，临时调整最小范围的 `main`/tag 写入保护；不要改变账号权限。
3. 使用逐 ref lease + 原子策略推送 heads/tags；不覆盖未在快照中的新 ref。
4. 立即恢复原规则，不等待其他工作。

## Verify and rollback

验证 GitHub ref 集合、关键路径、`git fsck --full`/connectivity、规则状态和项目记录。若失败，停止并按原始 `name -> OID` 清单恢复 refs，再恢复规则；保留失败证据，不宣称完成。

## Safety

不要运行本机应用构建、测试、模拟器或打包命令。不要删除工作树中的用户文件或无关缓存；本项目只处理隔离历史镜像和明确的 GitHub refs。
