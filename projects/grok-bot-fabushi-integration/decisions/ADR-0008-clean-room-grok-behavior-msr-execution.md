# ADR-0008 — clean-room Grok-like behavior; MSR remains execution owner

- Project: `FAB-P0004/GBF`
- Program: `FAB-ARCH-P0-20260904`
- Status: Proposed for protected-main review

## Decision

Use observable Grok Bot behavior only as clean-room reference for group invocation/privacy/progress/tool-result interaction. `bhrum/grok-bot-0.18-reconstructed@107877b4e2134fd167d239411386f09e42eadd6d` has no root LICENSE and its provenance warns no upstream source license is implied, so no implementation code is copied.

GBF specifies behavior/device capability semantics. All execution and durable sessions remain FAB-P0005/MSR; messaging transport remains FAB-P0001/TFI.