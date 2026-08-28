# Mahayana Design & Artifact Engine

- Project ID: `FAB-P0009`
- Project Key: `MDA`
- Status: active

## Objective
Fuse the reusable strengths of `nexu-io/open-design` into Fabushi without creating a second agent runtime: design-system packages, design skills/templates, craft guidance, runtime-adapter declarations, isolated skill staging, artifact preview/export contracts, and MiniApp-oriented delivery flow become Mahayana-owned capabilities.

## Current verified status
Project initialized from canonical `main`; implementation proceeds on `feat/fab-p0009-mahayana-design-artifact-engine`. Upstream audit baseline is pinned to `nexu-io/open-design@35edb37d60c8ec73e34174f1608f8833f461f8b4` (Apache-2.0).

## Architecture rule
Mahayana remains the sole executor/kernel. Existing Messenger/Agent Workbench remains the user-facing execution surface. OpenDesign daemon/UI is not embedded as a second product runtime.

## Next gate
Land MDA-101 through MDA-701 with objective contract/unit/E2E evidence, merge protected `main`, then run the repository post-main delivery gates required by `AGENTS.md`.

See `SOURCE_OF_TRUTH.md`, `docs/03-架构与实现策略.md`, and `management/01-WBS原子任务.md`.
