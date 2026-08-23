# FCM-008 — Build latest macOS package

- **Project ID:** FAB-P0003
- **Project Key:** FCM
- **Task ID:** FCM-008
- **Status:** in-progress
- **Started:** 2026-08-23
- **Updated:** 2026-08-23

## Objective

Build the latest canonical Fabushi macOS Electron package from GitHub `main` and provide a downloadable artifact/release link.

## Source requirement

User request: “构建最新的mac版本，把下载链接给我”。

## In scope

- Use canonical GitHub `main` as the build source.
- Use GitHub Actions; do not build locally.
- Run the repository's existing Electron desktop packaging/quality workflow or canonical release workflow.
- Verify the macOS packaging job succeeds.
- Record the exact source SHA, workflow run/job, artifact/release evidence, and download entry point.

## Out of scope

- No product-code changes unless a deterministic build blocker is discovered.
- No TestFlight/App Store upload is implied by this request.

## Acceptance criteria

1. Build source equals the latest canonical `main` SHA at task execution time.
2. GitHub Actions produces a macOS Fabushi package successfully.
3. The package artifact/release is retrievable and a download link is returned to the user.
4. FCM task/WBS/status/changelog/evidence are updated with the verified run facts.

## Current source

- Canonical `main`: `67b70fffa0720fa549fe6c1cc20f1f30bf1a3d2c`.
- Selected build workflow: `.github/workflows/electron-desktop.yml` (manual dispatch packages macOS/Windows/Linux and uploads artifacts after packaged E2E validation).

## Verification method

- GitHub Actions workflow run and job conclusions.
- `actions/runs/<run-id>` metadata.
- Workflow artifact metadata and downloadable artifact/release asset.

## Branch / PR

- Record branch: `chore/fcm-008-build-latest-macos-20260823`.
- Build source remains canonical `main`; this record branch does not change product source.

## Blockers / risks

- None at intake. If CI exposes a deterministic build failure, record it and repair through a governed PR before claiming success.

## Next action

Trigger `Electron desktop quality gate` on `main`, verify the macOS package job, retrieve the artifact, then close this task record with evidence.
