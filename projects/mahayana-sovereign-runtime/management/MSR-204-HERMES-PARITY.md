# MSR-204 — Hermes → Mahayana capability parity matrix

Pinned upstream: `NousResearch/hermes-agent@5eb99eb2844b22ebb723711b8e6a0bbb80bb5f04`.

This matrix is intentionally conservative. `present` means a Mahayana-owned implementation already exists and still needs exact-behavior verification; `partial` means useful first-party capability exists but does not yet prove Hermes-equivalent semantics; `missing` means no equivalent was established by this audit; `audit` means repository evidence is not yet sufficient to make a claim.

The goal is **not** to embed the Hermes Python runtime. The target is to preserve Hermes' useful behavior and UX semantics behind Mahayana-owned Rust contracts and existing Fabushi surfaces.

| Hermes capability | Upstream evidence / behavior | Mahayana / Fabushi target | Current state | Required acceptance evidence |
|---|---|---|---|---|
| Unified TUI/Desktop gateway | `tui_gateway`: one JSON-RPC dispatcher over stdio and WebSocket | `mahayana-gateway-protocol` + host/runtime transports | **partial** | Same ordered event trace over CLI stdio and Desktop/native transport; reconnect/replay test |
| Ordered assistant streaming | `message.start`, `message.delta`, `message.interim`, `message.complete` | `AssistantTurn` + Rust conversation store | **partial** | Real run renders text before/after tools in one turn without duplicate flat rows |
| Reasoning / thinking stream | `reasoning.delta`, `thinking.delta` | Gateway reasoning part | **partial** | Reasoning streams separately from final text and seals before terminal events |
| Tool lifecycle | `tool.generating`, `tool.start`, `tool.complete` | `mahayana-tool-host`, gateway tool part | **partial** | One tool part updates running → complete/failed; no second status card |
| Approval flow | approval request/response, command security | existing approval events / host policy + gateway approval part | **present / migration needed** | allow-once, allow-session, deny all work after Workbench visual split |
| Clarification flow | `clarify.request` and response | gateway clarify part + host request | **partial** | Agent pauses, asks in transcript, resumes same turn after answer |
| Interrupt / redirect | Ctrl+C, `/stop`, send-new-message redirect | host interrupt + operation lifecycle | **present / parity unproven** | Interrupt active run and continue conversation without corrupting transcript |
| Session create/list/history/resume | CLI sessions and cross-session continuation | `mahayana-conversation` | **partial** | Rust canonical session history survives renderer/app restart and resumes exact turn |
| Replay / reconnect | replay epoch + buffered transport fanout | gateway `replayEpoch` + sequence cursor | **partial** | Drop/reconnect test rejects gaps/stale events and replays without duplicates |
| CLI/TUI multiline editing | Hermes terminal UI | `mahayana-cli` / existing TUI compatibility | **audit** | Interactive terminal acceptance on macOS/Linux/Windows |
| Slash command completion | `/new`, `/model`, `/retry`, `/undo`, `/compress`, `/usage`, skills, etc. | Mahayana CLI command router | **audit** | Method/command catalog comparison and interactive tests |
| Retry / undo | `/retry`, `/undo` | conversation/runtime | **audit** | Deterministic rollback and regenerated turn with persisted history |
| Context compression | `/compress` | model/conversation layer | **audit** | Token-budget compression preserves required context and audit trail |
| Usage / insights | `/usage`, `/insights` | existing `usage.updated` projection | **partial** | Rust totals match provider usage and persist across surfaces |
| Multi-provider model switching | Nous Portal, OpenRouter, OpenAI, custom endpoints | `mahayana-model` | **present / parity unproven** | Runtime switch without app restart; provider/model reflected in same turn |
| Tool enable/disable / toolsets | `hermes tools`, 40+ tools | `mahayana-tool-host`, plugin/MCP runtimes | **partial** | Capability catalog + enable/deny policy tests |
| MCP | Hermes MCP integration | `mahayana-mcp-runtime` | **present / parity unproven** | stdio/SSE/http MCP interoperability and lifecycle tests |
| Browser / cloud browser | Tool Gateway / Browser Use | Fabushi browser/computer control | **partial** | Real browse/navigation/tool trace from Mahayana run, no renderer-owned execution |
| Terminal execution | local backend + remote backends | `mahayana-computer` / tool host | **partial** | shell/process streaming, exit code, cancellation, cwd/environment isolation |
| Docker terminal backend | Hermes terminal backend | Mahayana computer/runtime | **audit** | Backend selection + sandbox integration test |
| SSH terminal backend | Hermes terminal backend | Mahayana computer/runtime | **audit** | Auth-safe SSH execution + cancellation test |
| Singularity backend | Hermes terminal backend | Mahayana computer/runtime | **missing / unverified** | Backend implementation and integration test if product-required |
| Modal backend | Hermes serverless backend | Mahayana computer/runtime | **missing / unverified** | Explicit product decision or compatible Rust adapter + E2E |
| Daytona backend | Hermes serverless persistent backend | Mahayana computer/runtime | **missing / unverified** | Explicit product decision or compatible Rust adapter + hibernate/resume test |
| Vercel Sandbox backend | Hermes backend | Mahayana computer/runtime | **missing / unverified** | Explicit product decision or compatible Rust adapter + E2E |
| Subagents / delegation | isolated subagents + progress events | `mahayana-native-agent`, `mahayana-orchestrator` | **partial** | Parallel subagents, independent tools/context, ordered progress/completion events |
| Programmatic tool RPC from scripts | Python scripts call tools via RPC | Mahayana tool/gateway RPC | **missing / unverified** | Rust-owned RPC capability with policy enforcement and zero hidden renderer state |
| Background / async work | background agent + progress | existing background/async events | **partial** | Start/progress/finish/recovery across restart |
| Skills system | agentskills.io-compatible skills; create/use/improve | Mahayana plugin/skill surfaces | **audit** | Skill format/import/run/version lifecycle matrix |
| Autonomous skill creation | learning loop creates skills after complex tasks | no proven equivalent | **missing / unverified** | Explicit safe creation policy + generated skill validation + rollback |
| Skill self-improvement | updates skills during use | no proven equivalent | **missing / unverified** | Versioned self-edit review/approval and regression tests |
| Persistent memory | agent-curated memory | conversation/workspace stores | **partial** | Rust-owned memory CRUD, isolation, restart persistence, export/delete policy |
| Cross-session search | FTS5 session search + LLM summarization | conversation search | **audit** | Indexed search recall + provenance and account isolation |
| User modeling | Honcho dialectic user model | no established equivalent | **missing / unverified** | Product decision; if implemented, privacy/consent + deterministic storage tests |
| Personality switching | `/personality` | agent identity/profile | **audit** | Persona changes survive session boundaries without changing Bot identity incorrectly |
| Cron / scheduled automation | natural-language schedules delivered to platforms | Fabushi task/background infrastructure | **audit** | Persistent scheduler, restart recovery, delivery and cancellation tests |
| Telegram | single gateway platform | existing Telegram provider | **present / separate project evidence** | TFI canonical-main E2E reused only when exact protocol contract matches |
| Discord | messaging gateway | social/provider layer | **audit** | Real account sandbox integration if product scope includes Discord |
| Slack | messaging gateway | social/provider layer | **audit** | Real sandbox integration if product scope includes Slack |
| WhatsApp | messaging gateway | social/provider layer | **audit** | Real sandbox integration if product scope includes WhatsApp |
| Signal | messaging gateway | social/provider layer | **audit** | Real sandbox integration if product scope includes Signal |
| Email gateway | messaging gateway | connector/mail surfaces | **audit** | Inbound/outbound thread continuity test |
| Voice memo transcription | gateway voice transcription | bundled offline ASR / desktop audio | **partial** | Real voice attachment → transcript → agent reply across supported surfaces |
| Text-to-speech | Tool Gateway TTS | audio/tool layer | **audit** | TTS provider + playback/cancel test if in product scope |
| Image generation | Tool Gateway image generation | plugin/tool ecosystem | **audit** | Tool contract + artifact rendering test |
| Web search | Tool Gateway web search | plugin/tool ecosystem | **audit** | Search tool call/result provenance in ordered turn |
| File/artifact rendering | transcript tool/artifact parts | MiniApp/cards/files + ordered turn | **partial** | File/tool artifact appears inside same assistant turn with open/download behavior |
| Context/project files | files shaping each conversation | Mahayana workspace engine | **partial** | Workspace context selection, precedence and restart persistence |
| Security allowlist | command approvals and policy | host policy / approvals | **present / parity unproven** | allow/deny/session scopes, audit log, destructive-command test |
| DM pairing / platform access control | gateway security | messaging provider policy | **audit** | unauthorized sender rejected; pairing/revoke trace |
| Container isolation | security boundary | computer/tool host sandbox | **audit** | filesystem/network/process escape regression suite |
| Secrets handling | provider/tool credentials | `mahayana-secrets`, credential vault | **present / parity unproven** | no secret in transcript/log/replay; account isolation; rotate/revoke |
| Setup/config wizard | `hermes setup`, config get/set | Fabushi settings + CLI config | **partial** | installed app works without external bootstrap; CLI config round-trip tests |
| Doctor/diagnostics | `hermes doctor` | diagnostics/status surfaces | **audit** | deterministic self-test with actionable failures |
| Self-update | `hermes update` | Fabushi desktop/mobile release updater | **present on app surfaces** | version monotonicity, same-version suppression, restart verification |
| OpenClaw migration | settings/memory/skills/secrets migration | no established Mahayana equivalent | **missing / optional** | Product decision; dry-run + scoped import + secret allowlist if adopted |
| Change watcher / live reload | gateway change watcher | plugin/runtime reload | **audit** | changed skill/config reloads without corrupting active run |
| Hosted/remote compute host | compute host + bridge | Fabushi computer/device control | **partial** | App-owned device registration, policy, reconnect, remote action evidence |
| Billing/account view | gateway billing view | Fabushi commerce/account surfaces | **audit** | Only implement if product requirement; keep billing out of core agent protocol |
| Batch trajectory generation | research pipeline | no proven equivalent | **missing / unverified** | Deterministic export format, privacy scrub, reproducibility |
| Trajectory compression | training/research pipeline | no proven equivalent | **missing / unverified** | Compression fidelity tests if adopted |
| Desktop natural transcript | Desktop message parts | ordered `AssistantTurn` renderer | **partial** | Packaged Desktop screenshot/video proves no routine Workbench completion card |
| Cross-surface transcript parity | TUI/Desktop/gateway clients share semantics | Desktop/iOS/Android/Web/extension consume Mahayana events | **missing as full parity** | Same recorded gateway trace replays to all surfaces with semantic-equivalent output |
| Self-contained installation | Hermes currently bootstraps Python/Node/Git/ffmpeg | Fabushi bundles Mahayana/native dependencies | **target requirement** | Fresh macOS/Windows install performs first real agent run offline from build-time dependencies, with no post-install runtime download |

## Immediate execution order

1. **MSR-204A — Gateway + transcript cutover:** connect the product Rust producer, fold legacy/new events into one `AssistantTurn`, replace Messenger flat lifecycle rows, keep approval/recovery Inspector only.
2. **MSR-204B — Session/replay authority:** move turn/part/replay truth into `mahayana-conversation`; prove disconnect/restart recovery.
3. **MSR-204C — CLI/TUI parity:** same dispatcher semantics over stdio plus CLI session/history/interrupt/commands.
4. **MSR-204D — Tool/approval/MCP/subagent parity:** normalize lifecycle/approval/clarify and eliminate renderer-owned execution state.
5. **MSR-204E — Hermes capability closure:** convert every `audit`/`missing` row above into an explicit implement/decline decision and atomic task with tests.
6. **MSR-204F — Cross-surface + self-contained release:** Desktop/iOS/Android/Web/extension replay parity, packaged first-run proof, no post-install runtime bootstrap.

## Completion rule

`Hermes fused into Mahayana` may only be claimed after every in-scope row is `present` with objective evidence or has an explicit product decision to exclude it. A visually similar Desktop transcript alone is not completion.
