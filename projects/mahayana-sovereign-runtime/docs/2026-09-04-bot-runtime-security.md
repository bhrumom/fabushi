# MSR P0 security — FAB-ARCH-P0-20260904

- Bot identity alone grants no device or MiniApp mutation authority.
- Account identity, device presence, pairing, control enablement, session/generation and per-tool policy are distinct gates.
- MiniApp/provider schemas are admitted before model exposure; unknown/uninstalled/revoked/stale providers fail closed.
- Sensitive input follows existing secure-input/approval channels; secrets, tokens, cookies and hidden values are excluded from capability inventory and chat result envelopes.
- Duplicate/replayed invocation IDs cannot produce unintended repeated mutations.
- Upstream Apache-2.0 adaptations preserve required notices/provenance and remain behind Fabushi-owned interfaces.