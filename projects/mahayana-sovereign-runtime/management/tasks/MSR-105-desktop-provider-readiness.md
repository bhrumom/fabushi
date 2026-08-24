# MSR-105 — Desktop provider readiness and managed workspace bootstrap

- **Project ID:** FAB-P0005
- **Project Key:** MSR
- **Task ID:** MSR-105
- **Status:** in-progress
- **Started:** 2026-08-24T08:11:00+08:00
- **Updated:** 2026-08-24T08:14:00+08:00
- **Completed:** null

## Objective
Eliminate the desktop Mahayana first-message failure that surfaced as `provider failed: backend failed: No such file or directory (os error 2)` by making product-owned runtime prerequisites explicit and deterministic before the provider is allowed to serve requests.

## Reference implementation review
Cloudflare OS was reviewed as an architecture reference. Its AI backend centralizes model/provider routing behind typed handles and keeps routing/auth details out of callers. Fabushi should adopt the same class of boundary: initialize and validate runtime-owned prerequisites once at the host boundary, keep provider internals behind product-owned contracts, and surface deterministic failures instead of raw operating-system errors. Cloudflare OS is service/Workers oriented, so its implementation is a design reference rather than a literal Electron sidecar template.

## Root cause
The desktop app host configures the native runtime data directory under `feature-host/runtime`. When no explicit workspace is selected, `mahayana-host` derives the product-owned fallback workspace as `feature-host/runtime/workspace`. The first native Agent session canonicalizes that path. A fresh app-data directory did not create the fallback workspace before the first message, so path canonicalization returned OS error 2 and the error propagated through the Agent/provider layers to the conversation UI.

## In scope
- Create the product-owned desktop fallback workspace before `UnifiedAppHost` initialization.
- Never create arbitrary user-selected workspace paths implicitly.
- Add a deterministic regression test for the managed runtime layout.
- Verify the exact branch through CI before merge.
- Record PR, CI, merge and canonical-main evidence before task closure.

## Out of scope
- Retrying filesystem/configuration errors as if they were transient provider failures.
- Silently falling back to a test backend.
- Creating missing user-selected workspaces.
- Changing model credentials or provider routing.

## Acceptance criteria
1. A fresh desktop app-data directory creates `feature-host/runtime/workspace` before the native host starts.
2. The first native Agent session no longer fails because the product-owned fallback workspace is absent.
3. User-selected workspaces remain explicit inputs and are not auto-created by this bootstrap.
4. Regression coverage runs in CI.
5. The change is merged only after required checks pass and canonical `main` is verified.

## Verification
`cargo test -p mahayana-app-host-desktop --profile ci` plus repository fast checks on the exact PR head. Release/E2E packaging remains governed by the repository merge-to-main pipeline.

## Branch / commit / PR
Branch: `fix/msr-105-desktop-provider-readiness`
Initial implementation commit: `4936c3c65869be9cbfc4411368115a0e06cddfaf`
PR: #2081

## Implementation summary
Desktop startup now explicitly creates the runtime-owned fallback workspace before constructing `UnifiedAppHost`. The bootstrap is intentionally limited to the application-owned runtime path. This moves filesystem readiness to the lifecycle boundary instead of allowing an OS-level `ENOENT` to escape during the user's first chat request.

## Evidence
PR #2081 is open and mergeable. Exact-head CI had not yet appeared at the first post-PR status read; merge remains blocked until required checks complete.

## Next action
Run required CI on the exact #2081 head, inspect any failures, and merge only after the branch is green.
