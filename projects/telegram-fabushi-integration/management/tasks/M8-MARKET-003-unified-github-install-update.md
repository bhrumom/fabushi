# M8-MARKET-003 — 全平台 GitHub 小程序/插件安装更新合同

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M8-MARKET-003`
- **Stage**: `M8 Mini Apps`
- **WBS**: `M8.T14`
- **Status**: `RELEASED`
- **Started**: `2026-09-13`
- **Updated**: `2026-09-14`
- **Completed**: `2026-09-14T02:50:58Z` (product Release publication; governed record closure follows in this docs-only PR)
- **Test release target**: `1.2.65` (the existing `1.2.63`/`1.2.64` release lines remain immutable; `desktop-1.2.65` is the strictly newer accepted test Release)
- **Branch**: `codex/tfi-miniapp-unified-install-update-20260913`
- **Source requirement**: `../../source/2026-09-13-unified-github-install-update.md`

## Objective

让所有可安装小程序/插件都采用油猴式的 GitHub 版本分发模型：市场只提供审核后的版本清单，客户端直接取得不可变 GitHub/HTTPS 发布物，校验后安装；同一条状态合同驱动桌面、移动、Web、CLI 和 Chrome/用户脚本入口。

## Scope

- 统一 `pluginId + version + sourceRef + artifactSha256` 的发布/安装/更新状态。
- 复用现有 `mahayana.external-release.v1`、Rust `PluginInstaller`、Marketplace browse/release API 和 Host transport。
- Marketplace catalog、桌面 Mini Apps、Chrome Marketplace、公开 Web Marketplace 的安装/更新用户入口。
- GitHub 源码/不可变版本、权限、平台 artifact、校验失败与回滚语义的文档和回归合同。

## Out of scope

- 不把市场变成安装包字节代理或新增第二套插件协议。
- 不在宿主页面对远程代码执行 `eval`/动态注入。
- 不在本地执行 Electron、Rust、Android、iOS、完整 E2E 或打包构建；重验证由 GitHub Actions 完成。

## Acceptance criteria

1. Approved Marketplace release metadata points to a stable GitHub/HTTPS source ref and immutable artifact with SHA-256, size, format, entry, runtime and platform coverage.
2. A client can distinguish not installed / installed / update available / reinstall / blocked and uses one install/update path for userscript and package surfaces.
3. Desktop and Chrome call the canonical release + Host installer; Web records the same version/source/digest install state and never treats a bare localStorage id as a verified package install.
4. Updates are monotonic by version and digest, reject silent downgrade, and retain the previous active version when installation or verification fails.
5. Marketplace UI exposes source repository, source ref, current/latest version, permissions and release notes/status in an oil-monkey-style install card.
6. Backend, Rust/Host, frontend and Chrome contract tests cover GitHub source identity, platform filtering, digest/size validation, install/update state and unsafe remote-code rejection.
7. PR head CI, protected `main` merge, canonical-main readback, packaged Electron/mobile/CLI journeys and required screenshot/video/trace/report evidence are complete for the accepted product SHA; the task may be marked `RELEASED`.

## Verification plan

- Lightweight local inspection: `git diff --check`, JavaScript syntax checks for changed standalone files, targeted pure Node contract tests only when they do not build/package the application.
- GitHub Actions: backend tests, Rust/Host tests, frontend typecheck/build, Chrome extension contract/package checks, then exact-main packaged Electron/mobile/CLI journeys with always-retained visual/debug evidence.
- Release: publish only after required exact-main packaged journeys pass; Release assets must point to the accepted `main` SHA and use a strictly newer comparable version.

## Open-source-first survey and decision

- [Violentmonkey](https://github.com/violentmonkey/violentmonkey), MIT: use its mature userscript metadata model as the UX/protocol reference—stable script identity, explicit version metadata, update discovery and bundled execution boundary. No code is copied; Fabushi keeps its own Host permission model and package protocol.
- [Open VSX](https://github.com/eclipse-openvsx/openvsx), EPL-2.0: use the versioned extension listing, activation/update indexing and artifact integrity concepts as a market reference. Not added as a runtime dependency because its server/database stack does not fit Fabushi's Rust/Electron/Worker boundaries.
- [Obsidian community plugin releases](https://github.com/obsidianmd/obsidian-releases), community repository: use the manifest + version compatibility + GitHub Release asset pattern for discovery. It is a behavior reference, not vendored code or a new Fabushi dependency.
- Reuse decision: retain `mahayana.external-release.v1` and Rust `PluginInstaller` because they already implement HTTPS/GitHub release resolution, bounded download, SHA-256/size verification, staging, per-version storage and active-pointer switching. Extend the shared metadata/UI/status seams instead of rebuilding a parallel updater.

## Dependencies and risks

- Depends on M8-MARKET-001's approved catalog/release contract and M8-WEBMCP-001's Host/runtime boundary.
- The Web public catalog remains metadata-first: it records release metadata and delegates executable installs to a Host; it does not claim verified execution from a bare legacy ID.
- Every future package change still needs a new immutable source ref, digest and monotonic version. The three invalid legacy archives were revoked/replaced rather than mutated in place.
- The product delivery gates closed on canonical `main@f6a0d99c…`, with Release `desktop-1.2.65`; the optional old-client updater journey was not run and is not a required gate for this task.

## Implementation log

- 2026-09-13: Re-read canonical `origin/main` portfolio and reused `FAB-P0001 / TFI`; no new portfolio ID allocated.
- 2026-09-13: Persisted the user's GitHub-first requirement and opened this governed task record before implementation.
- 2026-09-13: Backend marketplace release metadata now emits `fabushi.marketplace.install.v1`, accepts only public GitHub repositories pinned to a 40-character commit, expands platform coverage to include `chrome-extension`, and keeps the marketplace metadata-only; the external-release publish path rejects non-GitHub executable artifacts.
- 2026-09-13: Rust Plugin Runtime/Host now validates the shared contract, verifies artifact bytes by SHA-256 and size, rejects monotonic-version downgrades, stores `previous-active.json`, and exposes explicit rollback through Host transports.
- 2026-09-13: Desktop, Web Host, public Web Marketplace, Android/iOS metadata clients, CLI, and Chrome Marketplace now consume the same release/install/update semantics. Web records release metadata only and requires a native Host for executable package installation.
- 2026-09-13: Chrome Marketplace now fetches a userscript only after an explicit user action from the contract's `raw.githubusercontent.com` URL fixed to the declared repository commit, checks redirect policy, size, SHA-256 and UserScript markers, and passes source provenance into the userscript runtime. The bundled copy remains bootstrap/compatibility only.
- 2026-09-13: Lightweight verification passed Chrome contract/platform tests `11/11`, backend pure marketplace tests `9/9`, JavaScript syntax checks, and `git diff --check`. The HTTP backend test was not run because this checkout has no `express` dependency; no dependency was installed.
- 2026-09-13: Read-only package audit found pre-existing release-data integrity issues in the fixed catalog: the `chatgpt-auto-confirm`, `faliu-flashcards`, and `hermes-installer` archives fail gzip validation; the catalog SHA/size for `chatgpt-auto-confirm`, `faliu-flashcards`, and `hermes-installer` do not match the checked-in bytes. This is recorded as a CI/release blocker for those artifacts, not silently repaired locally.
- 2026-09-13: Bumped the shared application/package metadata and release-control assertions from `1.2.57` to `1.2.58` so the requested test release remains update-comparable and cannot mutate the existing `v1.2.57` release.
- 2026-09-13: PR [#2590](https://github.com/bhrumom/fabushi/pull/2590) merged the CI-generated repair of the three invalid official archives to `main@5f67bb7a…`; PR [#2591](https://github.com/bhrumom/fabushi/pull/2591) merged the immutable release manifest/source binding to `main@cc23420c…`.
- 2026-09-13: Package repair workflow [34769542406](https://github.com/bhrumom/fabushi/actions/runs/34769542406) passed (`Build official package artifacts` job `103756495723`, publish job `103756528876`) and created immutable prerelease [marketplace-v1.0.1-cc23420c56c9](https://github.com/bhrumom/fabushi/releases/tag/marketplace-v1.0.1-cc23420c56c9). The first attempt [34769285913](https://github.com/bhrumom/fabushi/actions/runs/34769285913) was failed/deleted after it attempted a second upload to an immutable Release; the corrected run is the authoritative package evidence.
- 2026-09-13/14: Product PR [#2592](https://github.com/bhrumom/fabushi/pull/2592) merged the catalog, backend seed and migration updates to `main@da9af9e0…`; PR [#2593](https://github.com/bhrumom/fabushi/pull/2593) merged catalog-trigger and migration-order fixes to `main@31fdeca9…`. The follow-up cloud failures were retained as evidence and fixed by running the marketplace package test after migrations on the deployed Worker.
- 2026-09-14: Exact packaged E2E found and fixed a stale App Surface generation lease for stable `find` results in PR [#2596](https://github.com/bhrumom/fabushi/pull/2596), merged as `main@91521e88…`; PR [#2597](https://github.com/bhrumom/fabushi/pull/2597) added the exact Chrome trigger path and merged as `main@942cefe7…`.
- 2026-09-14: PR [#2598](https://github.com/bhrumom/fabushi/pull/2598) advanced the comparable product version to `1.2.65` (Android/iOS build/code `34`) and merged as `main@845fccec…`; PR [#2599](https://github.com/bhrumom/fabushi/pull/2599) added version-file paths to the Chrome exact-source trigger and merged the accepted product head `main@f6a0d99c85a481999298a18cada6a9f10718a360`.

## Branch / commit / PR / evidence

- Product implementation started from PR [#2578](https://github.com/bhrumom/fabushi/pull/2578); the protected delivery chain also includes [#2579](https://github.com/bhrumom/fabushi/pull/2579), [#2581](https://github.com/bhrumom/fabushi/pull/2581), [#2582](https://github.com/bhrumom/fabushi/pull/2582), [#2583](https://github.com/bhrumom/fabushi/pull/2583), [#2585](https://github.com/bhrumom/fabushi/pull/2585), [#2586](https://github.com/bhrumom/fabushi/pull/2586), [#2590](https://github.com/bhrumom/fabushi/pull/2590), [#2591](https://github.com/bhrumom/fabushi/pull/2591), [#2592](https://github.com/bhrumom/fabushi/pull/2592), [#2593](https://github.com/bhrumom/fabushi/pull/2593), [#2596](https://github.com/bhrumom/fabushi/pull/2596), [#2597](https://github.com/bhrumom/fabushi/pull/2597), [#2598](https://github.com/bhrumom/fabushi/pull/2598) and [#2599](https://github.com/bhrumom/fabushi/pull/2599).
- Implementation commits: `3cd8ba783` (shared GitHub install/update flow), `cc23420c56c98f7857b731832281c212203ce60c` (repaired official release manifest), `85b3a8b258269e9d4e234e648d086653146ffc82` (stable-find generation lease), and `bf8a1fdac975d564d116a3e995a2df288a3c2241` (Chrome version trigger). The final product main SHA is `f6a0d99c85a481999298a18cada6a9f10718a360`.
- Version line: `1.2.63` was the previously accepted product baseline; the intermediate `1.2.64` release line is preserved as immutable recovery provenance; the accepted comparable test version is `1.2.65`.
- Canonical product gates: CI/merge-group fallback [34799982178](https://github.com/bhrumom/fabushi/actions/runs/34799982178) and merge-group [34799981704](https://github.com/bhrumom/fabushi/actions/runs/34799981704) passed; Chrome [34800013075](https://github.com/bhrumom/fabushi/actions/runs/34800013075), Native mobile [34800013089](https://github.com/bhrumom/fabushi/actions/runs/34800013089), Electron [34800013097](https://github.com/bhrumom/fabushi/actions/runs/34800013097), Global Dharma exact-main evidence [34800500538](https://github.com/bhrumom/fabushi/actions/runs/34800500538), and post-main delivery [34800500558](https://github.com/bhrumom/fabushi/actions/runs/34800500558) all passed against the exact final SHA.
- Packaged job evidence: Electron macOS `103840631203`, Linux `103840631401`, Windows `103840631412`; Native Android `103840630838`, iOS `103840631007`; Chrome package job `103840630671`; post-main gate `103842055345`, publish `103842076233`.
- Evidence artifacts (90-day retention, expiry `2026-12-13`): Electron diagnostics/packages `10330992099`, `10331016984`, `10331361708`, `10331366828`, `10331600952`, `10331645539`, `10331680984`; Native reports `10331116764`, `10331631060`; Chrome package `10331530747`; post-main source binding `10330783065` and delivery bundle `10331456743`.
- Release: [desktop-1.2.65](https://github.com/bhrumom/fabushi/releases/tag/desktop-1.2.65), published `2026-09-14T02:50:58Z`, `target_commitish=f6a0d99c85a481999298a18cada6a9f10718a360`, latest stable Release. Assets include macOS DMG/ZIP plus blockmaps and `latest-mac.yml`, Windows/Linux installers and updater metadata, SHA256 manifests, and the Chrome package/content manifest.
- Release data audit: `marketplace-v1.0.1-cc23420c56c9` contains the three repaired `1.0.1` archives and manifest with verified SHA-256/size; final `desktop-1.2.65` self-reference checks for `SHA256SUMS.txt` and `fabushi-chrome-SHA256SUMS.txt` passed.
- Chrome Web Store: exact-source package dry-run [34796574040](https://github.com/bhrumom/fabushi/actions/runs/34796574040) passed for an earlier accepted product SHA. No public submission was attempted because protected store credentials were unavailable; the final Chrome package was nevertheless produced by exact final push run `34800013075`. Public-store submission is outside this test Release gate.
- Optional updater regression: not run; old-client discovery/download/install/relaunch is advisory by repository policy and was not promoted to a required acceptance criterion for this task.
- Records branch for this closure: `codex/tfi-market-003-record-closure-20260914`; this docs-only follow-up has product delivery `N/A` because it changes only governed project records, not runnable sources or package inputs.
- Records PR: [#2600](https://github.com/bhrumom/fabushi/pull/2600), merged as records commit `b0ac0efb822398b658464ab1b559fd4ca41f004d`; canonical project records were re-read from `main` after merge.
- Evidence index: `../../evidence/M8-MARKET-003/README.md`.

## Completion / next action

This task is `RELEASED`: the product PR chain is protected-merged, the exact accepted product SHA is `main@f6a0d99c…`, the packaged Electron/mobile/Chrome journeys and always-retained visual/debug evidence passed, and `desktop-1.2.65` is published against that SHA. The remaining work is optional updater sampling and any broader M8 marketplace authorization/revocation/sandbox expansion tracked in separate tasks; neither is a blocker for this task.
