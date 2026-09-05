# FAB-ARCH-20260905-01 — Bot / MiniApp / Mahayana 下一阶段目标架构

Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`

## 1. 项目复用映射

| 目标 | 主项目 | 复用/依赖 |
|---|---|---|
| 桌面首屏消息约一分钟 | FAB-P0001 / TFI | 复用 M3-DESKTOP-002 local-first；GBF-604 只作为后续全局性能门禁消费者 |
| Bot 生成 MiniApp -> 实体卡片 | FAB-P0001 / TFI | 复用 M8 Marketplace、BotFather、Messenger；MSR 只消费能力 |
| MiniApp install -> Bot 1:1 | FAB-P0001 / TFI | 复用 M8-MARKET-002 Bot projection 和 account sync |
| 每 Bot = Mahayana CLI session | FAB-P0005 / MSR | 复用 MSR-201/202/302/401；GBF 作为产品消费者 |
| Bot 控设备/MiniApp | FAB-P0004 / GBF + FAB-P0005 / MSR | 复用 GBF-409/410/411；MSR 提供 session/tool policy context |
| 多 Bot 群聊多步多结果 | TFI 协议 + MSR runtime + GBF UX | 不建立第二 conversation/runtime stack |

禁止新建重复项目。

## 2. Current-main facts vs older records

Canonical `main` for this round is `586a0952f17ab4b36dab9a69402b837968f5aa3f`.

- `native/mahayana-messaging` already models human/assistant/bot/service actors, direct/group/channel conversations, BotProfile/BotInvocation/BotExecution and MiniAppManifest/MiniAppGrant/MiniAppSession. However BotExecution has no durable Mahayana session or session generation, and MiniAppManifest/Session do not form a durable install/version/audit lifecycle.
- `ai-backend/src/miniapp_marketplace_mcp.js` already exposes search/add/remove/open and `generate_and_submit_miniapp`, but generation returns workflow/draft data; a durable generated MiniApp entity/card reference is not the protocol result.
- M8-MARKET-002 implemented installed-MiniApp Bot projection, but its task record still says PR #2158 remains to merge; #2158 is already merged. Treat the code as present, and the old administrative status as stale until post-main evidence is reconciled.
- GBF-409 task text still describes #2201 as pending, while #2201 is merged. The same applies to GBF-410/411 work carried by #2205. Existing account/device/client/session/generation security therefore is a current-main base, while any unproven live/release gate remains unresolved.
- MSR status text for MSR-403 is stale: current main itself is the merge of #2347. Do not use that stale record to infer other planned runtime capabilities are complete.
- The MSR capability matrix remains valuable but its upstream pins are stale relative to this round: review starts at Grok Build `72a61251fcffb464bcc687aeb5a998e5a98ec0c9` and Codex `ddf04ad26789d040f9ef6a96736f76602e35a6cc`.

## 3. Target canonical model

### Identity and runtime binding

- `ActorId`: canonical messaging identity. Bots remain actors; MiniApps are entities/installs, not actors by default.
- `MahayanaSessionId`: durable runtime identity owned by one Bot.
- `BotRuntimeBinding { account_id, bot_actor_id, mahayana_session_id, session_generation, state, checkpoint_ref, updated_at }`.
- Unique invariant: one active Mahayana session identity per Bot actor per account. Restart/reclaim preserves session id when recoverable and monotonically increments `session_generation` on new ownership epoch.

### MiniApp lifecycle

- `MiniAppDefinition { mini_app_id, publisher, discoverability, current_release }`.
- `MiniAppVersion { mini_app_id, version, manifest_digest, manifest, package/source refs, preview refs, created_at }` is immutable.
- `MiniAppInstall { install_id, account_id, mini_app_id, version, manifest_digest, bot_actor_id, bot_conversation_id, permission_revision, install_state, runtime_state, installed_at, updated_at }`.
- Current install is unique by `(account_id, mini_app_id)`; current install also has exactly one default Bot actor and one direct conversation. Reinstall/restore reuses or explicitly migrates that relationship; it never silently creates duplicate peers.
- `MiniAppCardProjection` is derived UI state only: entity identity + version + preview + install state + runtime state + actions. It is never source of truth.

### MiniApp events

`DraftCreated -> BuildProduced -> ReviewSubmitted -> Published` for generation; `InstallRequested -> PackageVerified -> Installed -> BotBound -> Ready` for installation. Updates use `UpdateRequested -> Updated -> Ready`; removal uses `UninstallRequested -> Uninstalled`; recovery uses `RestoreRequested -> Restored`. Every transition carries `event_id`, account, miniApp/install/version/digest, actor, causation/correlation id and timestamp. Failed transitions are terminal events with retryability metadata; no UI-only optimistic state may become canonical.

## 4. Mahayana session and tool boundary

Every Bot turn resolves `bot_actor_id -> BotRuntimeBinding -> mahayana_session_id + session_generation`. Every tool call receives a `ToolExecutionContext` containing at least account, actor/Bot, session id, session generation, conversation id, invocation/run id, correlation id, capability grant id and optional target resource identity. Session generation is a fencing token: stale generations cannot mutate devices, MiniApps, workspace or external connectors.

Mahayana owns planning, model/provider routing, tool/policy/approval, workflow/subagent, memory/checkpoint and artifact lifecycle. TFI owns messaging canonical data. GBF owns computer/App MCP transport and product control surfaces. Skills remain orchestration helpers above this runtime boundary.

## 5. Target-bound device command

Extend, do not replace, GBF-409/411 security. A mutating Bot device call must bind:

`account_id + bot_actor_id + mahayana_session_id + mahayana_session_generation + conversation_id + invocation_id + target_device_id + target_device_generation + device_control_session_id + capability_grant_id + nonce/idempotency_key + expiry`.

The receiver rejects wrong account/device, stale Bot generation, stale device generation, revoked grant/client/session, expired/replayed nonce, remote-control disabled state and policy denial. Audit result records requested and observed generations plus the selected tool/action. No wildcard “any device” write path is allowed.

MiniApp tool calls use the same context with `mini_app_install_id + manifest_digest + permission_revision` as the target fence.

## 6. Group-turn protocol

TFI provides durable conversation ordering. A canonical `GroupTurn` has `group_turn_id`, conversation, initiator, participant allowlist/routing policy, parent message, deadline/budget and correlation id. Each selected Bot receives a `BotInvocationRequested` bound to its Mahayana session generation.

Runtime emits ordered child events: `InvocationStarted`, `StepStarted`, `ToolRequested`, `ToolResult`, `PartialResult`, `StepCompleted`, `FinalResult`, `InvocationFailed/Cancelled`. Each event carries source actor, invocation/run, step/result id and group-turn correlation. Multiple result lanes coexist; one Bot cannot overwrite another Bot's result. The group turn finishes only when all selected participants are terminal or routing policy explicitly stops them.

Loop/safety controls: explicit participant allowlist, bot-to-bot policy, max steps/tool calls/time/tokens, cycle detection, cancellation propagation, approval gates and stale-session fencing. Device actions remain target-bound even inside a group turn.

## 7. Desktop first-frame performance diagnostic contract

Do not guess a root cause. Instrument a single monotonic startup timeline:

- P0 process/renderer navigation
- P1 local projection read start/end + bytes/counts/cache-hit
- P2 Messenger shell first paint/first interactive
- P3 auth restore start/resolved
- P4 native Host spawn/ready
- P5 first messaging snapshot request/first batch
- P6 visible conversation metadata complete
- P7 selected conversation message hydrate start/first visible/initial batch complete
- P8 event subscription requested/live + backlog count
- P9 account/background reconcile start/end

Record IPC/network duration, payload counts/bytes and renderer long tasks. Existing local-first intent remains: cached returning-user UI must paint before Host/auth roundtrips, initial lightweight conversation metadata must not be truncated by heavy-message limits, and background reconcile must not gate first interaction.

Initial acceptance target keeps the existing `<1000 ms` cached first-interactive contract and adds: first visible message batch `<1000 ms` on the seeded packaged returning-user case; initial bounded hydration `<2000 ms`; no background account sync may gate P2/P7. If trace places the bottleneck outside the frozen fix-task allowlist, execution fails closed and returns to architecture rather than editing extra files.

## 8. Open-source review gate

Before runtime implementation, MSR-107 must inspect exact current pins and source paths:

- `xai-org/grok-build@72a61251fcffb464bcc687aeb5a998e5a98ec0c9`, Apache-2.0: session/workflow/subagent/worktree/checkpoint/managed MCP and policy concepts are candidates for capability-level adaptation.
- `openai/codex@ddf04ad26789d040f9ef6a96736f76602e35a6cc`, Apache-2.0: thread/session lifecycle, approvals/sandbox, MCP/app-server/provider and observability are candidates.
- `bhrum/grok-bot-0.18-reconstructed@107877b4e2134fd167d239411386f09e42eadd6d`: behavior/protocol evidence only. Its provenance explicitly says no upstream source-code license is implied; do not copy reconstructed implementation into Fabushi.

For every capability record `upstream_path -> observed behavior -> Fabushi target -> reuse/adapt/reject -> license/provenance -> tests`. No upstream runtime becomes a second product core.

## 9. DAG / parallel waves

Wave 0 (parallel, no code-file overlap): `M3-DESKTOP-003`, `M8-ENTITY-001`, `MSR-107`.

Wave 1: `M3-DESKTOP-004` after startup trace; `M8-BIND-001` after entity model; `MSR-204` after upstream audit. These three own disjoint desktop / messaging+marketplace / Mahayana runtime files.

Wave 2: `M8-CARD-001` after startup fix and MiniApp binding; `M5-BOTGROUP-001` after MiniApp binding; `MSR-205` after MiniApp binding + MSR-204; `GBF-412` after MSR-204 and existing device-surface readback. File ownership remains disjoint within the wave.

Wave 3: `MSR-206` after TFI group protocol + MSR session/capability context; `GBF-413` after MSR-206 + GBF-412. They are sequential because GBF-413 is only a UI/projection parity consumer.

Any task that requires a file outside its allowlist stops and returns to this architecture revision for repartitioning.

## 10. Status semantics

All new runtime tasks start `PLANNED`. A task may not advance merely because a Skill/doc exists or because a similar old task was merged. `TESTED/COMPLETE` requires exact PR head review, required CI, protected-main merge, exact-main packaged E2E and evidence readback applicable to that task.
