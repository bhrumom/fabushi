# 01 WBS 原子任务

Statuses: `planned`, `in-progress`, `blocked`, `passed`, `failed`.

| ID | Action / deliverable | Dependency | Acceptance | Verification | Status | Next action |
|---|---|---|---|---|---|---|
| DHRF-001 | Establish governed project folder and pinned intake | none | standard scaffold, source pin, roadmap/WBS/acceptance/ADR/evidence exist on main | repository audit | in-progress | merge project folder |
| DHRF-101 | Inventory upstream packages/tools/events/config/persistence/user surfaces at pin | DHRF-001 | no unclassified required capability | source/package/test inventory review | planned | inspect pinned tree |
| DHRF-102 | Audit existing `mahayana-harness*` and integration code | DHRF-101 | every upstream row mapped to code/test/gap | code + CI evidence audit | planned | inspect all Harness crates |
| DHRF-103 | Freeze parity/gap matrix and task ownership | DHRF-102 | every required gap owns a task or explicit rejection | traceability review | planned | normalize matrix |
| DHRF-201 | Close service/plugin scoped and reversible composition parity | DHRF-103 | mount/unmount/scope/provider replacement semantics pass | Rust tests | planned | design/implement |
| DHRF-202 | Close profiles/bundles/patch overlay/config inspection parity | DHRF-103 | deterministic precedence/load/dump tests pass | Rust tests | planned | implement loaders |
| DHRF-203 | Close session persistence/replay/fork/resume/query/FTS/recovery | DHRF-103 | durable state and crash/replay scenarios pass | Rust integration tests | planned | select store strategy |
| DHRF-204 | Close prompt sections/model-visible invariant/compaction | DHRF-103 | all model-visible inputs reconstructable; compaction deterministic | property/conformance tests | planned | implement service |
| DHRF-301 | Close tool pipeline/interceptors/approvals/default guards | DHRF-103 | pre/execute/post and fail-closed approval scenarios pass | security/conformance tests | planned | bridge ToolHost |
| DHRF-302 | Register fs/subprocess/shell/PTY/LSP/code runtime providers | DHRF-301 | supported capabilities work through one provider seam | integration tests | planned | map providers |
| DHRF-303 | Unify sandbox/capability policy | DHRF-301 | filesystem/process/network/sandbox denial/allow scenarios pass | security tests | planned | design policy seam |
| DHRF-304 | Bridge MCP/web search/fetch/attachments/spill | DHRF-301 | supported providers and content lifecycle pass | integration tests | planned | map existing services |
| DHRF-401 | Close agent loop/inbox/turn/step/cancel/recovery semantics | DHRF-203,DHRF-301 | lifecycle conformance scenarios pass | state-machine tests | planned | implement gaps |
| DHRF-402 | Close subagents/teams/goals/jobs/todo/plan/presets | DHRF-401 | persistence/resume/coordination scenarios pass | integration tests | planned | implement gaps |
| DHRF-403 | Close workflows/hooks/schedule/background execution | DHRF-401 | pause/resume/cancel/restart scenarios pass | orchestrator tests | planned | bridge executor |
| DHRF-404 | Add repetition/deadline/loop/self-extension guards | DHRF-301,DHRF-401 | unsafe/unbounded scenarios terminate or require policy | security/stress tests | planned | define defaults |
| DHRF-501 | Close LLM streaming/settings/credentials/identity seams | DHRF-103 | provider replacement/stream/cancel/credential-reference tests pass | model/security tests | planned | bridge model/product |
| DHRF-502 | Expose canonical Harness Host ABI, SDK, ACP and headless commands/events | DHRF-401,DHRF-501 | protocol contract tests pass | Host/ACP tests | planned | extend protocol |
| DHRF-503 | Wire supported Electron/iOS/Android/Web/CLI surfaces | DHRF-502 | capability negotiation and affected E2E pass | GitHub Actions E2E | planned | surface integration |
| DHRF-504 | Bridge skills/plugins/artifacts/preset loaders | DHRF-201,DHRF-202 | installed extension lifecycle passes | plugin integration tests | planned | bridge runtime |
| DHRF-601 | Build pinned upstream scenario conformance corpus | DHRF-201..DHRF-504 | all required matrix rows have objective scenario evidence | CI conformance suite | planned | derive scenarios |
| DHRF-602 | Complete security/license/provenance/supply-chain gate | DHRF-601 | no unresolved critical findings; notices complete | security/license CI | planned | audit |
| DHRF-603 | Define and pass performance/reliability/stress budgets | DHRF-601 | agreed budgets pass | benchmark/stress CI | planned | baseline then gate |
| DHRF-701 | Switch accepted Rust-native Harness path to product defaults | DHRF-601,DHRF-602,DHRF-603 | default paths use accepted native providers | integration/E2E | planned | staged switch |
| DHRF-702 | Remove duplicate/obsolete compatibility paths and finalize notices | DHRF-701 | no required behavior depends on obsolete path | dependency/source audit | planned | cleanup |
| DHRF-703 | Release, post-merge verification and project closure | DHRF-702 | all DoD gates/evidence pass on canonical main | release/E2E/main audit | planned | close project |
