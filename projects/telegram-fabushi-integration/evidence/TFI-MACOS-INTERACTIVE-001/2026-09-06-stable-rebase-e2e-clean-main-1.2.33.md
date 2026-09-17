# TFI-MACOS-INTERACTIVE-001 — clean-main stable App-target rebase E2E / 1.2.33

- Project: `FAB-P0001 / TFI`
- Task: `TFI-MACOS-INTERACTIVE-001`
- Clean base: protected `main@ec8da03778481ac5bc854c06cc141ea0f6a1d57f` (release-contract #2384 already merged)
- Historical stacked validation PR: `#2387`, head `5696ef12bf8e93bd2ae15155c3d074e31be39e2c`
- Historical Electron desktop validation run: `34000905515` — `success`
- Clean branch: `fix/tfi-electron-stable-rebase-e2e-1-2-33-main-20260906`
- Candidate governed macOS test version: `1.2.33`; Android version code and iOS build number remain `29`

## Independent defect

The packaged App Agent Surface E2E still encoded the pre-#2378 expectation that every action carrying a stale snapshot generation must fail. The live product contract is narrower: a remembered stable target identified by `agentId` may rebase once when route, screen and target fingerprint remain unchanged and no volatile positional reference is supplied. Positional generation refs remain exact and fail closed.

## Atomic repair

The packaged E2E now proves both sides of the existing contract without changing product implementation:

1. reuse the stale snapshot generation with stable `agentId=test:profile-navigation-trigger` and no positional ref; the bounded rebase must complete and close the profile menu;
2. reuse that same stale generation with explicit `ref=g0:volatile`; the call must reject with `stale_app_surface_generation`.

The clean branch is rebuilt directly from current protected main. It does not carry #2387's stacked merge history and does not duplicate #2384's already-merged release-contract repair. Canonical version files advance from `1.2.32` to `1.2.33`; release/CI source contracts retain the current main semantics and only bind the new version.

No App Agent Surface implementation, route/screen/fingerprint rule, remote-control opt-in, Computer Use safety rule, branch-protection rule, gateway ownership, login/session parser, or release-source policy is weakened.

After protected merge, only an immutable `v1.2.33` macOS test release built from that exact protected-main source with the required gates green may enter the next interactive attempt. Recording must begin before installation; the installed App must log in and self-register its account-scoped gateway before `@fabushi test` discovery/control. Empty discovery is a failure, never success.
