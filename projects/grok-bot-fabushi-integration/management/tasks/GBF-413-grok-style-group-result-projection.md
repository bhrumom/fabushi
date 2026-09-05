# GBF-413 — Grok-style multi-step/multi-result group UX projection

- Project: `FAB-P0004 / GBF`
- Task ID: `GBF-413`
- Architecture revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`
- Status: `PLANNED`
- Wave: `3`
- Risk: medium; high-volume concurrent result UX

## Single objective

Project canonical TFI/MSR multi-Bot group-turn events into a Grok-Bot-like visible experience with participant, step, tool and multiple result lanes, without introducing a second state store/runtime.

## Dependencies

TFI `M5-BOTGROUP-001`, MSR `MSR-206`, GBF `GBF-412`.

## Exact implementation allowlist

- `desktop/src/messaging-shell-v2.tsx`
- `desktop/src/messaging-shell-v2.module.css`
- `frontend/apps/web/src/app/host/host-client.tsx`
- `desktop/e2e/messenger.spec.ts`
- `projects/grok-bot-fabushi-integration/evidence/GBF-413/**`

Forbidden: canonical event schema, Mahayana orchestrator, device gateway authorization, Marketplace ownership data, workflows/version files.

## Acceptance

1. A group turn with 2+ Bots renders each participant and its ordered running/waiting/tool/partial/final/failed state without collapsing results into one message.
2. Replayed events do not duplicate UI lanes; reconnect restores the same projection from canonical state.
3. Device/MiniApp tool result rows display the exact target identity and source Bot; sensitive values remain redacted.
4. Cancellation/failure is participant-scoped; completed other results remain visible.
5. UI exposes no control that bypasses TFI/MSR policy/routing; bot-to-bot loops are not inferred client-side.
6. Packaged E2E records a multi-participant, multi-step, multi-result journey including one targeted device or MiniApp action, screenshots, full video, trace and exact SHA.

## Open-source boundary

`bhrum/grok-bot-0.18-reconstructed` is a behavior/layout evidence source only. Do not copy renderer/source lacking an upstream source license.

## Rollback

Fallback to plain canonical messages/result summaries; persisted group events remain intact and executable state stays in MSR.
