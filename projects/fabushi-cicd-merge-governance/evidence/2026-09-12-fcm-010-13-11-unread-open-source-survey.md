# FCM-010.13.11 open-source-first survey — unread/read-boundary state

- Project: `FAB-P0003 / FCM`
- Atomic task: `FCM-010.13.11`
- Repair PR: `#2561`
- Survey date: `2026-09-12`
- Scope: the production Mahayana assistant's `unread_count` transition, explicit read/open boundary, background history/index isolation, and authoritative conversation-list refresh.
- Trigger: independent review of PR #2561 found that the stateful Rust/Electron unread redesign lacked the repository-required open-source-first decision record.

## Problem statement and constraints

The failed fresh production target `34696426684/1` proved that Fabushi's default Mahayana assistant could receive and render a real assistant reply while its authoritative conversation list remained permanently at `unread_count=0`. The repair therefore needs a small, deterministic state model that:

1. derives unread state from assistant completions after a read boundary;
2. never counts user messages as unread;
3. clears unread only at a user-intent read/open boundary, never because a background index/history query happened;
4. makes the authoritative list refresh after both assistant completion and explicit open;
5. preserves persisted-history privacy and the existing local-first Mahayana/FeatureHost architecture;
6. does not add a network service, new account authority, screenshot/OCR fallback, or a broad messaging framework dependency.

Current Fabushi constraints matter to reuse decisions: the provider is Rust, the desktop shell is Electron/TypeScript, the transcript is local, and the existing `ConversationProvider::history(limit)` contract does not expose a first-class read-receipt parameter. FeatureHost's explicit open currently requests `200` history items while the background index path requests `2,000` and Runtime clamps it to `500`.

## Candidate 1 — Matrix Rust SDK

Canonical repository: https://github.com/matrix-org/matrix-rust-sdk

Relevant upstream evidence:

- Room-list FFI exposes unread notification counts and an unread filter: https://github.com/matrix-org/matrix-rust-sdk/blob/main/bindings/matrix-sdk-ffi/src/room_list.rs
- Current SDK changelog records that precise unread-count computation moved from sliding-sync processing into the event cache, and clients must enable the event cache for precise counts: https://github.com/matrix-org/matrix-rust-sdk/blob/main/crates/matrix-sdk/CHANGELOG.md
- The SDK exposes explicit read-receipt / mark-fully-read concepts rather than treating ordinary history retrieval as proof of reading; the FFI changelog explicitly exposes `Room::mark_as_fully_read_unchecked` and warns that misuse can cause incorrect receipts: https://github.com/matrix-org/matrix-rust-sdk/blob/main/bindings/matrix-sdk-ffi/CHANGELOG.md
- A 2026 upstream issue documents the exact operational class of stale/incorrect unread counts across sync/session boundaries, reinforcing that unread must be tied to authoritative event/read state rather than a static list field: https://github.com/matrix-org/matrix-rust-sdk/issues/6211
- License: Apache-2.0 for the Rust SDK crates: https://github.com/matrix-org/matrix-rust-sdk/blob/main/bindings/matrix-sdk-ffi/Cargo.toml

Assessment:

| Dimension | Finding |
| --- | --- |
| Architecture | Event/cache-derived room state with explicit read-receipt semantics. This strongly matches the desired separation between incoming-event state and user read intent. |
| API/data model | Unread counts are room state; read receipts / fully-read markers are separate operations. This is preferable to deriving “read” merely from a fetch. |
| Testing strategy | The project maintains dedicated sync/event-cache/read-receipt code paths and regression-driven changes; the recent unread-count migration and closed bug demonstrate that exact state transitions are treated as correctness-sensitive behavior. |
| Operational edge cases | Multi-session sync and delayed state propagation can make cached unread stale. The lesson for Fabushi is to refresh the authoritative list after the state-changing event/open and keep the state owner in the runtime, not the renderer. |
| Security/privacy | The pattern does not require the UI to inspect private message text to compute unread. Fabushi can preserve its existing local transcript and expose only count/projection state. |
| Maintenance | Active Rust project with ongoing releases and 2026 unread/read-receipt work. |
| License | Apache-2.0 is compatible for learning/adaptation and would permit reuse with notices if a narrow reusable component actually fit. |
| Compatibility | Language fit is strong (Rust), but Matrix's protocol, room/event-cache stack, sync engine, identifiers, and network semantics are far broader than Fabushi's built-in single assistant provider. Pulling the SDK in would add a large irrelevant protocol dependency. |
| Decision | **Learn/adapt the architecture, do not add the dependency.** Adopt the principles “event-derived unread state + explicit read boundary + authoritative projection refresh”; keep Fabushi's small provider-specific implementation. |

## Candidate 2 — Signal Desktop

Canonical repository: https://github.com/signalapp/Signal-Desktop

Relevant upstream evidence:

- Signal persists conversation-level `unreadCount` and separately tracks `markedUnread`, rather than conflating automatic unread messages with a manual unread marker: https://github.com/signalapp/Signal-Desktop/blob/main/ts/sql/migrations/index.node.ts
- Signal's current UI exposes separate Mark read / Mark as unread operations and renders list-level unread badges from conversation state: https://github.com/signalapp/Signal-Desktop/blob/main/_locales/en/messages.json
- The desktop application is Electron/TypeScript, directly relevant to Fabushi's renderer boundary: https://github.com/signalapp/Signal-Desktop/blob/main/package.json
- License: AGPL-3.0-only: https://github.com/signalapp/Signal-Desktop

Assessment:

| Dimension | Finding |
| --- | --- |
| Architecture | Mature Electron desktop messenger with persisted conversation state feeding a conversation-list projection. |
| API/data model | Automatic `unreadCount` and manual `markedUnread` are distinct state. This supports Fabushi keeping `Conversation.unread_count` authoritative and not manufacturing list badges in the renderer. |
| Testing strategy | Signal has long-lived schema migrations and derived unread-stat utilities, so unread behavior is treated as persisted data-model behavior rather than a transient DOM concern. For Fabushi, deterministic provider tests plus a transport regression are the appropriate smaller equivalent. |
| Operational edge cases | Persisted data must survive restarts without converting historical messages into newly unread messages; Fabushi therefore initializes loaded history at the current read boundary and only counts later assistant completions. |
| Security/privacy | Signal's model keeps unread metadata as structured conversation state; Fabushi likewise should not inspect screenshots/OCR or export transcript content merely to produce a badge. |
| Maintenance | Very active desktop messenger with frequent releases and current 2026 development. |
| License | **AGPL-3.0-only.** Direct code copying/linking would impose copyleft obligations not justified for this narrow repair. |
| Compatibility | Electron concepts are highly relevant, but Signal's encrypted messaging/storage stack and application model do not fit Mahayana's provider interface. |
| Decision | **Conceptual learning only; no code reuse.** Preserve the separation of persisted unread metadata from renderer projection, but implement inside Fabushi's existing Rust provider/transport boundaries. |

## Candidate 3 — Mattermost

Canonical repository: https://github.com/mattermost/mattermost

Relevant upstream evidence:

- Mattermost's public data model gives channel membership an explicit `last_viewed_at` and message/mention counts, and its unread response carries message/mention counts plus last-viewed state: https://github.com/mattermost/mattermost-api-reference/blob/master/v4/source/definitions.yaml
- A real upstream issue shows that changing `last_viewed_at` alone can still leave a thread unread, demonstrating that read state can have more than one boundary and should not be inferred from an unrelated fetch: https://github.com/mattermost/mattermost/issues/30115
- Mattermost source licensing is mixed; much platform source is AGPLv3 while designated admin/configuration paths are Apache-2.0: https://github.com/mattermost/mattermost/blob/master/LICENSE.txt

Assessment:

| Dimension | Finding |
| --- | --- |
| Architecture | Server-authoritative per-user/per-channel read boundary with list/count projection derived from durable membership/message state. |
| API/data model | Explicit last-viewed/read state is separate from message retrieval. This reinforces that background history/index scans must be observational. |
| Testing strategy | The mature platform has separate channel/thread unread semantics; the upstream issue is a concrete warning that one marker can be insufficient when scopes differ. Fabushi has only one assistant conversation today, so its regression should lock the exact single-conversation boundary and avoid silently generalizing to threads. |
| Operational edge cases | Thread-vs-channel and import/migration state can create false unread/read results. Fabushi should fail closed if it later introduces multiple assistant threads rather than assuming today's single boundary scales automatically. |
| Security/privacy | Server authority is unnecessary for Fabushi's local assistant; adding one would expand trust and attack surface. |
| Maintenance | Mature actively maintained collaboration product. |
| License | Mixed AGPL/commercial/Apache paths make direct server-source reuse unattractive for this repair. |
| Compatibility | Data-model lesson is relevant; the networked multi-user server architecture is not. |
| Decision | **Reject implementation reuse; retain the explicit-boundary lesson.** No Mattermost dependency or copied source. |

## Reuse / adapt / reject decision

No surveyed project provides a narrow reusable component that fits Fabushi's existing `ConversationProvider` contract without importing an entire foreign messaging/sync stack or creating license/operational cost disproportionate to the repair.

The repair therefore remains custom, but it is **not an invention from scratch** after this survey. It adapts four proven cross-project principles:

1. **Runtime/event-derived unread state, not renderer inference.** Matrix moved precision-critical unread computation into its event cache; Signal stores unread as conversation state; Mattermost derives it from durable membership/message state. Fabushi keeps the count in `KernelConversationProvider` and projects it through authoritative `conversation.list`.
2. **A read boundary is an explicit semantic event.** Matrix has read receipts / fully-read markers and Mattermost has last-viewed/read operations. Fabushi must not clear unread merely because background indexing fetched history.
3. **Persisted old history starts read; only later incoming assistant completions become unread.** This matches mature messenger behavior and prevents restart-time false positives.
4. **Refresh the authoritative list after state transitions.** The Electron transport asks for `conversation.list` after assistant completion and after explicit open so UI projection follows runtime truth rather than stale local DOM state.

## Why the current compatibility shim is acceptable — and its limit

The ideal API, consistent with Matrix/Mattermost, would expose an explicit `mark_read` / read-receipt intent at the provider boundary. Fabushi's current provider contract has only `history(conversation_id, limit)` for the relevant open/index path. The smallest atomic repair therefore uses the existing, already-distinct FeatureHost contracts: explicit production open requests exactly `200`; background indexing arrives as `500` after clamping. The provider marks read only for the explicit-open `200` contract and a Rust regression proves `500` cannot clear unread.

This is a **compatibility shim, not a reusable protocol design**. It is acceptable for FCM-010.13.11 because it avoids expanding a production repair across every provider/host interface while preserving a deterministic fail-closed distinction already owned by FeatureHost. If a second caller needs a `200` background history window, if another provider needs the same behavior, or if conversation threads are introduced, this numeric intent encoding must be replaced by an explicit read-boundary API before reuse. That follow-up condition is recorded here so the magic number cannot silently become architecture.

## Test and acceptance mapping

The survey changes no production gate. The implementation must still prove:

- Rust state regression: persisted history starts read; user messages do not increment; assistant completions do; explicit-open `200` clears; background `500` does not.
- Electron transport regression: real command-observer mapping is exercised and both `conversation-list-after-open-*` and `conversation-list-assistant-message-*` refreshes occur.
- Existing fail-closed constraints remain: `find limit<=100`, generation re-resolution, exact semantic identities/names, immutable source/Release/device lineage, all 27 categories, real nonzero remote actions, and the exact final `READY_FOR_LOGOUT PASS -> ci_session_finish -> fresh App snapshot -> settings-logout` chain.
- Post-merge proof must come from a brand-new production-controller-dispatched frozen-source target, never from `34696426684`, `34691502192`, or older evidence.

## Provenance / licensing conclusion

No source code from Matrix Rust SDK, Signal Desktop, or Mattermost is copied into this repair. Matrix's Apache-2.0 design is used as an architectural reference; Signal's AGPL-3.0 implementation and Mattermost's mixed-license server source are explicitly **not** reused. The current Fabushi changes remain original code inside existing Mahayana and Electron boundaries, with the external repositories serving only as documented design evidence and risk checks.
