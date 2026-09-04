# MSR P0 requirements — FAB-ARCH-P0-20260904

- Project: `FAB-P0005/MSR`
- Status: architecture baseline; implementation unverified

- `MSR-R-P0-001`: Mahayana CLI/Runtime is the only Bot execution core.
- `MSR-R-P0-002`: one canonical Bot identity maps idempotently to one durable Mahayana session across restart/reinstall/update.
- `MSR-R-P0-003`: direct/group/channel/topic context is scoped inside the same Bot session.
- `MSR-R-P0-004`: device/MiniApp/MCP/WebMCP/App MCP/native capabilities are exposed through one policy/approval/audit catalog.
- `MSR-R-P0-005`: progress/tool/approval/result/error envelopes are typed, correlated, redacted and provider-neutral.
- `MSR-R-P0-006`: upstream capability reuse records exact revision/license/provenance/NOTICE and does not make Codex or Grok Build the product owner.