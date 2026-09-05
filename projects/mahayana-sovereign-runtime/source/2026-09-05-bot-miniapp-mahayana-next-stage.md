# 2026-09-05 — Bot / MiniApp / Mahayana 下一阶段原始需求快照

- Architecture revision: `FAB-ARCH-20260905-01`
- Spec digest: `sha256:106333ef4ab8c1d3315966361a0c7e98fcbaf0be84f776d46300c7013a3f0d20`
- Canonical repository baseline: `bhrumom/fabushi@586a0952f17ab4b36dab9a69402b837968f5aa3f`
- Scope owner: `FAB-P0005 / MSR`, with cross-project dependencies on `FAB-P0001 / TFI` and `FAB-P0004 / GBF`.

## User requirements preserved for this architecture round

1. Desktop first/returning launch currently takes about one minute before message content is fully visible. Diagnose startup, session restore, first-frame message hydration and event-stream critical path before changing behavior.
2. Bot-generated MiniApps must become durable discoverable/installable/direct-open entities/cards with real manifest, version/digest, preview, install and runtime state rather than code-only output.
3. Installed MiniApps must have an explicit account-scoped one-to-one binding to their default Bot actor/direct conversation, including visible and auditable permission/update/uninstall/recovery lifecycle.
4. Mahayana CLI is the single independent Fabushi product core shared by all Bots; one Bot maps to one durable Mahayana session. Absorb capability-level ideas from current `xai-org/grok-build` and `openai/codex`; use `bhrum/grok-bot-0.18-reconstructed` only as behavior/protocol evidence. Execution is local Fabushi/Mahayana host execution, never a second cloud-computer runtime.
5. Bots may operate explicitly selected same-account devices and installed MiniApps through the common Mahayana tool/policy plane. Group conversations need multi-step, multi-participant and multi-result turns. Device actions must bind account, target device, target device generation, Bot Mahayana session generation, conversation/invocation, grant and audit identity.

## Hard invariants

- Reuse `FAB-P0001`, `FAB-P0004`, `FAB-P0005`; do not create a duplicate project.
- Runtime capability without implementation plus exact-head CI/E2E proof remains `PLANNED`.
- Skills, orchestration documents and reconstructed evidence are not runtime implementation.
- This round is architecture/records only: no product code, merge or release.
