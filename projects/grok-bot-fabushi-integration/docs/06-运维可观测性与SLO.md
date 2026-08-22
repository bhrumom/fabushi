# 06 运维、可观测性与 SLO

## SLI

- Agent first-event latency / turn completion
- tool/capability round-trip latency and error rate
- host process start/crash/restart success
- IPC schema/transport failure rate
- permission deny/expire/replay events
- computer-control action success/target mismatch
- renderer crash/unresponsive/resource usage
- animation frame time / reduced-motion fallback

## SLO

当前未建立真实性能基线，因此暂不填虚构数字。M1/M2 测量后，GBF-604 负责把可执行阈值固化并加入 regression gate。安全不变量（无未授权能力执行、敏感输入不可重放）不是“百分比 SLO”，而是必须满足的 release gate。

## Telemetry

renderer -> IPC -> host -> Mahayana -> tool result 使用 correlation id；日志结构化并对 secrets/PII 做最小化与脱敏。每个能力定义错误码、健康检查和用户可见降级行为。

## Alerts / incident signals

高频 host crash、权限异常、target mismatch、replay rejection 激增、关键 E2E/CI 回归、资源持续异常均触发调查。恢复流程见 `runbooks/02-host-recovery.md`；computer-control 安全处置见 `runbooks/03-computer-control-safety.md`。
