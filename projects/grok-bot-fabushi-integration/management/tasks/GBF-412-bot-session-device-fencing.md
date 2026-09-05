# GBF-412 — Mahayana Bot-session fencing for exact-target device control

- Project: `FAB-P0004 / GBF`
- Task ID: `GBF-412`
- Architecture revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`
- Status: `PLANNED`
- Wave: `2`
- Risk: critical; remote computer mutation authorization

## Single objective

Extend the already-merged GBF-409/410/411 device authorization envelope so every Bot-issued mutating device call is fenced by the caller's current Mahayana Bot session identity/generation and an exact selected target device.

## Dependencies

Merged current-main GBF-409/410/411 behavior plus MSR-204 ToolExecutionContext. Do not reopen or replace the existing device/session/client/generation model.

## Exact implementation allowlist

- `chatgpt-vps-control/lib/fabushi-remote-mcp-server.js`
- `chatgpt-vps-control/lib/device-gateway.js`
- `desktop/electron/remote-device-agent-supervisor.cjs`
- `chatgpt-vps-control/tests/fabushi-remote-mcp-server.test.js`
- `desktop/electron/remote-device-agent-supervisor.test.cjs`
- `projects/grok-bot-fabushi-integration/evidence/GBF-412/**`

Forbidden: Mahayana session implementation, TFI messaging/MiniApp schema, generic secure-input weakening, new remote listener/protocol, workflow/version files.

## Required mutation envelope

`account_id, bot_actor_id, mahayana_session_id, mahayana_session_generation, conversation_id, invocation_id, target_device_id, target_device_generation, device_control_session_id, capability_grant_id, nonce/idempotency_key, expires_at` plus existing client/role/control flags.

## Acceptance

1. Mutating `device_call` cannot omit or wildcard `target_device_id`; no first/current/any-device fallback.
2. Wrong account/device/control session/client/role/device generation still fails as before.
3. Correct device state with stale/missing Bot session generation now also fails before forwarding the call.
4. Revoked grant, expired/replayed nonce and disabled AI/device control fail closed.
5. Audit/trace records Bot actor/session generation, conversation/invocation, exact device/tool and observed target generation while preserving secret redaction.
6. Human remote-control paths that are not Bot-issued remain governed by their existing contracts and are not forced through fake Bot identities.
7. Security tests cover cross-account, cross-device, stale Bot generation, stale device generation, replay, revoke and happy path; packaged/live E2E proves the selected device executes and another same-account device does not.

## Rollback

If the caller-fence adapter is defective, deny Bot mutations while retaining existing human/device authorization. Never roll back by accepting calls without the new Bot fence.
