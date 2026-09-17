# 2026-09-06 — M8-WEBMCP-002 Global Dharma Web/service change

- Base: `main@8f7e83902a616ecdb62fdaded65ea79227e745f3`.
- Implementation: `f9a2df5850e81bd5f1fbe3450adf4ec4e3b0f906`.
- Added canonical Global Dharma Tool Contract and removed hand-maintained Marketplace domain command list.
- Replaced process-memory Global Dharma business authority with AccountSyncStore-backed runtime + idempotent operation receipts; business events reuse `as1` sequence/recovery.
- Routed Global Dharma Bot execution through the official MCP handler used by WebMCP.
- Added authenticated runtime/difference/entitlement projections; prayer-wheel Host request is fail-closed unless server entitlement allows exact `local.prayer-wheel.start`.
- Added Web cursor convergence and write operation identity without adding a second event or payment authority.
- Added targeted GitHub Actions evidence workflow; feature-branch production Pages deploy was deliberately not triggered.
- Corrected stale records: #2169 and #2135 are already merged; their old pre-merge wording is no longer treated as a live blocker.
- Remaining: protected PR CI/merge/readback, AAC packaged credential bootstrap, real provider sandbox, and accepted-main packaged video evidence.
