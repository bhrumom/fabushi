# Runbooks

本目录保存 Grok->Fabushi 融合后可重复执行的高风险运维流程。runbook 本身不能替代对应平台/E2E 验证。

- `01-capability-rollback.md`：能力/feature gate 回滚
- `02-host-recovery.md`：host 进程故障恢复
- `03-computer-control-safety.md`：电脑控制异常安全处置

Owner: affected runtime/platform owner。每个 runbook 在对应实现任务完成时必须记录 last validated date 和证据；当前尚未完成运行时实施，因此验证状态为 pending。
