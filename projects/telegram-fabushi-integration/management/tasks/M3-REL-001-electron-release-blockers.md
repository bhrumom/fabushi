# M3-REL-001 — Electron release blockers

- **Project ID:** FAB-P0001
- **Project Key:** TFI
- **Task ID:** M3-REL-001
- **Status:** in-progress
- **Started:** 2026-08-23
- **Updated:** 2026-08-23

## Objective

Remove the deterministic Messenger regressions blocking the latest canonical macOS Electron package.

## Source / trigger

FCM-008 manual `Electron desktop quality gate` run `32619314508` on canonical main `67b70fffa0720fa549fe6c1cc20f1f30bf1a3d2c` failed the real Electron Messenger smoke before packaging.

## In scope

1. Restore strict authenticated-actor binding at the desktop messaging Host boundary so renderer-supplied envelope actor IDs cannot impersonate another actor.
2. Ensure one committed legacy chat message is projected once in the desktop message list/search even when runtime events/refetches overlap.
3. Preserve legitimate repeated messages with identical text; deduplication must use stable message identity/event causality, not text-only suppression.
4. Run Messaging Product Gate / Electron desktop E2E and merge through protected main.

## Acceptance criteria

- Forged `upsertProfile` using an envelope actor ID different from the authenticated desktop messaging identity is rejected with the Host authorization error.
- `desktop Messenger persists per-peer drafts and performs real in-conversation search` returns exactly one article for its unique sent marker on initial run and retry.
- Existing navigation, mutation, group, Mini App and messaging authorization tests remain green.
- Fix lands on canonical `main` before FCM-008 rebuild is retriggered.

## Evidence

- Failing run: `32619314508`.
- Failure artifact: `electron-runtime-smoke-failure-32619314508-1`.
- Product code: `desktop/electron/main.cjs`, `desktop/src/messaging-shell-v2.tsx`, messaging Host/bridge as required.
- E2E: `desktop/e2e/messenger.spec.ts`.

## Branch

`fix/tfi-m3-release-blockers-20260823`

## Next action

Trace the desktop identity boundary and legacy chat event identity, implement the narrow fixes, then validate through GitHub Actions.
