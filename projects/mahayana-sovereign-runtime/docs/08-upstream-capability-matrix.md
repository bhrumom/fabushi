# 08 上游能力、来源与缺口矩阵

Updated: 2026-08-22

## Audited revisions

- OpenAI Codex: `343074d4207d572809bd8cea15f4be1d09d98e0b`
- xAI Grok Build: `19d42e35c07a9c9244f03f6df0c4c353f970d4f9`
- Fabushi convergence baseline: PR #1971 / merge `5dcfaee4b8fb12896f9ac92c6dbc51317d10b942`

This matrix records capabilities, not product identity. `native` means the canonical contract/implementation is Mahayana-owned. `adapter` means a vendor implementation remains behind a Mahayana boundary. `partial` means a native primitive exists but semantic parity or cross-surface acceptance is not yet proved. `gap` means implementation work remains.

## Codex capability mapping

| Capability | Upstream reference | Mahayana contract / implementation | State | Remaining acceptance |
|---|---|---|---|---|
| Fail-closed approvals | strict MCP auto-review outcomes | `mahayana-kernel::supervisor::{ApprovalOutcome, PermissionMemory}` + sandbox policy | native/partial | side-by-side denial/timeout/interruption conformance |
| Granular sandbox policy | Codex execution/sandbox policy | `mahayana-kernel/src/sandbox.rs` | native/partial | platform-specific process/filesystem/network conformance |
| Thread/session identity | app-server thread/session model | `mahayana-kernel` IDs/events + Agent backend boundary | native/partial | restart/resume/cross-surface lifecycle E2E |
| Unfinished turn suspension | `CodexThread::suspend_turn_and_shutdown` | supervisor pause/recovery primitives | partial | explicit unfinished operation suspension/reclaim contract |
| MCP inventory/runtime | MCP servers/connectors; runtime status added in `343074d` | `mahayana-mcp-runtime` stdio + Streamable HTTP | native/partial | add observable connection state without side-effectful reconnect |
| Skills/plugins/connectors | Codex skills/connectors/plugin machinery | Mahayana plugin/skill/connector Host surfaces | native/partial | unified extension conformance and cross-surface E2E |
| Model providers | Codex provider machinery | `mahayana-model`, `mahayana-native-engine`, Responses adapter | native/partial | provider feature/capability negotiation parity |
| Local coding loop/tool execution | Codex core/tools | Mahayana native engine + tool host | native/partial | broad tool semantic and failure-mode conformance |
| Authentication/JWT session support | Codex login | `mahayana-auth` | native in MSR-103 | CI compile/test + canonical main verification |
| Encrypted product secrets | Codex secrets | `mahayana-secrets` | native in MSR-103 | migration/keyring/platform CI + canonical main verification |
| Legacy Codex agent behavior | Codex app-server/core | `mahayana-agent-codex` | adapter | removable after native parity gates pass |

## Grok Build capability mapping

| Capability | Upstream reference | Mahayana contract / implementation | State | Remaining acceptance |
|---|---|---|---|---|
| Prompt queue / steering | queued messages and goal-mode queue edits | `mahayana-orchestrator::PromptQueue` | native/partial | live Agent-turn steering E2E |
| Goal/task lifecycle | long-running goal mode | `mahayana-kernel::supervisor::TaskSupervisor` | native/partial | bind every runtime turn to supervisor lifecycle |
| Objective verification oracles | objective-named CI oracles | `VerificationOracle`, `VerificationMode::ObjectiveRequired` | native | CI/oracle integration E2E |
| Attempt journal | shell/task attempt accounting | `AttemptRecord` + supervisor journal | native | persisted/resumed execution evidence |
| Repeated-action loop protection | two-tier warn/interrupt | `LoopPolicy`, `LoopState`, `LoopDisposition` | native | tool-bus integration E2E |
| Remembered approvals / permanent denial | permission memory | `PermissionMemory`, approval ledger/snapshots | native/partial | persistence + cross-surface UX conformance |
| Pause/resume | paused workflows visible | supervisor `Paused` state + pause/resume | native/partial | workflow/UI visibility and restart persistence |
| Workflow DAG | workflows/background tasks | `mahayana-orchestrator::Workflow` | native/partial | durable executor and recovery integration |
| Hooks | pre/post model/tool/workflow/checkpoint hooks | `HookRegistry` | native/partial | connect all hook points to production execution paths |
| Subagents | subagent scheduling/guards | `SubagentScheduler` | native/partial | resumable descendants, live-descendant suspension guard |
| Managed worktrees | projected/managed worktree behavior | `mahayana-workspace-engine::create_worktree` | native/partial | Git-aware registration/isolation and cleanup conformance |
| Checkpoint / rewind | checkpoint/rewind codecs | `WorkspaceEngine::{create_checkpoint,restore_checkpoint}` | native/partial | exact rewind semantics including created/deleted files |
| Codebase graph | codebase graph/indexing | `build_codebase_graph`, symbol index | native/partial | richer language/reference graph and incremental updates |
| Memory | session/project memory | `mahayana-orchestrator::MemoryStore` | native/partial | durable storage/retrieval policies and compaction integration |
| Headless/ACP | headless and ACP embedding | Mahayana CLI/Host/Harness boundaries | partial | explicit ACP compatibility endpoint and acceptance suite |
| Session search / foreign sessions | active/foreign session handling | Mahayana session/Host state | partial | indexed session search and adoption/recovery semantics |
| Circuit breaker / resilience | long-running resilience | `mahayana-kernel/src/resilience.rs` | native/partial | production telemetry and failure-injection tests |

## Fabushi/Mahayana differentiation

These are not inherited from either upstream and remain product-owned acceptance requirements:

1. Humans, AI agents, bots, services and MiniApps share Fabushi conversation/actor semantics rather than a coding-agent-only session model.
2. Electron, iOS, Android, Web and CLI consume one Mahayana command/event protocol with capability negotiation.
3. Local Agent execution and remote model inference are separate trust boundaries.
4. MCP, product tools, computer control, plugins, connectors and MiniApp actions converge on one Mahayana tool/policy plane.
5. Messaging, payments, marketplace and MiniApps remain Fabushi-native domains and must not regress while the coding-agent kernel evolves.

## Execution order from this audit

1. **MSR-103:** finish native auth/secrets cutover and migration compatibility.
2. **MSR-201/MSR-202:** close explicit suspension/reclaim, durable permission, and tool-policy integration gaps.
3. **MSR-301:** make rewind exact and managed worktrees Git-aware.
4. **MSR-302:** connect queue/oracle/attempt/loop/hooks/subagents to the production turn executor and persist them.
5. **MSR-401:** add MCP runtime status and finish one extension/model contract.
6. **MSR-501:** execute the same acceptance journeys on Electron/iOS/Android/Web/CLI as applicable.
7. **MSR-601:** prove the default product path no longer requires vendor product crates and that the Codex adapter can be disabled without changing Mahayana public contracts.
