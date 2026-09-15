# GBF-509 Evidence — Grok-study avatar motion parity

## Scope

Upgrade the existing Fabushi-owned avatar runtime using behavior-level lessons from `bhrum/grok-icon-study`, without importing its extracted/reconstructed geometry, renderer, brands or proprietary assets.

## Implementation evidence

- Implementation branch: `codex/gbf-509-grok-avatar-motion-parity`
- Starting canonical main: `429dde3c5b6e7096042606a4f8b1813f044b917e`
- Source/provenance record commit: `557978d48ce5af635b8ce7a9a6e59b4405521af5`
- Task record commit: `e6dcb5cc80af8786fd603490552a94e79083dfdb`
- Avatar runtime implementation commit: `337806ad859d2bb4be1eda0adf30c19894ad25ec`
- Fail-closed motion/provenance guard commit: `04788417bc4f2078cdbbdd6d1c7b92be3b632ebf`
- Final implementation head: `72d987e5e32546ab31a7c6650219ed58dcf1a1bf`
- PR: `#2621` — merged 2026-09-14
- Merge commit: `8ecfaa9fc777c8286d7e15d80c4cd8bd45202764`

### Runtime delta

`frontend/apps/web/src/app/host/fabushi-avatar-runtime.tsx` keeps Fabushi-owned SVG/body shapes and implements:

- independent spring channels for body Y, roll, squash, spin, gaze X/Y, left/right blink and burst response;
- state-specific asymmetric eye poses instead of one pair of symmetric ellipse transforms for every state;
- canonical-identity-seeded ambient micro gaze, nod/roll impulse, hop/squash and wink-like actions;
- explicit pointer/gaze precedence over ambient gaze;
- state overlays for orbit/radar/progress/loading/send/receive/write/alert families;
- spring-driven `spin`, `bounce` and `burst` imperative actions;
- static low-cost reduced-motion/paused behavior;
- `data-motion-model="spring-character-v2"` and `data-overlay` observability markers.

### Provenance gate

`.github/scripts/assert-bot-mark-motion.py` requires the richer spring runtime and rejects production avatar references to the study/reconstructed implementation terms including `geometry-data.js`, `GROK_GEO`, `GROK_TABLES`, `GrokCharacter`, and `grok-icon-study`, in addition to retired Grok/OpenMaus renderer paths.

The reference repository README labels the extracted shapes/assets as belonging to xAI / their rights holders and not for commercial redistribution. Therefore GBF-509 intentionally adapts observable motion/interaction behavior in clean-room Fabushi code and does not copy proprietary path tables, eye polygons, brand art or reconstructed renderer code.

## Delivery evidence — 2026-09-15 live readback

### Exact implementation head / PR

- PR `#2621` exact head: `72d987e5e32546ab31a7c6650219ed58dcf1a1bf`.
- GitHub check-run collection on that head reports 39 checks. Electron desktop result, computer-control security result and protected-merge authorization are successful; no failed exact-head check was found in the check-run set used for this closeout.
- PR merged at 2026-09-14T09:06:34Z as `8ecfaa9fc777c8286d7e15d80c4cd8bd45202764`.

### Canonical main and immutable delivery lineage

- Canonical `main` readback on 2026-09-15: `f6ca88f5713a3e8cde0839fe1e48253a24d0145f`.
- `main` is 25 commits ahead of the GBF-509 merge commit and retains the spring avatar runtime.
- Release source `4f484be2fd72f13289473f9c4917e03b78a92022` is 19 commits ahead of the GBF-509 merge commit.
- The compare interval `8ecfaa9... -> 4f484be2...` does not modify `frontend/apps/web/src/app/host/fabushi-avatar-runtime.tsx`; therefore the release source contains the accepted GBF-509 avatar implementation unchanged.

### Packaged Electron verification

Electron workflow run `34922024240` (`Electron desktop quality gate`) is a successful `push` run on `main` at exact source `4f484be2fd72f13289473f9c4917e03b78a92022`.

The Windows packaged lane successfully completed:

- renderer build;
- canonical Electron packaging;
- exact-SHA delivery manifest;
- packaged Computer Use/runtime verification;
- `Simulate the complete user journey in packaged macOS or Windows Electron`;
- packaged user-journey diagnostics upload;
- Electron package upload.

Retained E2E diagnostics from the same workflow/source:

- `fabushi-electron-mac-e2e-diagnostics` — `sha256:c6a1baa21f53c3356f5a7c0cc80e3a40b873ff8b6606f08b924a212c105c4907`
- `fabushi-electron-win-e2e-diagnostics` — `sha256:d6974d13f4e287e767a2d227d7dd8fcbf370d66ee758fb8a85bad161c47532b3`
- `fabushi-electron-linux-e2e-diagnostics` — `sha256:3c4b6adba7bb0e13a2be3057736dc174603c58b7cd0429162219f96cd1fc68aa`
- prepackage diagnostics `electron-prepackage-e2e-34922024240-1` — `sha256:e5f7cdbad1e7eeeaec9e98f01319e5bf9eb71e362d82a89d881526afbe077b5a`

Packaged artifacts from the same exact source include macOS, Windows and Linux Electron packages.

### Release

- Stable immutable Release: `desktop-1.2.65-4f484be2fd72`
- Name: `Fabushi Desktop 1.2.65`
- Target source: `4f484be2fd72f13289473f9c4917e03b78a92022`
- Published: 2026-09-15T02:57:01Z
- Release assets include macOS ARM64 DMG/ZIP and other desktop platform packages.

A separate check named `Protected account production MCP preflight` failed on the same release source. It belongs to the remote protected-account/MCP delivery path, not the GBF-509 avatar runtime or Electron packaged quality gate. It is recorded rather than hidden, but it does not negate the successful avatar implementation, packaged Electron journey, or published desktop Release.

## Existing product E2E reused

`desktop/e2e/mahayana-agent-workbench.spec.ts` drives the real Mahayana multi-step journey and requires `#mahayana-agent-header-avatar [data-agent-state="result"]` after completion. That is the canonical runtime state path consumed by this implementation; no parallel avatar fixture/runtime was introduced.

## Acceptance state

- Implementation: `IMPLEMENTED`
- Exact-head PR CI: `PASSED`
- Protected-main merge/readback: `PASSED`
- Canonical-main packaged Electron journey/evidence: `PASSED`
- Release containing unchanged implementation: `PASSED`
- Task: `RELEASED`

GBF-509 is closed on the verified canonical lineage above. Broader full-project Grok parity remains governed independently by the later project-level parity tasks and must not be inferred from this avatar-only closeout.
