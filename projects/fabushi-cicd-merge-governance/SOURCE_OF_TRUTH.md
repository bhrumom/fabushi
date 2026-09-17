# Source of Truth

Canonical project record: `bhrumom/fabushi` `main` → `projects/fabushi-cicd-merge-governance/`.

## Requirement sources

- `source/README.md` preserves the original CI/CD and merge-governance requirement and diagnosed cause.
- `source/2026-08-24-main-e2e-release-open-source-first.md` records the historical requirement for open-source-first startup, warm/incremental build/test, per-main packaged simulated-user E2E and E2E-gated Release publication.
- `source/2026-08-24-updater-proof-optional-clarification.md` made the previous-installed-App updater journey optional/non-blocking by default.
- `source/2026-09-16-test-first-mcp-only-formal-release.md` historically replaced automatic/E2E-gated formal acceptance with external Fabushi official MCP validation.
- `source/2026-09-16-zero-test-all-platform-prerelease.md` then removed behavioral-test gates from test/prerelease construction while keeping MCP-driven formal acceptance.
- `source/2026-09-17-ordinary-device-no-build-disk-safety.md` strengthened resource safety: ordinary/persistent devices are not build surfaces.
- **`source/2026-09-18-user-directed-test-and-release-authority.md` is the latest explicit requirement and supersedes all conflicting mandatory MCP/E2E release gates.** Behavioral/product testing now runs only when the user explicitly requests testing. If the user explicitly authorizes publication, publication must not be blocked by an unrequested MCP/E2E/behavioral-test gate.

## Current release/test authority

1. The latest explicit user instruction controls test/release sequencing for the current task/candidate.
2. Behavioral/product testing is opt-in: run MCP, E2E, smoke, regression, simulator/emulator, packaged-app journeys, or equivalent behavioral validation only when the user explicitly asks to test.
3. Fabushi official MCP is an available test/control surface, not a mandatory formal-release gate unless the user explicitly requests MCP-based testing.
4. When the user explicitly says the candidate may be published / asks to publish, proceed once required non-behavioral release-construction and platform constraints are satisfied; do not invent an additional behavioral-test prerequisite.
5. Automatic product-test/quality/E2E workflows remain disabled by default unless a later explicit user requirement enables that exact test behavior.
6. Do not silently substitute another behavioral suite when testing was not requested.
7. Source identity, version monotonicity where required, build/sign/package/notarization, artifact integrity/provenance, protected-branch rules, credentials/permissions, security controls, and store/platform acceptance requirements remain mandatory where applicable because they are not behavioral tests.
8. Release evidence must state truthfully whether behavioral testing was requested and run. No MCP/E2E evidence is required when the user did not request that testing.
9. Existing work blocked only on the old mandatory MCP gate must be reevaluated under this authority; missing MCP evidence alone is no longer a release blocker.

## Ordinary-device resource-safety authority

1. Persistent developer machines, VPS/server hosts, production/service/MCP hosts and other non-disposable machines are control/edit/deploy surfaces only, not compiler/build/package surfaces.
2. Build, package, build-producing test, dependency-install/cache-warming, browser/E2E dependency and Docker image construction belongs on GitHub Actions or an explicitly designated disposable runner.
3. Low-space recovery must not be followed by local build/cache recreation; dispatch the build to Actions instead.
4. Deployment of already-built immutable artifacts is permitted when bounded, space-aware and rollback-safe.

## Precedence

1. Latest explicit user requirement once persisted here; currently `source/2026-09-18-user-directed-test-and-release-authority.md`.
2. This file and designated dated sources under `source/`; later explicit sources supersede only conflicting earlier rules.
3. Accepted ADRs and current CI/CD model docs that do not conflict with the latest source.
4. WBS, acceptance matrix, status, risk and task records.
5. Actual GitHub workflow files, rules/check results, PRs, Releases and deployment evidence for implementation facts.
6. Conversation memory.

No workflow is considered compliant merely because documentation says so; actual triggers, release behavior, and truthful evidence remain authoritative.