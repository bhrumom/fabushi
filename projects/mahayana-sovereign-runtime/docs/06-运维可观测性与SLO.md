# 06 运维可观测性与 SLO

Runtime-relevant project; not N/A.

Initial SLO targets to formalize during implementation:
- deterministic operation/session IDs across surfaces;
- explicit terminal status for every supervised operation;
- no silent fallback from local agent runtime to remote agent runtime;
- recoverable snapshots for long-running tasks where declared supported;
- observable tool/approval/workflow state transitions.

Telemetry must avoid secrets and private prompt contents by default. Task MSR-104 will define concrete latency/reliability metrics and dashboards after capability inventory identifies production paths.
