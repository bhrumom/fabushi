# Runbook — Store release source gate

## Purpose

Ensure Apple/Google manual store delivery starts only from an exact, protected-main, canonically validated source commit.

## Preconditions

- Requested source resolves to an exact SHA on protected `main` history.
- macOS: `CI result` + `Electron desktop result` successful.
- iOS/Android: `CI result` + `Native mobile result` successful.
- Apple `both`: all three successful.

## Failure response

1. Do not build/sign/upload.
2. Confirm the SHA is on `main`.
3. Inspect the missing/failed exact-SHA check.
4. Repair and revalidate via normal PR/merge queue.
5. Dispatch store delivery again only after the exact SHA is green.

## Rollback

Fix/revert the gate via protected PR. Do not disable branch protection or manually alter check conclusions.

Last validated: 2026-08-22, delivery governance run `32564046827`, PR #1999 merged `3a39dfef0ef30f1e6ae2d53602fa862bf28ddae6`.
