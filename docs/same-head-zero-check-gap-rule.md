# Same-Head Zero-Check Gap Rule

当一个 ready PR 已经经历过“关闭旧 PR、基于同一 head branch 重开新 PR”的恢复动作后，如果新的 PR head 仍然是 `0 workflow run / 0 combined status`，就不应再把它当成普通等待。

## 适用场景

- 仓库要求必需检查，例如 `CI result`
- 旧 PR 已经因为 head 没有 checks 而被关闭重开
- 新 PR 复用了同一 head branch，但新的 `pull_request opened` 事件仍没有挂上任何 workflow run 或 status

## 默认判断

- 这时问题已经不只是“旧 PR 状态脏了”或“单次 opened 事件没挂上”
- 应把它升级为更真实的分支级触发缺口、结果挂载缺口，或需要基于最新 `main` 重建承载分支的信号
- 同一 head 上继续叠更多内容，只会把“内容价值”和“门禁挂载缺口”重新混在一起

## 默认动作

1. 记录旧 PR 号、新 PR 号、同一 head SHA 与缺失的必需检查
2. 明确说明：本次重开动作已经完成了它的验证价值，即成功排除了“只是旧 PR 事件脏了”的可能
3. 不再把该 PR 视为普通等待，而是转为后续主动收口对象
4. 下一步优先基于最新 `main` 重建新的承载分支，再观察 checks 是否恢复挂载
5. 只有新的承载分支也复现同类问题，才继续升级为更底层的 workflow 触发治理事项

## 为什么要记录

2026-05-08 的官网线 `#239` 就是一个明确样本：它关闭了旧 `#232` 并基于同一 head branch 重开，但新的 head `8b524a2dcd031003a3689fcd22db7e8c01e2e2f0` 仍然没有任何 workflow run 或 combined status。

这条规则的目的是让后续主控在遇到同类 ready PR 时，不再反复把它误判成“再等等看”，而是更快切换到“基于最新 main 重建承载分支”这一更有效的收口路径。
