# 2026-09-07 — macOS exact-main recovery Release compatibility

- Project: `FAB-P0001 / TFI`
- Source baseline: canonical `main@2bfa9898d453a91119f7dd9a072322970423cd6b`
- Trigger: current-SHA post-main delivery run `34061585236` published immutable recovery Release `desktop-1.2.53-2bfa9898d453` because canonical `desktop-1.2.53` already belongs to historical SHA `71168adbeea65e998bb650ba3a4636911287636a`.
- Affected run: macOS interactive `34060996837`, job `101562624534`.

## User requirement carried forward

Close the canonical-main packaged delivery loop with truthful current-SHA evidence only: Release provenance, Windows/macOS interactive terminal results, full-session video, meaningful step screenshots, trace/report/logs, and the Global Dharma Mini App journey covering Marketplace search/install, Bot, Open App Web UI, natural-language WebMCP, Bot/UI same revision, bounded Fabushi auto-login, and test-mode CNY 1080 lifetime purchase/restore. Historical SHA evidence cannot close acceptance.

## Observed deterministic blocker

The current macOS interactive Release resolver requires `draft == false && prerelease == true`. The exact-SHA recovery Release emitted by the canonical post-main workflow is deliberately `draft:false`, `prerelease:false`, `immutable:true`, with `target_commitish=2bfa9898...`. Therefore the resolver cannot select the only valid current-SHA package and will time out.

A second deterministic incompatibility exists after selection: the install step derives the expected app version with `${RELEASE_TAG#v}`. Provenance-scoped recovery tags such as `desktop-1.2.53-2bfa9898d453` are not app SemVer, so the installed bundle version `1.2.53` would fail that comparison even if release selection succeeded.

## Required repair boundary

1. Preserve exact-source fail-closed authority: only a non-draft Release whose resolved `target_commitish` equals exact `GITHUB_SHA` may be installed.
2. Do not require `prerelease=true`; stable and recovery Releases are both eligible only after exact-SHA binding and strict macOS asset matching.
3. Derive expected application SemVer from the strict macOS asset filename `fabushi-X.Y.Z-macos-arm64.zip`, not from the Release tag.
4. Preserve bounded 20-minute wait, 15-second polling, artifact digest validation, codesign/Gatekeeper validation, whole-session recording-before-resolution/install, bounded account projection, App-owned registration, six semantic tools, final logout, Playwright, and always-upload evidence.
5. Add dependency-free contract assertions that reject reintroduction of the prerelease-only filter and tag-derived app version.

## Open-source-first startup gate

Reviewed GitHub CLI (`cli/cli`, MIT) Release create/edit/fetch implementation. GitHub Release `prerelease` and `target_commitish` are independent metadata fields; `target_commitish` is the provenance field and `prerelease` is not a source-identity guarantee. Reviewed electron-builder release workflow conventions as a secondary reference; release-event/tag semantics likewise must not substitute for immutable source provenance. We reuse the provenance principle only; no upstream code or new dependency is copied.

## Acceptance

- current-head contract test proves exact-SHA selection works independent of prerelease status;
- expected installed version is extracted from the matching macOS asset filename;
- PR passes required checks and merges through protected main/merge queue;
- new canonical main reruns the macOS interactive workflow and reaches terminal evidence;
- final task closure still requires the broader current-canonical-main desktop/mobile/post-main/Release and Global Dharma evidence. This repair alone is not delivery completion.
