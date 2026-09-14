# GBF-509 Evidence — Grok-study avatar motion parity

## Scope

Upgrade the existing Fabushi-owned avatar runtime using behavior-level lessons from `bhrum/grok-icon-study`, without importing its extracted/reconstructed geometry, renderer, brands or proprietary assets.

## Implementation evidence

- Branch: `codex/gbf-509-grok-avatar-motion-parity`
- Starting canonical main: `429dde3c5b6e7096042606a4f8b1813f044b917e`
- Source/provenance record commit: `557978d48ce5af635b8ce7a9a6e59b4405521af5`
- Task record commit: `e6dcb5cc80af8786fd603490552a94e79083dfdb`
- Avatar runtime implementation commit: `337806ad859d2bb4be1eda0adf30c19894ad25ec`
- Fail-closed motion/provenance guard commit: `04788417bc4f2078cdbbdd6d1c7b92be3b632ebf`

### Runtime delta

`frontend/apps/web/src/app/host/fabushi-avatar-runtime.tsx` now keeps the existing Fabushi SVG/body shapes but adds:

- independent spring channels for body Y, roll, squash, spin, gaze X/Y, left/right blink and burst response;
- state-specific asymmetric eye poses instead of one pair of symmetric ellipse transforms for every state;
- canonical-identity-seeded ambient micro gaze, nod/roll impulse, hop/squash and wink-like actions;
- explicit pointer/gaze precedence over ambient gaze;
- state overlays for orbit/radar/progress/loading/send/receive/write/alert families;
- spring-driven `spin`, `bounce` and `burst` imperative actions;
- static low-cost reduced-motion/paused behavior;
- `data-motion-model="spring-character-v2"` and `data-overlay` observability markers.

### Provenance gate

`.github/scripts/assert-bot-mark-motion.py` now requires the richer spring runtime and rejects production avatar references to the study/reconstructed implementation terms including `geometry-data.js`, `GROK_GEO`, `GROK_TABLES`, `GrokCharacter`, and `grok-icon-study`, in addition to the previously retired Grok/OpenMaus renderer paths.

## Existing product E2E reused

`desktop/e2e/mahayana-agent-workbench.spec.ts` already drives the real Mahayana multi-step journey and requires `#mahayana-agent-header-avatar [data-agent-state="result"]` after completion. That is the canonical runtime state path this implementation consumes; no parallel avatar fixture/runtime is introduced.

## Acceptance state

- Implementation: `IMPLEMENTED`
- GitHub PR CI: pending
- Protected-main merge/readback: pending
- Canonical-main packaged Electron visual evidence: pending
- Release: pending

GBF-509 must remain `IN_PROGRESS` until all required repository delivery gates above are proven on the same accepted canonical main lineage.
