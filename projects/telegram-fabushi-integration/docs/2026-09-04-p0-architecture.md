# TFI P0 target architecture — 2026-09-04

- Project: `FAB-P0001/TFI`
- Program: `FAB-ARCH-P0-20260904`

## 1. Messaging projection plane

`Rust state/journal -> Host events -> renderer projection` is canonical reconciliation. `fabushi.desktop.messenger-projection.v1` is a bounded display projection only. Startup must normalize cached messages into the same `DisplayMessage` shape used by live `conversation.opened`; UI paints from cache first, then issues `conversation.open` asynchronously. A late Host event may reconcile/update but may not replace complete cached content with an empty/intermediate payload unless canonical state proves deletion.

## 2. Community authority

For `ConversationKind::Group | Channel`, `CommunityState.members` is the sole membership source. Conversation participants are regenerated projections. Raw participant upsert/remove commands cannot mutate Community-backed membership. Recovery, sync snapshots, event projection and journal replay must derive the same participant set.

## 3. MiniApp card/install plane

Generation producer remains the existing `mahayana.miniapp.generation.v1` workflow. A consumer adapter must first validate the actual generated workflow/catalog/release fields, then emit a versioned MiniApp message card; do not invent duplicate package metadata. The card resolves to existing Marketplace/InstallMiniApp/OpenMiniApp paths.

Installed Bot identity remains derived by `desktop/src/miniapp-bot-projection.ts` from catalog/manifest `bot` metadata. No second contact DB is introduced. TFI asks MSR to bind the Bot identity to its single durable Mahayana session.

## 4. Protocol evolution

Implemented version remains v2 until the v3 task lands. Target v3 uses explicit supported-version negotiation, a documented v2 reader boundary, authoritative server timestamp, request-id bridge and admission result fields. Unsupported future versions fail explicitly; no writer emits v3-only state to a negotiated v2 peer.

## 5. Group Bot boundary

TFI transports mention/reply/command/tool-result events; GBF defines behavioral triggering/privacy semantics; MSR executes the Bot turn. A Bot keeps one Mahayana session; group/conversation/topic identifiers become scoped context inside that session, not extra runtimes.