# TFI-MACOS-STABLE-RELEASE-RESOLVER-001 — accept exact-main stable desktop Release

- **Project ID:** `FAB-P0001`
- **Project Key:** `TFI`
- **Task ID:** `TFI-MACOS-STABLE-RELEASE-RESOLVER-001`
- **Status:** `IN_PROGRESS`
- **Source canonical main:** `2bfa9898d453a91119f7dd9a072322970423cd6b`
- **Discovery run:** macOS interactive `34060996837`, job `101562624534`
- **Exact post-main Electron run:** `34060996860` (`success`)
- **Exact post-main delivery run:** `34061585236` (`success`)
- **Exact immutable Release:** `desktop-1.2.53-2bfa9898d453` -> `2bfa9898d453a91119f7dd9a072322970423cd6b`

## Defect

The canonical post-main workflow now publishes one immutable stable desktop Release (`draft=false`, `immutable=true`, `prerelease=false`) after exact-main Electron + Native mobile acceptance. Windows interactive resolves that Release by exact target SHA and matching installer asset. macOS interactive still filters candidates with `.prerelease == true`, so it cannot see the exact-main stable Release even though its target SHA and `fabushi-X.Y.Z-macos-arm64.zip` asset are correct. The macOS installer step also assumes legacy `vX.Y.Z` tags via `${RELEASE_TAG#v}`, while canonical post-main tags are `desktop-X.Y.Z-<sha>`.

This is a release-contract drift, not a product/Mini App failure. The `2bfa9898…` Electron packaged macOS journey already passed and uploaded `fabushi-electron-mac-e2e-diagnostics` artifact `9997619504`; the interactive workflow is blocked before installing that accepted Release.

## Minimal repair

1. Keep candidate selection fail-closed on `draft == false`, exact resolved target SHA == `GITHUB_SHA`, and the expected macOS ZIP asset name. Do not require prerelease classification.
2. Accept both canonical `desktop-X.Y.Z-<sha>` tags and legacy governed `vX.Y.Z` tags when deriving the bundle version; reject any other tag format.
3. Extend the existing macOS workflow ownership contract so `.prerelease == true` cannot silently reappear and desktop-tag parsing remains asserted.
4. Do not change account/session handling, App-owned device registration, semantic tools, journey assertions, signing/notarization, Release digest verification, or evidence retention.

## Open-source-first / provenance decision

No new dependency, framework, or protocol is introduced. The repair reuses the repository's existing GitHub Releases + `gh api` exact-SHA resolver model already used by the Windows interactive workflow, and standard GitHub Release fields (`draft`, `prerelease`, `target_commitish`, assets). Adding a dependency would increase CI surface without solving a domain-specific predicate mismatch.

## Acceptance

- PR required CI is green and the PR enters protected `main` normally; no admin/force merge.
- Re-read canonical `main` after merge and use only the new main SHA for acceptance.
- New exact-main Electron desktop, Native mobile, Computer-control security, and post-main delivery gates pass.
- The new exact-main macOS interactive run resolves the immutable Release without requiring `prerelease=true`, installs the exact package, logs in through the bounded CI account projection, waits for App-owned registration, and reaches the external journey gate.
- Required macOS interactive evidence uploads even on failure: whole-session video from before install, step screenshots, device-call trace, packaged Playwright report/trace/video/results, App/system logs, Release metadata/digests, report/README.
- Final completion additionally requires the exact-main desktop Global Dharma Mini App journey evidence already defined by TFI: Marketplace search/install, Bot, natural-language WebMCP, Open App Web UI, Bot/UI durable revision parity, Fabushi account projection, CNY1080 sandbox lifetime purchase/restore, restart/logout durability.

## Evidence / history

- `2bfa9898…` Electron desktop run `34060996860`: Linux/Windows/macOS packaged matrix completed successfully; current-SHA Global Dharma diagnostics exist for all three platforms.
- `2bfa9898…` Native mobile run `34060996858`: Android/iOS and aggregate result completed successfully; artifacts `9997520605` (`android-native-reports`) and `9997556592` (`ios-native-xcresult`).
- `2bfa9898…` Computer-control security run `34060996845`: completed successfully.
- `2bfa9898…` post-main run `34061585236`: exact bind to Electron run `34060996860` and immutable Release publication completed successfully.
- Release `desktop-1.2.53-2bfa9898d453`: target `2bfa9898…`, stable immutable Release with macOS ZIP/DMG, Windows setup, Linux packages and updater metadata.
- macOS interactive run `34060996837`: whole-session recording started, then blocked in `Wait for exact-main published macOS test release` because the workflow only admits prereleases.

Local build/test is prohibited for this task; all acceptance execution remains in GitHub Actions.
