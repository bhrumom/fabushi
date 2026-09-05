# 2026-09-05 — GBF scope: Bot target-bound device control + Grok-style group projection

- Architecture revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`
- Canonical baseline: `bhrumom/fabushi@586a0952f17ab4b36dab9a69402b837968f5aa3f`

GBF reuses the already-merged GBF-409/410/411 device and semantic App MCP surfaces. This round adds no second remote-control protocol. It requires every Bot-issued device mutation to carry and verify Mahayana Bot session identity/generation in addition to existing account/device/client/session/generation authorization, and it requires Grok-Bot-like multi-step/multi-result group UX to project canonical TFI group events without becoming a second runtime. Reconstructed Grok Bot material remains evidence-only and is never copied as unlicensed source.
