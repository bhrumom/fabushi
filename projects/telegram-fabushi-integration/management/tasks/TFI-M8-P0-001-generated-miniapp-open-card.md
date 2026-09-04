# TFI-M8-P0-001 — generated MiniApp message card

- **Project ID / Key:** `FAB-P0001 / TFI`
- **Task ID:** `TFI-M8-P0-001`
- **Program:** `FAB-ARCH-P0-20260904`
- **Status:** `NOT_STARTED`
- **Owner:** Execution project group
- **Current dependencies:** none
- **Parallel condition:** yes, provided no overlap with `desktop/src/messaging-shell-v2.tsx` work from M3 without an explicit merge plan.

## Objective
When Bot/Mahayana generation finishes, render a typed directly actionable MiniApp card in chat instead of source/code-only output.

## Exact implementation scope
- `ai-backend/src/miniapp_marketplace.js`: existing `mahayana.miniapp.generation.v1` producer; first read actual current event fields.
- existing Marketplace catalog/release manifest and `InstallMiniApp`/`marketplace.install`/`miniapp.open` contracts reached from current main; do not invent a second manifest.
- `frontend/apps/web/src/lib/mahayana-host/contracts.ts`: versioned serializable card payload boundary if needed.
- `desktop/src/messaging-shell-v2.tsx`: renderer consumer/action UI.
- existing MiniApp/Marketplace renderer/Host tests and packaged E2E fixtures.

## Implementation steps
1. Capture the exact current producer and install/open field schema on the implementation head and write the mapping into this task before modifying consumers.
2. Define one versioned card payload containing stable MiniApp identity and references to canonical catalog/release metadata; no package bytes/arbitrary executable URL.
3. Installed action opens the canonical installed MiniApp; uninstalled action calls the existing validated install path then opens on success.
4. Make failure visible/retryable and reject yanked/rejected/invalid/digest-mismatch metadata.
5. Render all card fields as data; no executable HTML/JS injection.
6. Add producer/consumer/render/action tests and packaged generation-result -> card -> open/install journey.

## In scope
Generation event adaptation, typed message card, install/open action, validation and UI evidence.

## Out of scope
Creating the Bot/session projection (M8-002), new Marketplace authority, arbitrary URL launch, group Bot capability routing, local build/test.

## Acceptance by category
- **Unit:** card parsing/state/action reducer for installed/uninstalled/invalid/yanked/digest mismatch.
- **Contract:** `mahayana.miniapp.generation.v1` producer fields map exactly to versioned card and canonical manifest/release references; unknown required fields fail visibly.
- **Integration:** generation producer -> Host contract -> desktop message renderer -> existing install/open APIs.
- **E2E:** exact-main installable package proves generation result renders a card and installed opens directly; uninstalled performs validated install then open; failure is visible/retryable.
- **Security:** arbitrary URL/script/HTML, rejected/yanked item, manifest/digest mismatch cannot execute/open; renderer escapes data.
- **Performance:** card rendering/install lookup introduces no blocking network wait before message paint; record generation-to-card paint timing in packaged evidence.

## Required write-back and evidence
Record actual producer field mapping, branch/commit/PR/review/CI workflow-run-job/check/evidence/status/changelog here and TFI P0 records. No planned=passed.

Post-main closure requires exact main SHA, app version, platform, run/job, journey ID, timestamp, installable artifact, full video, step screenshots, trace, HTML/native report and logs; pass/fail always-equivalent upload; 90-day target or recorded lower maximum. Missing evidence blocks pass.

## Execution fields
Branch: `pending`; Commit: `pending`; PR: `pending`; CI: `pending`; Evidence: `pending`; Review: `pending`; Canonical-main/package/release: `pending`.
