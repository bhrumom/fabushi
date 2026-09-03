# 08 DeepSeek Harness 能力映射

Status: intake baseline; DHRF-101/102 must replace assumptions with package/test-backed evidence.

| Capability domain | Upstream documented behavior | Existing Mahayana landing point | Intake status |
|---|---|---|---|
| Composition | everything-as-plugin, scoped/reversible effects | `mahayana-harness`, plugin runtime | partial; parity audit required |
| Profiles/config | profiles, bundles, patch overlays, config dump | Harness profiles/config | partial; filesystem/overlay parity pending |
| Session | append-only events, transcript, fork/resume | Harness session log | core present; concrete stores/query/recovery audit required |
| Prompt/context | sections/tool schemas/model-visible invariant | Harness + agent/model path | partial |
| Agent loop | inbox, turn/step lifecycle, intercept/cancel/recovery | Harness agent + native agent/orchestrator | partial |
| Tools | scoped registry, pre/execute/post pipeline | Harness + ToolHost | core present; provider bridges/guards pending |
| Approval/policy | guarded execution | Harness/FeatureHost/kernel policy | partial; UI/security parity required |
| LLM | provider-neutral streaming seam | `mahayana-model` + Harness adapters | seam present; adapter parity pending |
| Persistence/query | stores, replay, session query/FTS | Harness storage seam/product storage | pending/partial |
| Shell/process/PTY | subprocess, shell, persistent terminal | ToolHost/workspace/native engines | bridge parity pending |
| Filesystem/LSP/code | capability providers/tools | ToolHost/workspace/JS runtime | bridge parity pending |
| Sandbox | provider-controlled confinement | kernel/platform policy | unified Harness seam pending |
| MCP/web | MCP, web search/fetch | MCP runtime/connectors | bridge parity pending |
| Attachments/spill | normalized content/addressing/offload | app attachments + Harness hash primitive | partial |
| Skills/plugins | installable/reversible extensions | plugin runtime/FeatureHost | bridge/loader parity pending |
| Compaction | explicit context compaction | model/runtime backends | explicit Harness service pending |
| Subagents/teams | continuable subagents, team roster/task/mailbox | Harness agents + FeatureHost groups | partial |
| Jobs/goals | background jobs and objective state | Harness records/orchestrator | core records present; executors pending |
| Workflow/hooks | long-running workflows/hooks | Harness advanced/orchestrator | partial |
| Todo/plan/presets | agent work state and presets | product task/plan + profiles | dedicated parity pending |
| Guards | repetition/deadline/tool safety guards | interceptors/policy | seam present; defaults pending |
| Runtime extension | model/runtime extension within policy | plugin runtime | policy/product flow pending |
| Settings/credentials | configured services and credential refs | product settings/auth | generic Harness seams pending |
| Workspace | workspace entity/capabilities | workspace engine | integration pending |
| SDK/JSON ABI | programmatic client/server surface | Mahayana Host protocol | Harness command/event ABI pending |
| ACP | editor/agent client protocol | existing transports | bridge parity pending |
| Schedule | scheduled work | Fabushi automations/orchestrator | Harness seam pending |
| Feedback | feedback/reporting path | product feedback | seam pending |
| Identity | runtime/user identity | Fabushi product identity | shared seam pending |
| Remote providers | optional remote/E2B-like providers | provider abstractions | optional; local-first default |
| UI/headless | Web UI and headless runner | Electron/native/Web/CLI | product wiring pending/partial |

A row becomes `passed` only when DHRF traceability names the Rust implementation and objective CI evidence.
