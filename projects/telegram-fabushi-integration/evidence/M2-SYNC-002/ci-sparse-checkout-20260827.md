# M2-SYNC-002 CI sparse-checkout blocker — 2026-08-27

PR #2164 introduced a product UI guard that verifies the Marketplace producer (`ai-backend/src/miniapp_marketplace_catalog.js`) and Messenger consumer (`desktop/src/miniapp-bot-projection.ts`) remain aligned for top-level Mini App `bot`/`commands` metadata.

The full Electron quality gate and Host fast E2E passed, but the general CI `Product/backend/UI guardrails` job failed with `FileNotFoundError` because its sparse checkout did not include those two source files. This is a CI input-coverage defect, not a product-code failure.

Required repair: add both source paths to the `Checkout Electron Feature Host bridge inputs` sparse checkout in `.github/workflows/ci.yml`, then rerun the same guard under CI. The temporary apply workflow on this branch must remove itself after committing the repair.
