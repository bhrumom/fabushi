# 2026-09-07 — desktop interactive Host trigger coverage

- Project: `FAB-P0001 / TFI`
- Baseline: protected canonical `main@89922b7907d80d0840da5f394444a4affcbe45f4`
- Triggering change already protected-merged: PR #2473 / `89922b79...` fixed the Windows App-owned bounded CI session validator inside `third_party/mahayana/mahayana-rs/mahayana-product/src/lib.rs`.

## User requirement carried forward

Final acceptance must be proven only on the final protected canonical SHA with a same-SHA Release plus Windows/macOS packaged interactive evidence, including full-session video, meaningful screenshots, trace/report/logs, and the Global Dharma Mini App journey: Marketplace search/install, Bot, Open App Web UI, natural-language WebMCP, Bot/UI same revision, bounded Fabushi auto-login, and sandbox CNY 1080 lifetime purchase/restore. Older SHA evidence is diagnostic only.

## Deterministic delivery gap

The Windows and macOS interactive workflows are path-filtered on their workflow files, Electron App Agent files, Playwright App Agent evidence, and `chatgpt-vps-control` helpers. They do **not** include the embedded Mahayana product/Host crates that determine account-session validation, Host startup, and App-owned device registration.

Consequently the protected Windows Host fix at `89922b79...` correctly triggers Electron/native/security work, but it does not trigger either desktop interactive workflow. Waiting cannot produce the required same-SHA packaged external-control evidence, and using the prior `2bfa...` / `74f9...` runs would violate current-SHA acceptance.

## Smallest repair boundary

1. Add the embedded `mahayana-product/**` and `mahayana-app-host/**` paths to both Windows and macOS interactive push filters.
2. Extend each dependency-free workflow contract to assert those paths remain part of the trigger set.
3. Do not change any runtime behavior, account policy, device registration semantics, release selection, signing, recording, semantic-tool, logout, or evidence gates.
4. Rely on the resulting protected-main push to start both desktop interactive workflows from the exact new canonical SHA. They may wait for that SHA's Release, but must never fall back to an older package.

## Open-source-first startup gate

This is native GitHub Actions path-filter configuration, not a missing implementation or reusable runtime component. No third-party dependency is appropriate. We reuse the repository's existing narrow `paths:` model and its dependency-free Node workflow-contract tests; no upstream code, package, or protocol is introduced.

## Acceptance

- Windows and macOS contracts explicitly require both embedded Host/product path families.
- Required PR GitHub Actions pass; no local build/test.
- Protected merge only and canonical main is read back.
- The resulting main push creates Windows and macOS interactive runs from the same exact SHA.
- Final closure remains PENDING until the new canonical SHA has terminal Electron/native/post-main/Release and both desktop interactive evidence artifacts, and Global Dharma visual/trace/report/log evidence passes without relying on historical SHA artifacts.
