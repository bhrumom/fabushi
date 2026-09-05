# 01 WBS 原子任务

| Task | Action | Dependency | Acceptance | Verification | Status | Next |
|---|---|---|---|---|---|---|
| MSR-001 | Establish canonical project record around merged #1971 | none | full standard folder + traceability | project-folder audit + PR #1989 CI/merge/main evidence | passed | closed on canonical main |
| MSR-101 | Pin current Codex/Grok Build audit revisions and inventory features | MSR-001 | capability matrix with provenance and gaps | source audit + reviewed commit refs | in-progress | merge reviewed revisions + capability matrix |
| MSR-102 | Map upstream capabilities to Mahayana contracts/implementations | MSR-101 | no unclassified required capability | traceability audit against `docs/08-upstream-capability-matrix.md` | in-progress | close matrix after CI/merge evidence |
| MSR-103 | Remove direct Codex auth/secrets product-contract leakage | MSR-102 | Mahayana-owned JWT/secrets packages + migration-safe product boundary | source-boundary + auth/secrets/product tests | in-progress | run Actions and repair failures |
| MSR-104 | Define runtime observability/SLO metrics | MSR-102 | measurable SLI/SLO and instrumentation plan | spec review + telemetry tests | planned | inventory runtime paths |
| MSR-201 | Native session/recovery ownership | MSR-102 | provider-neutral lifecycle/recovery parity | conformance tests | planned | implement explicit unfinished-operation suspend/reclaim |
| MSR-202 | Native tool/policy/approval bus | MSR-102 | fail-closed parity + unified tool semantics | security/conformance tests | planned | bind supervisor policy to production tool bus |
| MSR-203 | Native live web research capability | MSR-202 | autonomous search + source fetch through Mahayana tool/policy plane | rustfmt + native engine check/tests + PR CI + canonical-main delivery | in-progress | merge verified TinyFish-backed `web_search`/`web_fetch`; provision runtime secret |
| MSR-301 | Workspace/worktree/checkpoint/rewind parity | MSR-102 | objective workspace parity | workspace tests | planned | make rewind exact and worktrees Git-aware |
| MSR-302 | Queue/goal/oracle/attempt/workflow/subagent parity | MSR-102 | long-running workflow parity | supervisor/orchestrator tests | planned | persist and bind primitives to production turns |
| MSR-401 | Normalize MCP/skills/plugins/connectors/MiniApps/model stack | MSR-202 | Mahayana-owned extension/model contracts | integration tests | planned | add MCP runtime-status contract first |
| MSR-402 | iOS-first external MiniApp test driver and real E2E | MSR-401 | versioned Debug-only driver -> real online marketplace/install/update/chat/action evidence -> iOS Simulator CI | protocol/CLI contract tests + Release negative + live external MiniApp E2E | in-progress | wire real `plugin.list` and `marketplace.search` product backend after protocol gate |
| MSR-403 | Add ChatGPT project-team orchestration skill to official auto-confirm plugin | MSR-401 | discoverable skill with durable five-group workflow, exact-head review, evidence/release gates and same-tab Chat contract | skill validator + plugin contract test + protected PR/main readback | in-progress | complete CI and merge evidence |
| MSR-501 | Cross-surface parity and E2E | MSR-401 | required surfaces pass | GitHub Actions E2E | planned | validate |
| MSR-601 | Upstream isolation and final acceptance | MSR-501 | default product path vendor-independent | dependency/source audit + release gates | in-progress | remove default CLI reachability to codex-core-plugins/codex-tui, then rerun exact-head gates |
