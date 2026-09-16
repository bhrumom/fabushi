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

## Implementation branch

`project/fcm-024-zero-test-release-20260916`

## Current blockers

- Fabushi official MCP account/device calls return a connection-layer HTTP 400. This blocks formal MCP validation and therefore blocks stable publication; it does not block no-test prerelease construction.
- Protected main merge queue is serial and is still consuming the previously opened/authorized PR set. Final workflow cleanup must be rebound to the then-current canonical main so older PRs cannot reintroduce test workflows.

## Verification

- GitHub readback of active workflow directory and triggers.
- GitHub protected-main readback after merge.
- GitHub Actions run/release evidence for the exact no-test prerelease.
- Fabushi official MCP device/tool/finish evidence before any stable publication.

No local build/test is permitted.