# M8-MARKET-003 — 全平台 GitHub 小程序/插件安装更新合同

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M8-MARKET-003`
- **Stage**: `M8 Mini Apps`
- **WBS**: `M8.T14`
- **Status**: `IN_PROGRESS`
- **Started**: `2026-09-13`
- **Updated**: `2026-09-13`
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
7. PR head CI, protected `main` merge, canonical-main readback, packaged Electron/mobile/CLI journeys and required screenshot/video/trace/report evidence remain mandatory before this task can be marked complete.

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
- The Web public catalog is currently a presentation/localStorage surface, so it must not claim verified package installation until it stores release metadata and delegates executable installs to a Host.
- Existing official package hashes are tied to a fixed repository commit; every future package change needs a new immutable source ref, digest and monotonic version.
- Required CI/package/E2E/release evidence is still open; this record must remain `IN_PROGRESS` until the protected-main and post-main gates close.

## Implementation log

- 2026-09-13: Re-read canonical `origin/main` portfolio and reused `FAB-P0001 / TFI`; no new portfolio ID allocated.
- 2026-09-13: Persisted the user's GitHub-first requirement and opened this governed task record before implementation.
- 2026-09-13: Backend marketplace release metadata now emits `fabushi.marketplace.install.v1`, accepts only public GitHub repositories pinned to a 40-character commit, expands platform coverage to include `chrome-extension`, and keeps the marketplace metadata-only; the external-release publish path rejects non-GitHub executable artifacts.
- 2026-09-13: Rust Plugin Runtime/Host now validates the shared contract, verifies artifact bytes by SHA-256 and size, rejects monotonic-version downgrades, stores `previous-active.json`, and exposes explicit rollback through Host transports.
- 2026-09-13: Desktop, Web Host, public Web Marketplace, Android/iOS metadata clients, CLI, and Chrome Marketplace now consume the same release/install/update semantics. Web records release metadata only and requires a native Host for executable package installation.
- 2026-09-13: Chrome Marketplace now fetches a userscript only after an explicit user action from the contract's `raw.githubusercontent.com` URL fixed to the declared repository commit, checks redirect policy, size, SHA-256 and UserScript markers, and passes source provenance into the userscript runtime. The bundled copy remains bootstrap/compatibility only.
- 2026-09-13: Lightweight verification passed Chrome contract/platform tests `11/11`, backend pure marketplace tests `9/9`, JavaScript syntax checks, and `git diff --check`. The HTTP backend test was not run because this checkout has no `express` dependency; no dependency was installed.
- 2026-09-13: Read-only package audit found pre-existing release-data integrity issues in the fixed catalog: the `chatgpt-auto-confirm`, `faliu-flashcards`, and `hermes-installer` archives fail gzip validation; the catalog SHA/size for `chatgpt-auto-confirm`, `faliu-flashcards`, and `hermes-installer` do not match the checked-in bytes. This is recorded as a CI/release blocker for those artifacts, not silently repaired locally.

## Branch / commit / PR / evidence

- Branch: `codex/tfi-miniapp-unified-install-update-20260913`
- Commit: pending
- PR: pending
- CI/E2E/Release: pending
- Evidence index: `../../evidence/M8-MARKET-003/README.md` (implementation evidence recorded; PR/main/post-main evidence pending)

## Next action

Open the task PR with the implementation and records, run exact-head CI and required review/protected-main gates, then execute the exact accepted `main` packaged Electron/mobile/CLI journeys with the mandatory screenshots/video/trace/report bundle before considering Release publication or task closure.
