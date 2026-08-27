# M2-SYNC-002 CI sparse-checkout blocker — 2026-08-27

PR #2164 introduced a product UI guard that verifies the Marketplace producer (`ai-backend/src/miniapp_marketplace_catalog.js`) and Messenger consumer (`desktop/src/miniapp-bot-projection.ts`) remain aligned for top-level Mini App `bot`/`commands` metadata.

The full Electron quality gate and Host fast E2E passed, but the general CI `Product/backend/UI guardrails` job initially failed with `FileNotFoundError` because its sparse checkout did not include those two source files. This was a CI input-coverage defect, not a product-code failure.

Repair commit `6ba76927447fe3a3ffb3b2f7b040cc16d4468650` added exactly those two paths to the `Checkout Electron Feature Host bridge inputs` sparse checkout in `.github/workflows/ci.yml` and removed the temporary one-shot apply workflow. The next user-authored current-head run must prove the same guard succeeds under general CI as well as the Electron quality gate before #2164 is eligible for merge.
