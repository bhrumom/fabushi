# 2026-09-15 — GBF-509 avatar parity closeout

## Scope

Reconcile durable project records for the already-delivered Grok-study avatar motion parity work. This closeout does not introduce a second avatar runtime and does not modify product code.

## Live facts re-read

- Implementation PR: `#2621`
- Exact implementation head: `72d987e5e32546ab31a7c6650219ed58dcf1a1bf`
- Merge commit: `8ecfaa9fc777c8286d7e15d80c4cd8bd45202764`
- Canonical main at closeout start: `f6ca88f5713a3e8cde0839fe1e48253a24d0145f`
- Verified descendant Release source: `4f484be2fd72f13289473f9c4917e03b78a92022`
- Packaged Electron quality run: `34922024240` — success
- Stable immutable Release: `desktop-1.2.65-4f484be2fd72`

## Records changed

- Marked `management/tasks/GBF-509-grok-avatar-motion-parity.md` as `RELEASED` and bound it to live CI/main/E2E/Release facts.
- Expanded `evidence/GBF-509/README.md` with exact-head, merge, lineage, packaged Electron diagnostics and Release evidence.
- Reconciled the stale implementation status-round note.
- Added GBF-509 to the canonical WBS as a released M5 task.

## Product and provenance decision

The production runtime remains the existing `BotMark -> FabushiBotMarkEngine -> FabushiAvatarRuntime` chain. No duplicate renderer or study runtime was added.

The accepted result is clean-room observable-behavior parity: Fabushi-owned spring dynamics, state-specific/asymmetric eyes, deterministic identity-seeded micro-actions, pointer gaze, semantic overlays, spin/bounce/burst reactions, reduced-motion handling and canonical identity continuity.

The reference repository states that extracted shapes/assets belong to xAI / their rights holders and are not for commercial redistribution. Therefore proprietary `geometry-data.js`, eye polygons, body path tables, brand art and reconstructed renderer code remain excluded.

## Verification boundary

This closeout commit is documentation/project-governance only, so a new product package is not required for the closeout delta itself. The underlying application change already satisfied product delivery through PR `#2621`, canonical-main ancestry, packaged Electron quality run `34922024240`, retained multi-platform diagnostics, and Release `desktop-1.2.65-4f484be2fd72`.

A later-source `Protected account production MCP preflight` failure is recorded as unrelated to GBF-509 and is not used to claim or deny avatar parity acceptance.

## Rollback

Revert only this closeout records commit/PR if any recorded GitHub fact is later proven incorrect. Do not revert the released avatar runtime through this documentation rollback and do not restore any upstream/reconstructed renderer or proprietary assets.
