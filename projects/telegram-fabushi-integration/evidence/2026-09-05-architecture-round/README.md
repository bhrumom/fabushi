# TFI architecture-round evidence index — 2026-09-05

- Architecture revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`
- Baseline: `bhrumom/fabushi@586a0952f17ab4b36dab9a69402b837968f5aa3f`
- Evidence status: architecture facts only; runtime/product acceptance evidence is not yet present.

## Current-main evidence anchors

- Local-first startup contract and existing packaged startup-performance gate: `management/tasks/M3-DESKTOP-002-local-first-settings.md`, `desktop/e2e/messenger.spec.ts`.
- Canonical Bot and MiniApp types: `native/mahayana-messaging/src/bot.rs`, `native/mahayana-messaging/src/miniapp.rs`, `native/mahayana-messaging/src/conversation.rs`.
- Marketplace generation/install surfaces: `ai-backend/src/miniapp_marketplace*.js`.
- Existing installed-MiniApp Bot projection: `management/tasks/M8-MARKET-002-openmaus-avatar-miniapp-bot-parity.md` and merged PR #2158.

## Planned task evidence directories

- `evidence/M3-DESKTOP-003/`: P0-P9 packaged startup critical-path JSON/video/trace/logs.
- `evidence/M3-DESKTOP-004/`: repaired startup timing and regression journeys.
- `evidence/M8-ENTITY-001/`: MiniApp lifecycle compatibility/multidevice state-transition proof.
- `evidence/M8-BIND-001/`: one-install/one-Bot/direct-conversation multidevice + packaged proof.
- `evidence/M8-CARD-001/`: generate -> entity card -> install/open/restart packaged proof.
- `evidence/M5-BOTGROUP-001/`: protocol parity/idempotency/replay proof.

No item above is implementation evidence until its exact task head and CI/E2E artifacts are written back.