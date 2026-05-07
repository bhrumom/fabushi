# Draft PR 转 Ready 重开规则

当一条 draft PR 已经拿到真实的 head checks，但工具链仍无法把它稳定转成 ready for review 时，不要把它继续停留在 draft 中间态。

## 适用条件

满足以下条件时，默认进入这条收口规则：

- 当前 PR 是 draft
- 当前 head SHA 已经有真实 workflow run 或必需检查结果
- 仓库仍要求通过 ready PR / merge queue 路径推进
- 当前工具或接口在执行 draft -> ready 时持续报错，不能可靠转正

## 默认处理方式

1. 先记录当前 draft PR 编号、head SHA、已有 checks 结果，以及转正接口失败的具体错误。
2. 在旧 draft PR 线程说明：这条线不是因为代码未准备好而关闭，而是因为“已验证 head 无法稳定转 ready”。
3. 关闭旧 draft PR。
4. 基于同一 head branch 立即重开一个 ready PR。
5. 在新的 ready PR 里明确说明：
   - 复用了哪条 head branch
   - 复用了哪次已存在的 checks
   - 为什么要从 draft 改为重开 ready，而不是继续等待接口恢复
6. 如果仓库使用 merge queue，新的 ready PR 应继续启用 auto-merge 或进入 queue，而不是停在“已开 PR”状态。

## 判定重点

- 这不是开新需求，而是把同一条已验证分支重新挂回可合并路径。
- 只要新的 ready PR 已经建立，旧 draft 就不应继续被视为活跃主线。
- 如果新的 ready PR 仍然没有 head checks，再把问题升级为 workflow 触发缺口继续追。

## 与既有规则的关系

- 如果 draft PR 本身没有任何 head checks，优先使用运行手册里的“Draft PR 无检查收口规则”。
- 如果 draft PR 已经有 checks，但卡在转 ready 的接口故障，这条规则是对现有 runbook 的补充分支。
