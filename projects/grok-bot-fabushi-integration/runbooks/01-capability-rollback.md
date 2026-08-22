# Capability Rollback Runbook

Owner: affected capability/release owner
Last validated: pending GBF-802

1. 确认触发条件：权限绕过、敏感泄漏、数据/执行副作用异常、关键崩溃或 E2E 回归。
2. 优先 revoke/disable 对应 capability 或 feature gate，阻止新动作。
3. 保存 correlation IDs、版本、平台和非敏感错误证据。
4. 验证拒绝路径：禁用后新请求必须 fail closed。
5. 若需代码回滚，只回滚最小实施 PR/commit；禁止恢复历史 Grok 整分支。
6. 运行 affected smoke/E2E 与安全 denial tests。
7. 更新 evidence、incident/风险状态和 release 记录。

外部不可逆副作用不能用代码回滚伪装为已撤销，必须单独处置和记录。
