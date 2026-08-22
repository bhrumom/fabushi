# Host Recovery Runbook

Owner: host/runtime owner
Last validated: pending GBF-602/802

1. 识别 host crash/unresponsive 与关联 session/correlation id。
2. 停止继续派发高风险 capability，进入 fail-closed 状态。
3. 重启 host，并只恢复可幂等/有 checkpoint 的工作。
4. 对具有外部副作用的未知结果动作不得自动重放；先查询/确认结果。
5. 重新建立 IPC/schema handshake，验证版本一致。
6. 运行 health check、最小 tool smoke 和 recovery E2E。
7. 记录 crash cause、restart result、重复副作用检查和 evidence。
