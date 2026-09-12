# 2026-09-12 — exact-source macOS release dispatch

## User intake

- Request marker: `[Fabushi:e12da10d-edb2-406d-b5fe-a7029e9bf640]`
- Reference URL supplied by the user: `https://mp.weixin.qq.com/s/DEg20nFKfrd2urMc3BjntA`
- Requested outcome: keep pushing Fabushi toward a Shopify-like automated test/iteration loop with GitHub Actions, fast feedback, and real automated verification rather than plan-only work.

The WeChat article URL is preserved as an intake source. Automated retrieval of the article body is not relied on for implementation truth; this task is grounded in the repository's existing FCM architecture, measured CI latency evidence, GitHub Actions behavior, and exact-source release/E2E requirements.

## Existing measured bottleneck

FCM-010.11 measured the real required validation surface and identified `macos-packaged-interactive` as an over-budget lane. FCM-010.10 already added an Action-owned semantic smoke inside the real installed macOS package, but its final acceptance remains blocked until a canonical exact-source interactive run actually starts and produces evidence.

## Diagnosis

Fabushi currently has two canonical macOS Release producers:

1. `Native Electron macOS test release` for the dedicated signed/notarized macOS test Release.
2. `Post-main E2E Release delivery` for the exact-SHA desktop Release after desktop + Android + iOS gates pass.

Both publish Releases from GitHub Actions using the workflow token. The interactive macOS workflow also has `release: published`, but a workflow-token-created Release cannot be treated as a reliable recursive trigger for the next workflow. The repository already had a `workflow_run -> workflow_dispatch` bridge for the dedicated macOS release workflow, proving the intended control-plane pattern, but it dispatched `macos-interactive-app-e2e.yml` with `--ref main`.

Using moving `main` breaks exact-source provenance when main advances between Release publication and interactive dispatch: the interactive workflow binds `GITHUB_SHA`, Release target, installed package, and uploaded evidence, so dispatch must use an immutable ref whose commit is exactly the published Release source SHA.

The bridge also did not listen to `Post-main E2E Release delivery`, leaving the canonical desktop Release path dependent on the unreliable recursive `release` event.

## Atomic correction

- Keep the existing installed-App interactive lane and its App-owned registration/truth gates unchanged.
- Make the bridge listen to both canonical Release-producing workflows.
- Take the upstream `workflow_run.head_sha` as the required source SHA.
- Resolve a published Release whose `target_commitish` equals that exact SHA and that contains an installable macOS ZIP.
- Verify the resolved Release tag dereferences to the exact source SHA.
- Dispatch the existing interactive workflow with `--ref <release-tag>`, never `--ref main`.
- Suppress a duplicate dispatch when an exact-source interactive run is already active or has already succeeded.
- Keep an explicit manual replay entrypoint that requires the exact source SHA.
- Lock these invariants into the required lightweight `CI result` contract suite.

## Acceptance boundary

Static YAML and unit/contract checks prove only the control-plane intent. Completion requires protected merge, canonical readback, and a canonical main Release path that automatically produces an exact-source `macOS interactive app device E2E` run whose Action-owned packaged-App smoke succeeds against the installed application.