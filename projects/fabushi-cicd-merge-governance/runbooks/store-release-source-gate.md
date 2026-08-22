# Runbook — Store release source gate

## Purpose

Ensure Apple/Google manual store delivery starts only from an exact, protected-main, canonically validated source commit.

## Preconditions

- Requested source ref resolves to an exact SHA.
- Source commit is on protected `main` history.
- macOS: `CI result` and `Electron desktop result` are successful for the SHA.
- iOS/Android: `CI result` and `Native mobile result` are successful for the SHA.
- Apple `both`: all three checks are successful.

## Failure response

1. Do not build/sign/upload when the gate fails.
2. Confirm whether the SHA is actually on `main`.
3. Inspect the missing/failed check on that exact SHA.
4. Repair and revalidate the code through normal PR/merge queue.
5. Dispatch store delivery again only after the exact SHA has the required successful gates.

## Rollback

If the gate implementation itself is broken, fix/revert it through a protected PR. Do not disable branch protection or manually alter check conclusions.

Last validated: pending PR #1999 acceptance.
