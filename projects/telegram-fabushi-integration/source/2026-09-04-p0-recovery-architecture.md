# FAB-ARCH-P0-20260904 — TFI recovery architecture source

- Project ID: `FAB-P0001`
- Program ID: `FAB-ARCH-P0-20260904`
- Owner: Architecture project group
- Status: `ARCHITECTURE_READY_IMPLEMENTATION_NOT_VERIFIED`
- Source: user recovery mandate, live GitHub state, root `AGENTS.md`
- Baseline main: `688465e94647d4c866f6b1d7b4884145b2f4a9da`
- Audited M6 branch: `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`

## Required outcomes

1. Desktop returning-user/first-start Messenger paints complete cached message content immediately; the existing packaged target remains conversation-list first interactive `<1000 ms`.
2. A Bot MiniApp generation result is a message-level, directly openable MiniApp card rather than only code/text.
3. Installing a MiniApp idempotently materializes and displays its canonical Bot projection.
4. Every Bot executes only through `FAB-P0005/MSR`; Bot identity has exactly one durable Mahayana session, while conversation/thread context is scoped inside that session rather than creating another runtime.
5. Group Bot messaging implements the behavior contract owned by `FAB-P0004/GBF`: mention/privacy/session/tool-result semantics without copying unlicensed Grok Bot implementation.
6. M6 Group/Channel/Topic state has one membership authority, explicit admission, recipient-neutral durable journal, and protocol-v3-compatible negotiation without breaking v2 readers.

## Ownership

- TFI owns Messenger/Group/Channel/Topic transport, UI projection, MiniApp message card and install-to-Bot projection.
- MSR owns Mahayana CLI/Runtime, durable Bot session, tool/policy/approval bus and provider-neutral capability execution.
- GBF owns observable Bot behavior parity, same-account device capability semantics and MiniApp/device capability discovery contracts.

## Current branch findings that remain blockers

- `RespondCommunityJoin` computes `approved && <bool>.then(...).flatten()`, yielding an invalid boolean/Option expression.
- `ClientCommand::CreateConversation` still directly maps to `Command::UpsertConversation`; only `UpdateConversation` gained a Community-aware path.
- The repair series touches canonical membership, admission, journal and projection code but strict review has not accepted recovery/replay/negative-contract closure.
- Protocol constant remains v2; v3 reader/negotiation/admission/server-time/request-bridge closure is not established.

## Dependency graph

`TFI-M6-P0-001 -> TFI-M6-P0-002 -> {TFI-M6-P0-003, TFI-M6-P0-004} -> TFI-M6-P0-005`

`TFI-M3-P0-001` is independent of M6.

`TFI-M8-P0-001` is independent; `TFI-M8-P0-002` depends on `TFI-M8-P0-001 + MSR-210`.

`TFI-M7-P0-001` depends on `TFI-M6-P0-005 + MSR-210 + GBF-508`.

## Handoff gates

Execution -> Code Review -> Test Release -> Video Review -> Formal Release. No stage may self-promote. See `docs/2026-09-04-p0-release.md`.