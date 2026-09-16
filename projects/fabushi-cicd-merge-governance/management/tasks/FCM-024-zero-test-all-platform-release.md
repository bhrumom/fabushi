# FCM-024 — Zero-test automatic control plane and all-platform test release

- Project ID: `FAB-P0003`
- Project Key: `FCM`
- Task ID: `FCM-024`
- Started: `2026-09-16`
- Updated: `2026-09-16`
- Status: `in-progress`

## Objective

Finish the FCM-023 migration by eliminating the remaining automatic product-test/quality/E2E workflows, creating a fast no-behavior-test all-platform prerelease path, and retaining formal acceptance only as manually started Action runner + App-owned device + Fabushi official MCP external control.

## Acceptance

1. Active merge queue uses only the lightweight no-product-test `CI result` as the required test-like status.
2. Automatic E2E/unit/integration/contract/smoke/regression/simulator/emulator/user-journey/quality-test workflows are removed from `.github/workflows` or made non-automatic; release construction/deployment workflows remain.
3. `app-version.json` advancement on protected main triggers macOS/Windows/Linux packaging and immutable GitHub prerelease publication without behavioral tests.
4. The same exact source triggers iOS TestFlight and Android internal-track test builds without behavioral tests.
5. Test-release construction retains exact source/version/package/signing/notarization/checksum/provenance evidence.
6. Formal stable publication is separate and fail-closed until manually started Action-hosted App-owned device(s) are controlled through the Fabushi official MCP for the exact candidate.
7. No workflow-authored autonomous E2E is accepted as formal behavioral evidence.
8. Existing open PRs are merged where GitHub permits; merge-queue/conflict truth is reported without pretending queued PRs are already merged.
9. A strictly newer full-platform test version is published after the accepted PR set and final workflow cleanup reach canonical main.
10. Chrome test/release artifact construction remains available as a zero-test packaging path: exact source -> deterministic ZIP/content manifest/checksums -> immutable Action artifact. It must not install Playwright or run Node test/E2E suites merely to create the package.

## Implementation branch

`project/fcm-024-zero-test-release-20260916`

Follow-up repair branch: `codex/fcm024-chrome-zero-test-package-20260916` restores only the artifact-construction half of the Chrome workflow after the earlier FCM-024 cleanup correctly removed its automated product tests but also unintentionally removed the package artifact needed by downstream publication.

## Current blockers

- Fabushi official MCP account/device calls return a connection-layer HTTP 400. This blocks formal MCP validation and therefore blocks stable publication; it does not block no-test prerelease/package construction.
- Chrome Web Store formal submission remains blocked until the exact candidate has the required official-MCP validation; older autonomous Chrome journey runs are not accepted as substitutes.

## Verification

- GitHub readback of active workflow directory and triggers.
- GitHub protected-main readback after merge.
- GitHub Actions exact-source package artifact with ZIP, content manifest and SHA256SUMS; no behavioral-test step in the Chrome package workflow.
- GitHub Actions run/release evidence for the exact no-test prerelease.
- Fabushi official MCP device/tool/finish evidence before any stable publication.

No local build/test is permitted.