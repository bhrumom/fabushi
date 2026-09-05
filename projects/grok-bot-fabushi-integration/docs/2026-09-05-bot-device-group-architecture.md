# FAB-ARCH-20260905-01 — GBF architecture delta

Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`

GBF reuses current-main universal computer control and App/WebMCP surfaces. No new remote desktop authority, identity store or Agent runtime is introduced.

## Device boundary

Existing device authorization already matches account/device/client/control-session/device-generation and fail-closes stale/revoked state. The new requirement adds a caller-side Mahayana fence: `bot_actor_id + mahayana_session_id + mahayana_session_generation + conversation/invocation + capability_grant`. A device mutation is valid only when both device-side and Bot-runtime-side generations are current.

`list_devices` may enumerate same-account permitted devices, but every mutating call must name exactly one `target_device_id`; no implicit current/first/any-device selection. Read-only descriptions may be less restrictive only where existing policy explicitly allows them.

## Group/Grok parity boundary

Grok Bot 0.18 reconstructed behavior is an acceptance reference only. TFI owns durable group-turn events; MSR owns orchestration. GBF only renders/project those events into Grok-like multi-step/multi-result product UX and preserves exact target identity on device/MiniApp tool result cards.

## Rollback

The added Mahayana caller fence can be feature-disabled only by denying new Bot mutations, never by weakening existing GBF-409/411 checks. UI projection rollback must leave canonical TFI group events intact.
