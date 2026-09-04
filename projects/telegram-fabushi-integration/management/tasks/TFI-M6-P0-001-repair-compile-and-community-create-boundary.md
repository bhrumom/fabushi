# TFI-M6-P0-001 — repair compile blocker and Community-backed CreateConversation boundary

- Project ID: `FAB-P0001`
- Task ID: `TFI-M6-P0-001`
- Program: `FAB-ARCH-P0-20260904`
- Status: `NOT_STARTED`
- Owner: Execution project group
- Source: `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`, strict rejected review
- Dependencies: none
- Parallel: may run with TFI-M3-P0-001 / TFI-M8-P0-001; must not run concurrently with other M6 engine/service repair tasks.

## Objective

Make the current M6 slice compile without changing behavior by accident, and close the create-vs-update backdoor for an already Community-backed Group/Channel conversation.

## Primary modules

`native/mahayana-messaging/src/engine.rs`, `service.rs`, focused M6 contract tests; `protocol.rs` only if a typed error is already modeled there.

## Steps

1. Re-read the exact branch head and this task before editing.
2. Fix `RespondCommunityJoin` so `approved` gates an `Option<Event>` without `bool && Option` typing; preserve event ordering and rejection behavior.
3. For `CreateConversation`, detect existing Community-backed IDs before generic `UpsertConversation`. It must not overwrite `kind`, `owner_id` or derived participants. Define an explicit idempotent/no-op or typed AlreadyExists path and test it; do not silently reinterpret arbitrary client data as Community state.
4. Keep `UpdateConversation` limited to allowed informational fields for Community-backed conversations.
5. Add regression/negative contracts.

## Forbidden scope

No protocol-v3 work, no admission redesign, no journal redesign, no renderer changes, no local build/test.

## Acceptance

- Rust compilation succeeds in GitHub Actions.
- Approved and rejected join response paths have focused tests.
- Existing Community conversation cannot be replaced/retyped/re-owned through CreateConversation.
- Non-Community conversations retain intended create behavior.
- `git diff --check` and task record updated.

## Handoff

Commit/push one atomic change and PR. Record commit, PR and Actions links here. Code-review group must review real diff before any test-release group runs.