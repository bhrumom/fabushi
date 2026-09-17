# FCM-024 — Zero-test automatic control plane and all-platform test release

- Project ID: `FAB-P0003`
- Project Key: `FCM`
- Task ID: `FCM-024`
- Started: `2026-09-16`
- Updated: `2026-09-16`
- Status: `in-progress`

## Objective

Finish the FCM-023 migration by eliminating the remaining automatic product-test/quality/E2E workflows, creating a fast no-behavior-test all-platform prerelease path, and retaining formal acceptance only as manually started Action runner + App-owned device + Fabushi official MCP external control.

## Acceptance

1. Active merge queue uses only the lightweight no-product-test `CI result` as the required test-like status.
2. Automatic E2E/unit/integration/contract/smoke/regression/simulator/emulator/user-journey/quality-test workflows are removed from `.github/workflows` or made non-automatic; release construction/deployment workflows remain.
3. `app-version.json` advancement on protected main triggers macOS/Windows/Linux packaging and immutable GitHub prerelease publication without behavioral tests.
4. The same exact source triggers iOS TestFlight and Android internal-track test builds without behavioral tests.
5. Test-release construction retains exact source/version/package/signing/notarization/checksum/provenance evidence.
6. Formal stable publication is separate and fail-closed until manually started Action-hosted App-owned device(s) are controlled through the Fabushi official MCP for the exact candidate.
7. No workflow-authored autonomous E2E is accepted as formal behavioral evidence.
8. Existing open PRs are merged where GitHub permits; merge-queue/conflict truth is reported without pretending queued PRs are already merged.
9. A strictly newer full-platform test version is published after the accepted PR set and final workflow cleanup reach canonical main.
10. Chrome test/release artifact construction remains available as a zero-test packaging path: exact source -> deterministic ZIP/content manifest/checksums -> immutable Action artifact. It must not install Playwright or run Node test/E2E suites merely to create the package.

## Implementation branch

`project/fcm-024-zero-test-release-20260916`

Follow-up repair branch: `codex/fcm024-chrome-zero-test-package-20260916` restored only the artifact-construction half of the Chrome workflow after the earlier FCM-024 cleanup correctly removed its automated product tests but also unintentionally removed the package artifact needed by downstream publication.

## Chrome zero-test package repair — delivered

- Repair PR [#2681](https://github.com/bhrumom/fabushi/pull/2681) passed PR CI and portfolio governance and then passed merge-group CI run `35106753460`.
- PR #2681 merged through protected merge queue on `2026-09-16T14:11:21Z` at canonical main `195ddb0d96ca58fb262b6fe5a8b859056bc013c9`.
- Push run [35106817630](https://github.com/bhrumom/fabushi/actions/runs/35106817630), job `104830079326`, completed successfully under workflow `Chrome Extension Package (zero-test)`.
- The job contained only checkout, Node setup, deterministic package construction, exact-source/version/checksum verification, and artifact upload. It did not install or run Playwright, Node test suites, product E2E, smoke, regression or user journeys.
- `fabushi-chrome-0.6.11.zip`: `124645` bytes, SHA-256 `7eb41b77c0cd86953729990467adc30a7eef2c2a500e4018e32d68e1864104db`.
- `fabushi-chrome-0.6.11.content-manifest.json` and `SHA256SUMS.txt` verified `OK` in the workflow log; manifest source SHA equals `195ddb0d96ca58fb262b6fe5a8b859056bc013c9`.
- Action artifact `10450532008`: `fabushi-chrome-web-store-195ddb0d96ca58fb262b6fe5a8b859056bc013c9`, `125574` bytes, artifact digest `sha256:7d95d6a5463a3a7d812ca7b9c533856ac06449150734db6769f638e88582bcb0`, expires `2026-12-15T14:11:23Z`.

## Current blockers

- Fabushi official MCP account/device calls still return a connection-layer HTTP 400: `We couldn't connect your account. Please try again.` This was rechecked after the Chrome package chain had been repaired.
- That failure blocks formal MCP validation and therefore blocks stable/formal publication; it does not invalidate the completed no-test package construction.
- Chrome Web Store formal submission for this candidate remains blocked until the exact candidate has the required official-MCP validation. Older autonomous Chrome journey runs, unified-device control, or a different device are not accepted as substitutes.

## Verification

- GitHub protected-main readback: Chrome product integration PR #2680 merged at `343019ed0d10ab4ecd9bd37c3aa686d3cc59f2c2`; zero-test package repair PR #2681 merged at `195ddb0d96ca58fb262b6fe5a8b859056bc013c9`.
- Exact-source package job/run and immutable artifact evidence are recorded above.
- The package workflow has no behavioral-test step.
- Fabushi official MCP must provide device/tool/finish evidence before any stable publication.

No local build/test is permitted.
## 2026-09-17 release execution round

- Fresh protected-main baseline before this round: `f15274ec0f3c5eb2007027f35d7f0cc8eb71b5af`.
- Requested historical PR set `#2297/#2299/#2316/#2446/#2620` is already merged. The remaining post-merge durability slice from #2620 was carried by #2697; exact head `826aed9430a40be77b067a22f71c9a755058540a` passed required `CI result` in run `35202081151`, and #2697 then merged through the protected SQUASH queue as `f15274ec0f3c5eb2007027f35d7f0cc8eb71b5af`.
- Open-PR readback after that merge returned an empty set.
- Canonical version before bump is `1.2.70 / Android 39 / iOS 39`; this round advances the test candidate to `1.2.71 / Android 40 / iOS 40`.
- Test publication remains zero-behavior-test: `electron-desktop.yml` for macOS/Windows/Linux immutable prerelease and `mobile-test-delivery.yml` for iOS TestFlight plus Android internal, both bound to the same accepted canonical SHA.
- Formal publication remains fail-closed until interactive Action runners install the exact candidate, the installed App self-registers fresh run-scoped App-owned devices, and the Fabushi official MCP controls those devices with run/device/SHA/video/screenshot/log evidence.
- MSR-204 remains separately `in-progress` for its explicitly recorded non-durability Hermes acceptance debt. This release round must not rewrite that product record as passed without corresponding implementation/evidence.

### 2026-09-17 PR #2698 exact-head repair

- First release head `b1a1b6aa1d000fdfdef20d5cb142df069894a41c` passed required `CI result` but exposed `RustDesk sidecar Linux / materialize-runtime` as an automatic PR test triggered only by the Desktop version change.
- That workflow violated the FCM-024 automatic-workflow whitelist and failed, so it was not ignored as an optional red status.
- The workflow is now changed to manual `workflow_dispatch` only on this branch. No local test/build substitutes for the fresh exact-head GitHub checks that must rerun after this governance repair.
- PR #2698 remains the single release/version PR and must re-enter the protected SQUASH merge queue only after the repaired exact head satisfies repository gates.

### 2026-09-17 same-version candidate repair after canonical `63a273cf...`

- The preliminary `e96c9bb1752036d3796d61d762d745bcdb9ef111` test delivery is diagnostic only because governance follow-up #2699 subsequently changed canonical main.
- Desktop no-test release run `35218893260` failed on Linux job `105193998581`, macOS job `105193998632`, and Windows job `105193998638` during renderer TypeScript compilation. Root causes: generated Mini App rendering expected a missing `TranscriptCard.kind = miniApp` union member, and Agent Bot conversation projection could receive `assistant-turn` while `BotTranscriptMessage` did not model/render it.
- Mobile parent run `35218893282` reached both stores. iOS TestFlight child run `35218919317` succeeded. Android internal child run `35218921320`, job `105193996429`, failed at `:app:compileReleaseKotlin` because `FabushiScreen.kt` referenced `MobileChatEntryKind.MINI_APP`, `miniAppName`, and `miniAppDescription` that were absent from `MarketplaceViewModel.kt`.
- Repair branch `fix/fcm024-1.2.71-renderer-contracts-20260917` starts from canonical `63a273cf47c0c600b63912487885cfff795ccae7` and repairs only those compile-time projection contracts.
- No local build or behavioral test is accepted. Final exact-head CI, protected SQUASH queue merge, and a fresh all-platform no-test delivery against the resulting canonical SHA remain required.
