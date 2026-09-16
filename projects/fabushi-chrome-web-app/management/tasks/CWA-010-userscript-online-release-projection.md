# CWA-010 — Publish userscript v2.9.32 to the online catalog

- Portfolio Project: FAB-P0011; Project Key: CWA; Task ID: CWA-010.
- Status: `IN_PROGRESS / DEPLOYMENT_PENDING`.
- Started/updated: 2026-09-16. Completed: null.
- Source: `source/2026-09-16-userscript-online-release.md`; user request in the current task.

## Objective

Make the already-published GitHub userscript release `v2.9.32` visible to the live
marketplace update checker. The Worker projection must point to the exact GitHub main
commit, immutable release asset, byte size, digest, release URL and publication time.

## Scope

In scope: the Chrome userscript catalog projection, project/release records, protected
main merge, the existing Platform Control Plane deployment workflow, and a read-only
live API readback. Out of scope: changing userscript source, creating a second GitHub
Release, the self-hosted CWA-009 admission implementation, Chrome Web Store review, and
all script/plugin E2E runs.

## Dependencies

- GitHub Release `v2.9.32` in `bhrumom/fabushi-chatgpt-auto-confirm-userscript`.
- Protected `main` and the existing Platform Control Plane deployment credentials.
- The client update checker already deployed on `main`.

## Acceptance criteria and verification

1. The live `GET https://api.ombhrum.com/v1/marketplace/plugins?q=chatgpt-auto-confirm&platform=chrome-extension`
   response returns `latestVersion=2.9.32`, the exact source commit
   `50569be0ab88909408ed8880a24c185906d760eb`, the GitHub Release asset, size `234862`,
   and SHA-256 `30ec1f70e0c14a8ebbd530b2cf0186a2d63690bf85e45b8ec8d0e1a81090e9e7`.
2. The response no longer advertises the stale `2.9.31` projection for this plugin.
3. The change is merged through protected `main` and deployed by the existing Worker
   workflow; record the exact merge SHA and workflow/run evidence here.
4. Per the user's explicit instruction, no script/plugin E2E is run or added. This
   exception keeps the task in progress for the normal product-delivery E2E gate; it
   must not be reported as a fully closed product-delivery task.

## Open-source survey and decision

No new runtime or security mechanism is introduced in this release-only change, so no
new dependency is selected. The release follows the existing GitHub immutable-asset
contract already recorded for CWA: source and package remain on GitHub, while the Worker
publishes only pinned metadata and the client verifies the digest before installation.

## Branch / implementation

- Branch: `codex/cwa-010-publish-userscript-2.9.32`.
- Implementation: update the Worker userscript projection constants to the existing
  GitHub `v2.9.32` release and asset digest.
- Commit / PR / deployment: pending.

## Evidence, risks and next action

- Lightweight local inspection: pending after the patch; no local build or test.
- CI / deployment / live API evidence: pending.
- Risk: a successful GitHub Release alone does not change the Worker catalog; the
  protected main deployment and API readback are required for client detection.
- Next: run lightweight checks, push the branch, open/merge the protected PR, wait for
  the Worker deployment, then read the live catalog and append exact evidence.
