# 2026-09-07 — Desktop interactive exact-main Release binding

## Current acceptance baseline

- Canonical main at task restart: `113379cb2313e03a7a90d397da2da2f1918b5de3`.
- Final acceptance may use only this SHA or a later protected-main merge produced by this repair. Earlier `ee8cd4b3…` / `71168ad…` evidence is diagnostic history only and does not satisfy final completion.
- Heavy build/package/UI/video work remains GitHub Actions-only.

## Problem statement

Both desktop App-owned interactive workflows resolve the globally newest compatible GitHub Release asset, then install it while the workflow source may be a newer canonical `main` SHA. This can silently execute a different product revision from the exact source under validation.

The defect was observed concretely on Windows run `34059848147`: workflow source `ee8cd4b3a7b51b18497fd34164781f13e3ebaf31` selected `desktop-1.2.21-4bc3e832fffe` -> `4bc3e832fffe4eaff21aa6fbf617a33133302c62`, installed `1.2.21.0`, then timed out before App-owned registration. The failure artifact was `9997183366`. This old-SHA run is diagnostic only; it is not final evidence.

The current macOS workflow has the same selection pattern (`sort_by(.published_at // .created_at) | last`) and therefore the same exact-main lineage risk even if a current run has not yet exposed it.

## Open-source-first startup gate

Reviewed mature GitHub-native release patterns before choosing the repair:

- GitHub Releases REST API documents `target_commitish` as the commit/branch that a release tag is created from; exact source identity must therefore be resolved to an immutable commit SHA before accepting a Release.
- GitHub Actions/Marketplace examples create releases with `target_commitish: ${{ github.sha }}` rather than relying on publication recency.
- `loft-sh/github-actions` publishes a reusable wait-for-release action that uses bounded polling and can fail fast when the producer failed. We reuse the proven bounded-polling design, but keep the implementation repository-local because Fabushi must additionally inspect platform asset names and resolve each release target to the exact current SHA.

No new runtime dependency or protocol is introduced.

## Root cause

The interactive workflows are push-triggered at the same time as the canonical Electron/native/post-main delivery producer. Therefore the exact-main desktop Release may not exist when an interactive job begins. Selecting the globally newest existing Release is unsafe; immediately failing when the Release is not yet present is unnecessarily flaky. The correct contract is bounded waiting for a Release whose resolved target SHA equals the workflow source SHA, followed by fail-closed timeout.

## Atomic repair

1. Windows and macOS interactive workflows must search candidate Releases for the required platform asset and resolve every candidate `target_commitish` to a commit SHA.
2. Accept only a Release whose resolved SHA equals `GITHUB_SHA`.
3. Poll for a bounded period so the same-SHA post-main/Release producer can finish.
4. If no exact-source Release appears, fail closed with a source-SHA-specific error. Never fall back to an older Release.
5. Preserve digest/signature checks, recording-before-install, protected-account login, App-owned registration, six semantic tools, complete user journey, final logout, and always-upload evidence.
6. Extend both dependency-free workflow contracts to prevent regression to global-newest selection.

## Acceptance

- Narrow Windows/macOS workflow contract checks pass on the repair PR.
- The PR reaches canonical `main` through required CI and the protected merge queue.
- A subsequent exact-main desktop Release is bound to that protected main SHA.
- Windows/macOS interactive jobs install only Release assets resolving to the same SHA as their workflow source.
- Final Global Dharma and full-platform acceptance remains PENDING until the newest canonical SHA has complete Marketplace -> install -> Bot -> natural-language WebMCP -> Open App same durable revision -> bounded Fabushi auto-login projection -> CNY 1080 sandbox purchase/restore evidence plus whole-session video, step screenshots, trace/report/logs, and successful post-main/Release binding.