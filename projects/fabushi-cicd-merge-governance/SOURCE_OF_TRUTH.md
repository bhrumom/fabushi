# Source of Truth

Canonical project record: `bhrumom/fabushi` `main` → `projects/fabushi-cicd-merge-governance/`.

## Requirement sources

- `source/README.md` preserves the original CI/CD and merge-governance requirement and diagnosed cause.
- `source/2026-08-24-main-e2e-release-open-source-first.md` records the historical requirement for open-source-first startup, warm/incremental build/test, per-main packaged simulated-user E2E and E2E-gated Release publication.
- `source/2026-08-24-updater-proof-optional-clarification.md` made the previous-installed-App updater journey optional/non-blocking by default.
- `source/2026-09-16-test-first-mcp-only-formal-release.md` superseded historical automatic/E2E-gated release behavior: test publication has no behavioral-test gate and formal acceptance is external through the Fabushi official MCP.
- **`source/2026-09-16-zero-test-all-platform-prerelease.md` is the latest explicit refinement.** Before test publication, automatic workflows are limited to the no-test merge status and artifact construction/distribution. Automatic unit/integration/contract/smoke/E2E/regression/simulator/emulator/user-journey/quality-test flows are disabled. A newer exact-main version publishes macOS/Windows/Linux test packages plus iOS TestFlight and Android internal builds without behavioral tests. Formal acceptance remains MCP-driven on manually started App-owned Action devices.
- `source/2026-09-17-ordinary-device-no-build-disk-safety.md` is the latest explicit resource-safety refinement: ordinary/persistent devices (including `bhrum2`) are never build surfaces; compilation/package/cache-heavy work belongs on GitHub Actions or a user-designated disposable runner. This strengthens local-disk safety without changing the release/test authority above.

## Current release/test authority

1. Merge/protected-main provenance, source identity, version monotonicity, signing/notarization, package integrity and security controls remain mandatory.
2. Test/beta/prerelease construction and publication must not run or require product behavioral tests.
3. Automatic product-test/quality/E2E workflows are not release authority and must remain disabled; historical implementations may be retained only outside the active workflow directory or as later explicitly requested manual diagnostics.
4. For a formal/stable candidate, GitHub Actions provides a manually started runner/device and installs/launches the exact candidate App; the App self-registers its own controllable device; the Fabushi official MCP is the external test driver.
5. The runner may provision/install/launch/record evidence, but must not substitute an autonomous simulated-user acceptance journey for MCP control.
6. Missing/unavailable MCP connectivity, missing App-owned device, failed external control, or failed required journey blocks formal publication. Do not substitute another SHA, an autonomous workflow E2E, or an older run.


## Ordinary-device resource-safety authority

1. Persistent developer machines, VPS/server hosts, production/service/MCP hosts and other non-disposable machines are control/edit/deploy surfaces only, not compiler/build/package surfaces.
2. Build, package, build-producing test, dependency-install/cache-warming, browser/E2E dependency and Docker image construction belongs on GitHub Actions or an explicitly designated disposable runner.
3. Low-space recovery must not be followed by local build/cache recreation; dispatch the build to Actions instead.
4. Deployment of already-built immutable artifacts is permitted when bounded, space-aware and rollback-safe.

## Precedence

1. Latest explicit user requirement once persisted here; currently `source/2026-09-16-zero-test-all-platform-prerelease.md`.
2. This file and designated dated sources under `source/`; later explicit sources supersede only conflicting earlier rules.
3. Accepted ADRs and current CI/CD model docs that do not conflict with the latest source.
4. WBS, acceptance matrix, status, risk and task records.
5. Actual GitHub workflow files, rules/check results, PRs, Releases and MCP/runner evidence for implementation facts.
6. Conversation memory.

No workflow is considered compliant merely because documentation says so; actual triggers and actual release/MCP evidence remain authoritative.