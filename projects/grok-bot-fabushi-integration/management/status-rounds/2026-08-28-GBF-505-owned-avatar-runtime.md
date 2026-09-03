# GBF-505 status round — 2026-08-28

## Completed this round

- Reopened GBF-505 on current canonical `main` because the production BotMark path still depended on a vendored OpenMaus `CursorAvatar` implementation.
- Added a Fabushi-owned procedural SVG avatar runtime.
- Rewired BotMark to the Fabushi-owned runtime and removed the vendored OpenMaus source file.
- Reversed the BotMark CI guard from requiring the upstream implementation to rejecting any upstream avatar/renderer runtime dependency.
- Persisted the new user requirement and updated task/evidence records.

## Acceptance state

Implementation: complete on branch.

Verification/delivery: pending PR CI, protected-main merge, canonical-main packaged E2E visual evidence, and Release proof.

## Blockers

No code blocker known before CI. The task must not be marked complete until repository delivery gates pass.

## Next action

Open PR, run required CI, fix any failures, merge through protected main, then verify the exact merged SHA through packaged Electron E2E and Release evidence.
