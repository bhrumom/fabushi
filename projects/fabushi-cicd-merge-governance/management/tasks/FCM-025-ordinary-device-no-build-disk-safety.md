# FCM-025 — Ordinary-device no-build and disk-safety governance

- Project ID: `FAB-P0003`
- Project Key: `FCM`
- Task ID: `FCM-025`
- Started: `2026-09-17`
- Updated: `2026-09-17`
- Status: `passed`

## Objective

Prevent persistent/ordinary devices from being used as build machines so repository work cannot again exhaust a long-lived host such as `bhrum2`. Strengthen root Agent governance so compilation, package construction and disk-growing build caches are moved to GitHub Actions/disposable runners while ordinary devices remain low-footprint control/edit/deployment surfaces.

## Acceptance criteria

1. Root `AGENTS.md` explicitly prohibits compile/build/package/build-producing test activity on ordinary/persistent devices and explicitly covers `bhrum2`.
2. Root policy routes build/package work to GitHub Actions or a user-explicit disposable runner.
3. Root policy prohibits material build/dependency/cache growth (`target`, `node_modules`, Gradle/DerivedData, emulators/simulators, Playwright/browser dependencies, Docker-build layers, compiler/package caches) on ordinary devices.
4. Root policy allows only low-footprint control-plane work plus bounded deployment of already-built artifacts and states that cleanup does not authorize resuming local builds.
5. Source of truth, ADR, risk, WBS, acceptance, status/changelog and evidence index are updated.
6. Required PR/merge-queue checks pass and canonical `main` readback contains the policy.

## Verification method

- No local build/test.
- `git diff --check` and textual canonical readback only on the persistent control host.
- GitHub required CI/portfolio governance and protected merge queue.
- Post-merge `git show origin/main:AGENTS.md` plus canonical project-record readback.

## Implementation

- Branch: `project/fcm-025-ordinary-device-disk-safety-20260917`
- Implementation PR: #2695
- Implementation head: `81766dbdfff81fdf1054735f073649e2b9e88ef6`
- Merge-group CI: run `35198069214` — `success`
- Protected merge commit / canonical main after implementation: `8f06463b5eb7389252d459d28709ab889651aaa6`
- Canonical readback confirmed the complete ordinary-device no-build section in root `AGENTS.md`.
