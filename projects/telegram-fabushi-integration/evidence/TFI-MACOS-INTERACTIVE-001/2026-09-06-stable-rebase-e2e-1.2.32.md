# TFI-MACOS-INTERACTIVE-001 — stable App-target rebase E2E parity / 1.2.32

- Base protected main: `46050cdb3cf91c7cdc59548d8153e255c72782ed`
- Discovery PR/run: `#2384`, Electron desktop run `34000293854`, Linux job `101397827616`
- Failing test: `desktop/e2e/app-agent-surface.spec.ts`
- Atomic branch: `fix/tfi-electron-stable-rebase-e2e-1-2-32-20260906`

## Independent failure

The restored Electron quality gate passed dependency-free source contracts, built the real Linux Rust Host, started the real test stack, and then failed the packaged App Agent Surface Playwright journey. The test took a snapshot lease for stable target `test:profile-navigation-trigger`, performed one action, then reused the now-stale snapshot generation while still expecting `stale_app_surface_generation`.

That expectation predates #2378. The live bridge intentionally allows rebase only for a stale `action` from a remembered snapshot lease, with a stable `agentId`, no volatile positional ref, unchanged route/screen, and exactly one unchanged target fingerprint. Base DOM generation checks remain fail-closed; positional refs are never rebound; leases and retries remain bounded.

## Atomic repair

The packaged E2E now requires the stale leased stable profile trigger to complete through bounded rebase and close the menu, then proves the same stale generation with a volatile positional ref still rejects with `stale_app_surface_generation`.

No App Agent Surface implementation, safety boundary, generation rule, route/screen rule, fingerprint rule, branch protection, gateway ownership, or product behavior changes. The existing source-level stable-rebase contract remains required.

This independent-failure slice stages strictly newer comparable macOS test version `1.2.32`; Android version code and iOS build number remain `29`. PR #2384 remains separate for its release/source-contract drift; after this repair protected-merges, #2384 must absorb latest main, advance again, and rerun the restored gates.
