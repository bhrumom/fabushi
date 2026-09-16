# Source of Truth

Canonical project record: `bhrumom/fabushi` `main` → `projects/fabushi-cicd-merge-governance/`.

## Requirement sources

- `source/README.md` preserves the original CI/CD and merge-governance requirement and diagnosed cause.
- `source/2026-08-24-main-e2e-release-open-source-first.md` records the historical requirement for open-source-first startup, warm/incremental build/test, per-main packaged simulated-user E2E and E2E-gated Release publication.
- `source/2026-08-24-updater-proof-optional-clarification.md` made the previous-installed-App updater journey optional/non-blocking by default.
- **`source/2026-09-16-test-first-mcp-only-formal-release.md` is the latest explicit requirement and supersedes conflicting historical E2E/release-test rules.** Test/beta/prerelease publication has no behavioral-test gate; automatic E2E/long-running test flows are disabled/manual-only; formal/stable behavioral acceptance is driven from ChatGPT through the Fabushi official MCP against Action-hosted App-owned devices after the test release exists.

## Current release/test authority

1. Merge/protected-main provenance, source identity, version monotonicity, signing/notarization, package integrity and security controls remain mandatory.
2. Test/beta/prerelease construction and publication must not run or require product behavioral tests.
3. Automatic post-main/release-triggered E2E is not release authority and must remain disabled/manual-only.
4. For a formal/stable candidate, GitHub Actions provides the runner/device and installs/launches the exact candidate App; the App self-registers its own controllable device; the Fabushi official MCP is the external test driver.
5. Missing/unavailable MCP connectivity, missing App-owned device, failed external control, or failed required journey blocks the formal release. Do not substitute another SHA, an autonomous workflow E2E, or an older run.

## Precedence

1. Latest explicit user requirement once persisted here; currently the 2026-09-16 source above.
2. This file and designated dated sources under `source/`; later explicit sources supersede only conflicting earlier rules.
3. Accepted ADRs and current CI/CD model docs that do not conflict with the latest source.
4. WBS, acceptance matrix, status, risk and task records.
5. Actual GitHub workflow files, rules/check results, PRs, Releases and MCP/runner evidence for implementation facts.
6. Conversation memory.

No workflow is considered compliant merely because documentation says so; actual trigger configuration and actual release evidence remain authoritative.