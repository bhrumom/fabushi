# 01 WBS 原子任务

| Task | Action | Dependency | Acceptance | Verification | Status | Next |
|---|---|---|---|---|---|---|
| MSR-001 | Establish canonical project record around merged #1971 | none | full standard folder + traceability | project-folder audit + PR/CI/main evidence | in-progress | merge project baseline |
| MSR-101 | Pin current Codex/Grok Build audit revisions and inventory features | MSR-001 | capability matrix with provenance and gaps | source audit + reviewed commit refs | planned | start after baseline merge |
| MSR-102 | Map upstream capabilities to Mahayana contracts/implementations | MSR-101 | no unclassified required capability | traceability audit | planned | map nine domains |
| MSR-103 | Remove direct Codex auth/secrets product-contract leakage | MSR-102 | native interfaces + adapter boundary | source-boundary + auth tests | planned | design ADR |
| MSR-104 | Define runtime observability/SLO metrics | MSR-102 | measurable SLI/SLO and instrumentation plan | spec review + telemetry tests | planned | inventory runtime paths |
| MSR-201 | Native session/recovery ownership | MSR-102 | provider-neutral lifecycle/recovery parity | conformance tests | planned | implement |
| MSR-202 | Native tool/policy/approval bus | MSR-102 | fail-closed parity + unified tool semantics | security/conformance tests | planned | implement |
| MSR-301 | Workspace/worktree/checkpoint/rewind parity | MSR-102 | objective workspace parity | workspace tests | planned | implement |
| MSR-302 | Queue/goal/oracle/attempt/workflow/subagent parity | MSR-102 | long-running workflow parity | supervisor/orchestrator tests | planned | implement |
| MSR-401 | Normalize MCP/skills/plugins/connectors/MiniApps/model stack | MSR-202 | Mahayana-owned extension/model contracts | integration tests | planned | implement |
| MSR-501 | Cross-surface parity and E2E | MSR-401 | required surfaces pass | GitHub Actions E2E | planned | validate |
| MSR-601 | Upstream isolation and final acceptance | MSR-501 | default product path vendor-independent | dependency/source audit + release gates | planned | close project |
