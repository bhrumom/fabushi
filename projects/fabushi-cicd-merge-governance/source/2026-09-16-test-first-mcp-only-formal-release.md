# 2026-09-16 — Test-first publication and MCP-only formal release validation

Project: `FAB-P0003 / FCM`

## Latest explicit requirement

The release/test policy is changed as follows:

1. Merge accepted work quickly and publish a new all-platform **test/beta** build first.
2. Before a test/beta/prerelease is published, **do not run product tests**. No unit, integration, simulator, emulator, Playwright, packaged-app E2E, smoke, regression, or other behavioral test may gate that test release. Build, sign, notarize, package, checksum, source-provenance and protected-main ancestry checks remain allowed because they construct/identify the artifact rather than test product behavior.
3. Disable automatic E2E and other long-running test flows. E2E may only be started manually when explicitly necessary.
4. Formal/stable release behavioral verification is performed only through the **Fabushi official MCP** against GitHub Actions-hosted runner devices. The Action installs/launches the exact candidate App; the installed App must self-register its own account-scoped controllable device. The ChatGPT-side agent then uses the Fabushi official MCP to discover and operate that App/device as a user.
5. A workflow must not substitute a self-authored/autonomous simulated-user E2E for that MCP-driven formal validation.
6. Formal/stable release is blocked unless the exact candidate passes the required MCP-driven runner/device validation. If the MCP account connection is unavailable, the device never appears, control cannot be exercised, or a required journey fails, the formal release remains blocked.
7. Test-release evidence is source/version/artifact/signing/provenance evidence with deliberately **no behavioral-test requirement**. Formal-release evidence additionally includes Action run/job, App-owned device identity, MCP operation trace, screenshots/video/logs where supported, final notes/finish signal, and pass/fail result.
8. The intended order is: accepted merges -> exact-main all-platform test release without tests -> manually start platform runner(s) only for formal candidate -> App self-registers -> Fabushi official MCP drives verification -> stable release.

## Supersession

This source supersedes older FCM requirements only where they require automatic/post-main E2E, E2E-gated test publication, release-event-triggered E2E, or autonomous workflow-driven behavioral testing. It does not remove project governance, protected-main provenance, signing/notarization, package integrity, source identity, version monotonicity, security controls, rollback requirements, or the local-disk prohibition.

Older E2E workflows may remain in history for diagnostics, but automatic triggers must be removed/disabled and they are not release authority under this policy.