# TFI P0 requirements addendum — 2026-09-04

- Project: `FAB-P0001/TFI`
- Program: `FAB-ARCH-P0-20260904`
- Status: architecture baseline; implementation unverified

## P0 requirements

- `TFI-R-P0-001`: complete cached Messenger content must be renderable before Host/network reconciliation; no minute-scale completeness delay.
- `TFI-R-P0-002`: local projection remains display-only; Rust/Host stays canonical and reconciles without blanking valid cached content on transient failure.
- `TFI-R-P0-003`: MiniApp generation produces a typed message-card payload that has an Open/Install action and stable app identity.
- `TFI-R-P0-004`: installing a MiniApp produces exactly one visible Bot projection derived from canonical manifest/catalog metadata; reinstall is idempotent.
- `TFI-R-P0-005`: Community is the sole membership authority for Group/Channel; Conversation participants are derived projection only.
- `TFI-R-P0-006`: public/private/invite/join_request admission and owner/admin/member/self-leave/ban rules are fail-closed and covered by negative contracts.
- `TFI-R-P0-007`: historical journal is recipient-neutral; privileged views are projected at read time for authorized admins.
- `TFI-R-P0-008`: protocol v3 negotiation preserves a documented v2 reader boundary and adds authoritative server time/request correlation/admission contracts without silent fallback.
- `TFI-R-P0-009`: group Bot messages obey the GBF behavior contract and execute through the single MSR runtime/session owner.

No task may claim these requirements complete without linked CI and packaged evidence.