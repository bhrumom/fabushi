# 2026-09-07 — returning-user seed active-peer persistence race

- Project/task: `FAB-P0001 / TFI` · `M3-DESKTOP-003`
- Triggering canonical SHA: `71168adbeea65e998bb650ba3a4636911287636a`
- Electron run: `34058850412`
- macOS job: `101555620505`
- diagnostics artifact: `9996959351` (`fabushi-electron-mac-e2e-diagnostics`)
- artifact archive: `https://api.github.com/repos/bhrumom/fabushi/actions/artifacts/9996959351/zip`
- digest: `sha256:7da5587219e33c4c52d35e6df01f6d4ca50ee5f273936d0f2656eb28752d2515`

## Observed failure

Both the first run and retry of `returning-user local-first conversation list is interactive within the one-second target` failed before the measured returning-user relaunch. After creating and clicking the self-hosted channel `首屏性能验收`, the test immediately read the durable local-first projection exactly once. `activePeerKey` had not yet persisted, so `seededConversationId` was empty and `expect(seededConversationId).not.toBe('')` failed.

The actual `< 1000 ms` returning-user target was therefore never evaluated in those two attempts. This evidence must not be described as a product performance regression.

## Minimal repair

Reuse the existing repository persistence discipline from the same `messenger.spec.ts`: bounded `expect.poll` on `fabushi.desktop.messenger-projection.v1.activePeerKey`. After the click, require a `selfhosted:*` durable active peer before extracting the id and seeding the existing 32 real Host messages.

Unchanged gates:
- real self-hosted channel creation and click;
- 32 real history messages through the Host command path;
- native/durable projection checks;
- full Electron relaunch;
- P0-P9 critical-path evidence;
- one-second interactive acceptance threshold.

No product/runtime behavior is changed. Heavy validation remains GitHub Actions only.
