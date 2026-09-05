# MSR architecture-round evidence index — 2026-09-05

- Architecture revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`
- Baseline: `bhrumom/fabushi@586a0952f17ab4b36dab9a69402b837968f5aa3f`
- Evidence status: architecture facts only; runtime acceptance evidence is not yet present.

## Current-main evidence anchors

- Mahayana CLI real command surface: `third_party/mahayana/mahayana-rs/mahayana-cli/src/main.rs`.
- Fabushi-owned runtime boundaries: `mahayana-kernel`, `mahayana-host-protocol`, `mahayana-orchestrator`, `mahayana-product` and source-boundary checks.
- Existing capability matrix: `docs/08-upstream-capability-matrix.md`; it is an input and contains planned/partial rows, not completion proof.
- Current upstream review pins for this architecture revision: Grok Build `72a61251fcffb464bcc687aeb5a998e5a98ec0c9`; Codex `ddf04ad26789d040f9ef6a96736f76602e35a6cc`; Grok Bot reconstructed evidence `107877b4e2134fd167d239411386f09e42eadd6d`.

## Planned task evidence directories

- `evidence/MSR-107/`: source-path/license/provenance matrix + upstream lock.
- `evidence/MSR-204/`: BotRuntimeBinding create/race/restart/reclaim/stale-generation proof.
- `evidence/MSR-205/`: installed MiniApp discovery/control permission fencing proof.
- `evidence/MSR-206/`: bounded multi-Bot orchestration/restart/idempotency proof.

No Skill, document, compatibility adapter or command name is runtime-completion evidence by itself.