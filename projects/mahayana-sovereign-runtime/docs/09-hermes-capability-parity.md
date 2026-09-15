# 09 Hermes → Mahayana capability parity matrix

Updated: 2026-09-15

## Audit identity

- Hermes source: `NousResearch/hermes-agent`
- Pinned audit commit: `d128ce2e25634105c81dfcc9c7a1678d6c1db038`
- License: MIT (Nous Research, 2025)
- Fabushi starting main for this program: `944461ea020966dd76905c7e601d9e6c121ae4b3`
- Delivery project: `FAB-P0005 / MSR`

This matrix interprets “fully fuse Hermes into Mahayana” as **capability and behavior parity behind Mahayana-owned Rust contracts**, not shipping Hermes as a second Python runtime and not copying Nous-specific product identity. Fabushi-native messaging, identity, marketplace, wallet, billing, MiniApps and device-control contracts remain authoritative where Hermes has a vendor-specific analogue.

States:

- `native`: Mahayana already owns the underlying primitive; parity evidence may still be pending.
- `partial`: a Mahayana primitive exists but the Hermes behavior/wire surface is not fully bound or accepted.
- `MSR-204`: actively implemented in the current Hermes gateway/transcript PR.
- `gap`: no accepted Mahayana equivalent is currently evidenced.
- `adapt`: preserve the user capability while mapping it to Fabushi product semantics instead of cloning Nous-specific commerce/account behavior.

## Gateway, transcript and recovery

| Hermes capability | Pinned upstream contract/reference | Mahayana target | State | Acceptance still required |
|---|---|---|---|---|
| One dispatcher over stdio + WebSocket | `tui_gateway/transport.py`, `ws.py` | `mahayana-gateway` transport-neutral dispatcher; stdio + App Host/WS adapters | MSR-204 | production runtime handler + App Host/WS binding |
| Fine-grained assistant stream | `message.start/delta/interim/complete` | `mahayana-turn-protocol` | MSR-204 | runtime emits contract directly rather than renderer adapter |
| Reasoning stream | `reasoning.delta/available` | ordered reasoning parts | MSR-204 | native engine event binding + packaged visual proof |
| Tool lifecycle inside one assistant turn | tool generating/start/progress/complete | stable `toolId` part updated in place | MSR-204 | Messenger consumes ordered parts directly |
| Approval / clarify inside turn | approval RPCs + clarify locks/server requests | approval/clarify parts + Rust policy bus | partial/MSR-204 | server-request lifecycle, timeout, replay, answer E2E |
| Event replay | `session.events.since`, sequence + epoch | `seq` + `replayEpoch` and persistent turn store | MSR-204/partial | bounded replay buffer + durable Rust recovery implementation |
| Reconnect in-flight snapshot | `InflightTurn`, queued prompt, open requests, todo, approval | Rust canonical session/turn snapshot | partial | renderer-local journals no longer authoritative |
| Renderer projection | Desktop message-stream reducer | `AssistantTurn + ordered parts` | MSR-204 | native Messenger wiring; remove compatibility CSS/Workbench side effects |

## Session lifecycle and prompt control

| Hermes capability | Pinned upstream contract | Mahayana target | State | Follow-up |
|---|---|---|---|---|
| create / resume / activate / close | `session.create/resume/activate/close` | Mahayana conversation/session runtime | partial | MSR-205 |
| stored/live session listing | `session.list/most_recent/active_list` | conversation list + live runtime index | partial | MSR-205 |
| delete/title/hidden/workspace/cwd | session mutation RPCs | conversation metadata + workspace engine | partial | MSR-205 |
| history / status / usage / context breakdown | session introspection RPCs | conversation store + model usage/telemetry | partial | MSR-205 |
| branch / undo | `session.branch`, `session.undo` | workspace + conversation branch/rewind | partial | MSR-205/MSR-301 |
| compression | `session.compress` | durable context compaction | gap/partial memory primitives | MSR-205/MSR-302 |
| interrupt | `session.interrupt` | runtime interrupt | native/partial | MSR-205 production parity |
| steer / redirect / queued prompts | `session.steer`, `session.redirect`, busy prompt statuses | `PromptQueue` + runtime correction path | native/partial | MSR-205/MSR-302 |
| prompt truncation/edit/regenerate | `prompt.submit` truncate coordinates | conversation row identity + exact rewind | gap/partial | MSR-205/MSR-301 |
| stateless one-shot | `llm.oneshot` | model/runtime one-shot request | partial | MSR-205 |
| spawn-tree save/list/load | `spawn_tree.*` | `SubagentScheduler` + durable delegation graph | partial | MSR-206 |

## Attachments, tools and local execution

| Hermes capability | Pinned upstream contract | Mahayana target | State | Follow-up |
|---|---|---|---|---|
| clipboard/image bytes/image path | `clipboard.paste`, `image.attach*` | Fabushi attachment pipeline + workspace staging | partial | MSR-206 |
| PDF page attachment | `pdf.attach` | Fabushi/PDF attachment preprocessing | partial/unverified | MSR-206 |
| arbitrary file staging | `file.attach`, input drop | Fabushi attachments + workspace refs | partial | MSR-206 |
| background/BtW side agents | `prompt.background`, `prompt.btw` | Mahayana subagents/orchestrator | native/partial | MSR-206 |
| preview restart side agent | `preview.restart` | app/browser preview tool | gap/partial | MSR-206 |
| tool/toolset inventory | `tools.list/show/configure`, `toolsets.list` | `mahayana-tool-host` | native/partial | MSR-206 |
| safe shell / CLI exec | `shell.exec`, `cli.exec` | computer/tool policy plane | native/partial | MSR-206 security conformance |
| process list/kill/stop/agents | `process.*`, `agents.list` | process registry/computer control | partial | MSR-206 |
| slash command catalog/resolve/dispatch | `commands.*`, `slash.exec` | CLI/plugin/skill command surface | partial | MSR-206 |
| checkpoint list/diff/restore | `rollback.*` | `WorkspaceEngine` checkpoints/rewind | native/partial | MSR-301 |
| cron management | `cron.manage` | Mahayana Routine/Automation | native/partial | MSR-206 cross-surface parity |
| browser CDP attach/status | `browser.manage` | Fabushi computer/browser control | partial | MSR-206 |
| host battery/status helpers | `system.battery` | platform host telemetry | gap/non-core | MSR-206 if product UX requires |

## MCP, skills, plugins, memory and connectors

| Hermes capability | Pinned upstream contract/module | Mahayana target | State | Follow-up |
|---|---|---|---|---|
| toolset enable/disable and reload | `tools_mcp_plugins.py` | tool host + runtime rebuild | partial | MSR-207 |
| MCP catalog/list/status/add/update/remove/auth/reload | `mcp.*`, `reload.mcp` | `mahayana-mcp-runtime` + connector accounts | native/partial | MSR-207 |
| Skills list/search/browse/inspect/install/reload | `skills.manage`, `skills.reload` | Fabushi Skills + marketplace | native/partial | MSR-207 |
| Plugins lifecycle | `plugins.manage` family | Fabushi plugin host/runtime/marketplace | native/partial | MSR-207 |
| learning graph / journey | `learning.*` | Mahayana memory + skill provenance UI | gap/partial memory primitives | MSR-207 |
| environment reload | `reload.env` | trusted runtime configuration reload | gap/partial | MSR-207 |
| connector operation lifecycle | `connectors_operation.py` | Fabushi connector host + approvals | native/partial | MSR-207 |
| profiles/vault/free-tier/control | corresponding contract modules | Fabushi account/profile/secrets/control plane | adapt/partial | MSR-207; do not expose vendor secrets |

## Delegation, group/bot and product collaboration

| Hermes capability | Pinned upstream module | Mahayana/Fabushi target | State | Follow-up |
|---|---|---|---|---|
| delegation controls + handoff | `billing_delegation_pets.py` | `SubagentScheduler`, bot/agent handoff | partial | MSR-208 |
| message reactions | delegation/reaction contracts | Fabushi messaging reactions | partial/unverified | MSR-208 |
| foreign subagents | `profiles_vault_complete_foreign_subagents.py` | cross-agent/session adoption with policy | partial | MSR-208 |
| groups + bot relay | `groups_bot_relay.py` | Fabushi channels/bots/messaging | native/partial | MSR-208 |
| project facts/project surfaces | delegation/projects modules | Fabushi Work/projects + memory | partial | MSR-208 |
| hosted room/session routing | gateway room RPC/server | Fabushi conversation routing | partial | MSR-208 |
| Hermes pets/avatar generation | pets contracts | Fabushi Bot identity/animated avatar engine | adapt/partial | MSR-208 visual/product mapping |

## Voice and wake

| Hermes capability | Pinned upstream contract | Mahayana target | State | Follow-up |
|---|---|---|---|---|
| voice mode + TTS | `voice.toggle`, `voice.tts` | native voice/TTS service behind Mahayana contract | gap/unverified | MSR-209 |
| push-to-talk + transcript | `voice.record`, `voice.transcript` events | native capture/STT + turn input | gap/unverified | MSR-209 |
| wake start/stop/pause/resume/status | `wake.*` | device-local wake service | gap/unverified | MSR-209 |
| remote PCM feed | `wake.feed` | authenticated device/audio transport | gap | MSR-209 |

## Commerce/account features

Hermes exposes Nous billing/subscription/usage/free-tier contracts. Fabushi must **not** clone Nous product identity or portal semantics. The equivalent user outcomes map to Fabushi-owned account, usage, wallet, purchase, entitlement and marketplace contracts.

| User capability | Fabushi target | State | Acceptance |
|---|---|---|---|
| usage visibility | model usage/wallet state | native/partial | consistent CLI/Desktop/mobile presentation |
| subscription/purchase state | Fabushi purchase/entitlement service | native/partial | product-specific E2E |
| top-up/billing controls | Fabushi wallet/payment contracts | native/partial | no Nous endpoint/runtime dependency |
| auth/profile/secrets | `mahayana-auth`, `mahayana-secrets`, product profile | native/partial | MSR-103/MSR-207 gates |

## Required execution sequence

1. **MSR-204 — Gateway + transcript:** complete production event binding and native Messenger rendering; remove default Workbench/Portal semantics.
2. **MSR-205 — Session lifecycle/replay:** create/resume/activate/list/history/branch/undo/compress/interrupt/steer/truncate and Rust canonical recovery.
3. **MSR-206 — Tools/attachments/process/browser/subagents:** normalize every runtime tool lifecycle onto the same turn protocol.
4. **MSR-207 — MCP/skills/plugins/connectors/memory/config:** close extension-control parity without vendor product dependencies.
5. **MSR-208 — Delegation/groups/bots/projects/collaboration:** map Hermes collaboration abilities onto Fabushi actor/conversation semantics.
6. **MSR-209 — Voice/wake:** implement device-local voice/wake contracts where supported.
7. **MSR-501 — Cross-surface acceptance:** Electron, iOS, Android, Web, CLI consume the same Mahayana event/session semantics.
8. **MSR-601 — Isolation/release:** prove disabling/removing vendor adapters does not change Mahayana public contracts or default product behavior.

No row is considered passed from source presence alone. Every parity claim requires exact-head tests, protected merge, canonical-main readback, and the appropriate packaged/real-device acceptance evidence.