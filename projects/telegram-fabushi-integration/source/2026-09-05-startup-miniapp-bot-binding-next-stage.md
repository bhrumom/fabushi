# 2026-09-05 — TFI scope: startup + MiniApp entity/Bot binding + group protocol

- Architecture revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`
- Canonical baseline: `bhrumom/fabushi@586a0952f17ab4b36dab9a69402b837968f5aa3f`

TFI owns the canonical messaging/MiniApp data semantics for this round: diagnose the desktop first-frame/message hydration regression; model MiniApp definition/version/install state as durable canonical entities; make generated MiniApps renderable as installable/openable cards; bind each install to exactly one default Bot actor/direct conversation per account; and define the canonical group-turn event protocol used by runtime orchestration. Mahayana execution semantics remain MSR-owned and device-control transport/security remains GBF-owned.

No existing TFI project is replaced. `M3-DESKTOP-002` and `M8-MARKET-002` are inputs, not proof that the new requirements are already complete.
