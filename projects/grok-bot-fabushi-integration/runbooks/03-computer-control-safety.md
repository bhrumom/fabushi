# Computer Control Safety Runbook

Owner: platform capability + security owner
Last validated: pending GBF-407/702

当出现 target mismatch、异常连续输入、授权失效、replay、无法停止操作时：

1. 立即 revoke 当前 computer-control grant，并阻止新动作。
2. 停止键鼠/浏览器/窗口 action queue；不可继续“尝试修复”用户界面。
3. 保留非敏感 correlation/target/capability/error 元数据，不保存多余屏幕私密内容。
4. 验证目标窗口/tab identity 是否漂移，检查 grant scope/expiry/replay token。
5. 只有用户重新授权且安全检查通过后才恢复。
6. 运行 deny/revoke/replay/recovery E2E，并更新风险/evidence。
