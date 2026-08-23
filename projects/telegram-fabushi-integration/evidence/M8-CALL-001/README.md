# M8-CALL-001 Evidence Index

- Project: `FAB-P0001` / `TFI`
- Task: `M8-CALL-001`
- Branch: `feat/tfi-miniapp-ai-service-calls`
- Status: `IN_PROGRESS`

## Implementation evidence

- `native/mahayana-messaging/src/miniapp_service_call.rs` — service-call state/input/effect/action contract + unit tests.
- `native/mahayana-messaging/src/miniapp.rs` — `ServiceCall` capability and service-call bridge requests/responses.
- `native/mahayana-messaging/src/lib.rs` — public Rust domain export.
- `decisions/ADR-0008-miniapp-service-call-unified-conversation.md` — architecture decision.

## Verification evidence

- Local application build/test: **not run**, prohibited by repository disk-safety policy.
- GitHub Actions current-head CI: pending.
- PR / protected merge / canonical-main verification: pending.

This index must be updated with current-head workflow run/check IDs and merge SHA before the task can advance to `TESTED`/complete.
