# 2026-09-07 — 71168ad packaged macOS truncated-target generation race

- Project: `FAB-P0001 / TFI`
- Task: `TFI-MACOS-SEMANTIC-MESSAGE-ACTIONS-001`
- Canonical source: `71168adbeea65e998bb650ba3a4636911287636a`
- Electron quality run: `34058850412`
- macOS job: `101555620505`
- Exact diagnostics artifact: `9996959351` (`fabushi-electron-mac-e2e-diagnostics`)
- Artifact archive: `https://api.github.com/repos/bhrumom/fabushi/actions/artifacts/9996959351/zip`
- Artifact digest: `sha256:7da5587219e33c4c52d35e6df01f6d4ca50ee5f273936d0f2656eb28752d2515`

## Failure

The formal signed/notarized macOS package passed packaging, signature, notarization, staple and packaged Computer Use verification. In `e2e/app-agent-surface.spec.ts`, the 500-element snapshot intentionally omitted the authored-message target. Between that snapshot and the context-menu action, the renderer generation advanced by exactly one on both attempts (`75 -> 76`, retry `85 -> 86`). Because the target was intentionally absent from the truncated snapshot lease, stable-target rebase correctly refused to guess and returned `stale_app_surface_generation`.

The same exact run's Global Dharma packaged parity test passed, so this defect does not justify changing Marketplace, Bot, WebMCP, Web UI revision/account synchronization, or CNY 1080 sandbox entitlement semantics.

## Atomic repair contract

1. Keep the truncated snapshot assertion and require the target to remain absent from that snapshot.
2. Immediately before invoking the off-snapshot target, resolve it with semantic `find` and use that returned generation.
3. If and only if the action fails with `stale_app_surface_generation`, repeat `find -> action` within a bounded Playwright poll; any other error fails immediately.
4. Do not change `callSurfaceWithStableTargetRebase`, the DOM surface exact-generation guard, security policy, or product behavior.
5. Open-source-first decision: no new dependency is warranted; reuse the repository's already-proven fresh `find -> action` controller discipline recorded in this same task.
6. Real build/package/E2E validation is GitHub Actions only; no local application build/test.

## Acceptance

- [ ] Atomic PR required checks green.
- [ ] Protected merge creates a canonical main descendant of `71168ad...`.
- [ ] New exact-main Electron macOS packaged E2E passes this semantic App MCP test.
- [ ] New diagnostics retain screenshots/trace/report and exact source identity.
- [ ] Post-main remains fail-closed until all same-SHA desktop/mobile gates pass.
