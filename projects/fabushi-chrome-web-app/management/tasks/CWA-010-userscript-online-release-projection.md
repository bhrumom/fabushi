# CWA-010 — Publish userscript v2.9.32 to the online catalog

- Portfolio Project: FAB-P0011; Project Key: CWA; Task ID: CWA-010.
- Status: `IN_PROGRESS / NO_E2E_BY_USER`.
- Started/updated: 2026-09-16. Completed: null.
- Source: `source/2026-09-16-userscript-online-release.md`; user request in the current task.

## Objective

Make the already-published GitHub userscript release `v2.9.32` visible and installable
through the live marketplace update checker. The Worker projection must point to the exact
GitHub main commit, an artifact URL whose raw path contains that commit, byte size, digest,
release URL and publication time.

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
3. `deploymentUrl`, `install.artifacts[0].source.url` and
   `releaseManifest.artifacts[0].source.url` use the public raw GitHub path containing the
   exact declared `sourceRef`; the userscript installer accepts the contract and the raw
   bytes match the declared size and SHA-256.
4. The change is merged through protected `main` and deployed by the existing Worker
   workflow; record the exact merge SHA and workflow/run evidence here.
5. Per the user's explicit instruction, no script/plugin E2E is run or added. This
   exception keeps the task in progress for the normal product-delivery E2E gate; it
   must not be reported as a fully closed product-delivery task.

## Open-source survey and decision

No new runtime or security mechanism is introduced in this release-only change, so no
new dependency is selected. The release follows the existing GitHub immutable-asset
contract already recorded for CWA: source and package remain on GitHub, while the Worker
publishes only pinned metadata and the client verifies the digest before installation.

## Branch / implementation

- Branch: `codex/cwa-010-userscript-url-fix-20260916` (follow-up to
  `codex/cwa-010-publish-userscript-2.9.32`).
- Implementation: keep the existing GitHub `v2.9.32` release metadata and change the
  userscript artifact/deployment URL to the raw URL pinned to `sourceRef`.
- Commit: `a135a79baa9a0280004964e8603112f66b1fd86f` (protected-main merge of PR #2658).
- PR: https://github.com/bhrumom/fabushi/pull/2658.
- Merge queue CI: run `35058079712` (green); Platform Control Plane deployment run
  `35058217234`, deploy job `104673038412` (green).
- Follow-up commit: `b73226835a767d7c903dfb7109e5a352fc57fdb6` (protected-main merge of
  PR #2665); Platform Control Plane run `35063898686`, deploy job `104690001160` (green).

## Evidence, risks and next action

- Lightweight local inspection: `git diff --check` passed; no local build or test.
- CI / deployment: PR #2658 passed the required non-E2E checks; Platform Control Plane
  architecture and production deployment passed in run `35058217234`.
- Live API readback: on 2026-09-16, the catalog endpoint returned `latestVersion=2.9.32`,
  source commit `50569be0ab88909408ed8880a24c185906d760eb`, GitHub Release asset URL,
  size `234862`, SHA-256
  `30ec1f70e0c14a8ebbd530b2cf0186a2d63690bf85e45b8ec8d0e1a81090e9e7`, and
  `releaseStatus=approved`; the live assertion passed.
- The stale `2.9.31` projection is no longer returned. A GitHub Release alone would not
  have changed the catalog; the protected Worker deployment and readback completed that
  link.
- Explicit user constraint: no script/plugin E2E was run or added. The online release is
  verified, but the task remains open for the normal product-delivery E2E gate and is not
  reported as fully closed.
- User-reported install failure: the live `releases/download/v2.9.32/...` URL failed the
  extension's sourceRef path check even though its bytes matched the declared digest.
- Raw source readback before the fix: the commit-pinned URL returned HTTP 200, size `234862`
  and SHA-256 `30ec1f70e0c14a8ebbd530b2cf0186a2d63690bf85e45b8ec8d0e1a81090e9e7`.
- Fix deployment and live contract readback: the catalog returned `latestVersion=2.9.32`,
  `releaseStatus=approved`, and all three userscript URLs equal to
  `https://raw.githubusercontent.com/bhrumom/fabushi-chatgpt-auto-confirm-userscript/50569be0ab88909408ed8880a24c185906d760eb/chatgpt-auto-confirm.user.js`.
  Each URL contains the declared `sourceRef`; no `/releases/download/` URL remains in those
  fields.
- Raw artifact readback: HTTP 200, size `234862`, SHA-256
  `30ec1f70e0c14a8ebbd530b2cf0186a2d63690bf85e45b8ec8d0e1a81090e9e7`; the sourceRef-path,
  metadata and byte-integrity assertion passed.
- Explicit user constraint: no script/plugin E2E was run or added. The online install
  contract is now verified, but the task remains open for the normal product-delivery E2E
  gate and is not reported as fully closed.
- Next: refresh the Marketplace in the client and retry installation; retain the task as
  `IN_PROGRESS / NO_E2E_BY_USER`.
