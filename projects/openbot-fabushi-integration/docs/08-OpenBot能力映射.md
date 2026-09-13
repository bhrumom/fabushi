# OpenBot feature -> Fabushi implementation -> evidence -> gap matrix

Pinned upstream: `CopilotKit/OpenBot@19fdcbb7fd5c072d5c2aa95800fcbbbf72aa202c` (MIT). Fabushi round baseline: canonical `main@25aaf4fef98fb33ca0100c8cdbd6c7971390ec94`. Reference screenshot: user task `Fabushi:173d215e-3b26-4bbd-9609-4110d72f4133`, original `2048x1280`, SHA-256 `555f8ae43517b2f6b2a1e545a16c0eb95e596585a1c9adfd211cad6a217c475b`.

Classification:

- `EQUIVALENT`: an existing Fabushi capability is the canonical implementation; OBF must reuse it.
- `GAP-CLOSED`: a verified missing surface/contract was implemented in OBF-001; CI / packaged acceptance can still be pending.
- `NOT-FUSED`: upstream deployment semantics conflict with Fabushi architecture or duplicate an existing source of truth; the reason is explicit.
- `EVIDENCE-PENDING`: implementation exists, but the exact packaged reference run is not yet proven.

| OpenBot feature | Fabushi corresponding implementation | Evidence/source | Disposition / remaining gap |
|---|---|---|---|
| Matte dark workspace | Messenger + authoritative OpenBot parity layer | `desktop/src/openbot-ui-parity.css`, merged PR #2580 | `EQUIVALENT`; fixed-reference packaged pixel evidence pending |
| Coworker roster/search | Messenger peer list + search | `desktop/src/messaging-shell-v2.tsx` | `EQUIVALENT`; Chief/Research/Builder/Launch packaged scene pending |
| Geometric coworker avatar | canonical deterministic `BotMark` | `frontend/apps/web/src/app/host/bot-mark.tsx` | `GAP-CLOSED`: removed roster-position `nth-child` clipping that could change silhouette when order changed; roster/header/transcript now use canonical Bot identity; restart proof pending |
| One channel per coworker | Messenger bot/conversation projection | `desktop/src/messaging-shell-v2.tsx`; Mahayana transport | `EQUIVALENT`; no second OpenBot channel store added |
| Reply thinking | `operation.started` -> thinking projection | `messaging-shell-v2.tsx` | `GAP-CLOSED`: parity CSS now targets live `agentThinkingRow`, not stale selector aliases |
| Reply action/tool | `model.routed` / `agent.step` -> action projection | `messaging-shell-v2.tsx`, `mahayana-agent-workbench.tsx` | `GAP-CLOSED`: parity CSS now targets live `agentActionRow`; running/completed/failed packaged evidence pending |
| Final assistant completion | `chat.delta` / `chat.message` + operation terminal event | `messaging-shell-v2.tsx` | `EQUIVALENT`; exact real-provider completion proof pending |
| Component / structured result | runtime-authored Markdown heading/table renderer | `StructuredMessageBody`, `parseStructuredMessage` in `messaging-shell-v2.tsx` | `GAP-CLOSED`: generic result projection added; no hard-coded Final launch brief transcript |
| Final launch brief 3-column table | generic structured result table | `assistant-result-table` in `messaging-shell-v2.tsx` | `GAP-CLOSED`; packaged real Mahayana output still required |
| Source files / attachments | existing Messenger document media + new generic source chips | `messageFile`, `assistant-source-files` | `GAP-CLOSED`: source-file chip projection added while retaining real file attachment path |
| Hover reply/copy/more | existing reply/context operations exposed as hover toolbar | `message-hover-actions`, existing `MessageContextMenu` | `GAP-CLOSED`; visual parity pending |
| Composer | Messenger attachment/text/emoji/silent/send composer | `messaging-shell-v2.tsx` | `EQUIVALENT`; geometry diff pending |
| Coworker computer | Fabushi registered App-owned/user computer runtime | `remote-computer/desktop-peer`, universal computer control, RDF project | `NOT-FUSED` for mandatory container-per-coworker semantics: Fabushi's product boundary is the user's registered/App-owned computer, not an OpenBot-owned mandatory container; duplicating a supervisor would create a second computer source of truth |
| Coworker browser | existing browser/computer automation on the assigned Fabushi computer | computer-control/browser integrations | `EQUIVALENT` capability; `NOT-FUSED` for mandatory per-coworker isolated browser profile until Fabushi product requirements explicitly require that isolation model |
| Coworker files | Mahayana workspace/file tools + Messenger document surfaces | ToolHost/workspace + `MessagingMediaRef` | `EQUIVALENT` file capability; `NOT-FUSED` for OpenBot's mandatory independent `/workspace` per coworker because Fabushi does not use that container tenancy model |
| Coworker tools / MCP | Mahayana ToolHost/MCP/plugins/Mini Apps | MSR Tool Bus / plugin contracts | `EQUIVALENT`; do not import a second OpenBot MCP gateway/catalogue |
| Shell through same policy gate | Mahayana/local execution path | ToolHost/local execution settings | `EQUIVALENT`; existing policy boundary remains authoritative |
| Live screen | App-owned snapshot/live remote channel + RustDesk/semantic device control | `computer.screenshot`, remote computer channel, `fabushi.app.snapshot`, FAB-P0009 | `EQUIVALENT` underlying capability; same-channel OpenBot-style panel visual placement is `EVIDENCE-PENDING`, not a second screen stack |
| Human take-over | existing remote-control/session control | remote computer control settings + RDF/GBF paths | `EQUIVALENT` underlying control; exact OpenBot `help_requested/control_taken/control_released` UI vocabulary is `NOT-FUSED` because Fabushi has its own session protocol; packaged audit/lockout behavior remains evidence-pending |
| Policy before action | Mahayana policy/approval + localToolPermission | `approval.requested/resolved`, `localToolPermission`, MiniApp/WebMCP gates | `EQUIVALENT`; packaged allow/deny evidence pending |
| Audit after action | existing Host audit list + run/evidence journals | `frontend/apps/web/src/app/host/host-client.tsx` `audit.list`, MSR event/workbench records | `EQUIVALENT` capability; OpenBot's `/admin/audit` route itself is `NOT-FUSED` because Fabushi has a different Host/admin surface |
| Secrets not exposed in transcript | existing Fabushi sensitive-input/credential boundaries | credential gateway + sensitive input policy | `EQUIVALENT`; do not copy OpenBot secret store |
| Durable threads / restart | Mahayana persistence + Messenger projection | Host/client persistence | `EQUIVALENT`; avatar/transcript restart packaged assertion added, live acceptance pending |
| Memory | Fabushi/Mahayana existing conversation/workspace memory semantics | host/runtime persistence | `EQUIVALENT` at product capability level; no OpenBot memory store imported |
| Components instead of prose | Mini Apps/WebMCP + generic ordinary-message structured result | Mini App runtime + `StructuredMessageBody` | `GAP-CLOSED` for the reference ordinary reply table; Mini Apps remain the richer canonical component system |
| Skills | existing Skills/plugin/Mini App ecosystem | marketplace/plugin/tool contracts | `EQUIVALENT`; tenant-specific OpenBot skills are data, not fusion target |
| Routines/scheduled work | existing Fabushi automation/workflow runtime | MSR/automation surfaces | `EQUIVALENT`; outside the screenshot journey |
| Admin computers/boundaries/components/audit pages | Fabushi settings/Host/admin surfaces | remote computer/settings/host client | `NOT-FUSED` at route/UI identity level; functionality maps to Fabushi-native control planes rather than duplicating `/admin/*` |

OBF-001 therefore changes only presentation/projection and acceptance contracts. It does **not** add an OpenBot executor, container supervisor, gateway, store, transcript database, MCP gateway, audit database, or remote-control protocol.
