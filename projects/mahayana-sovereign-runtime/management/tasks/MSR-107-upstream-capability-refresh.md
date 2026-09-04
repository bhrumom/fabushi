# MSR-107 — current Codex/Grok Build capability and license refresh

- **Project ID / Key:** `FAB-P0005 / MSR`
- **Task ID:** `MSR-107`
- **Program:** `FAB-ARCH-P0-20260904`
- **Status:** `NOT_STARTED`
- **Owner:** Execution project group (governance/provenance audit)
- **Dependencies:** none
- **Parallel condition:** yes; this task changes provenance/project records only and must not modify runtime implementation.

## Objective
Refresh MSR-101/102 capability inventory against pinned current upstream revisions and produce a file-level provenance decision ledger without importing code by assumption.

## Fixed upstream inputs
- `openai/codex@8e85265c39176b6bd498242a33d7b0f9b4b98303`; root LICENSE Apache-2.0; root NOTICE exists and must be evaluated/preserved when applicable.
- `xai-org/grok-build@72a61251fcffb464bcc687aeb5a998e5a98ec0c9`; root LICENSE Apache-2.0.
- Reconstructed Grok Bot is **not** an implementation upstream for this task; unclear rights prohibit source adoption.

## Exact repository scope
- `projects/mahayana-sovereign-runtime/docs/08-upstream-capability-matrix.md`
- `third_party/mahayana/mahayana-rs/SOURCES.lock`
- this task file and MSR P0 WBS/acceptance/risk/changelog/evidence records.
No runtime source file may be edited by MSR-107.

## Implementation/audit steps
1. Inventory session lifecycle, workflow/subagent, MCP/plugins/marketplace, policy/approval, network/process, worktree/checkpoint, model/config and observability capabilities at each fixed revision.
2. For every P0 capability, record exact upstream **file path + revision**, applicable license, NOTICE/attribution disposition, current Mahayana equivalent, gap and decision (`reuse concept`, `adapt`, `clean reimplement`, `reject`).
3. Record any ambiguous license/rights as `REJECT/DO-NOT-USE` until independently resolved.
4. Update `SOURCES.lock`/project ledger only with verified facts; no code adoption in this task.
5. Add a downstream gate: any later implementation that borrows/adapts upstream work must repeat exact-file revision/license/NOTICE/attribution/adaptation evidence in its own task/evidence. This MSR-107 audit **cannot** substitute for implementation-time provenance.
6. Commit project records and request real-diff review.

## In scope
Capability inventory, file-level provenance/license/NOTICE decisions and downstream provenance gate.

## Out of scope
Runtime code changes, builds/tests, implementing missing capabilities, using reconstructed Grok source.

## Acceptance by category
- **Unit:** `N/A` — no runtime unit is changed. Alternative check: deterministic file/path/SHA ledger consistency review. Owner: code-review group.
- **Contract:** every P0 capability has an exact upstream file/revision/license/NOTICE/disposition and current Mahayana mapping or explicit reject; no unclassified P0 row.
- **Integration:** `N/A` — no runtime integration is authorized. Alternative check: cross-reference matrix <-> `SOURCES.lock` <-> task evidence. Owner: architecture/code-review group.
- **E2E:** `N/A` — governance/provenance only. Alternative check: fresh-chat reviewer can trace every decision to an upstream file and revision. Owner: code-review group.
- **Security:** ambiguous/unlicensed material is rejected; secrets/user data are not copied into provenance records; NOTICE/attribution obligations are explicit.
- **Performance:** `N/A` — no executable path changes. Alternative check: verify diff is restricted to project/provenance records. Owner: code-review group.

## Mandatory implementation-time provenance gate
For any later task that actually adapts Codex/Grok Build code/implementation, that task must write: upstream repo, exact file, exact revision, license, NOTICE/attribution disposition, local destination, adaptation/reimplementation note and reviewer decision. Architecture-level pinning here does not satisfy that gate.

## Write-back
Update this file with branch/commit/PR/review head+verdict and evidence ledger paths; update MSR WBS/acceptance/risk/status/changelog. CI/build/package fields are `N/A` only because this task is docs/provenance-only; the objective substitute is real-diff provenance review. Do not claim runtime CI/release success.

## Execution fields
Branch: `pending`; Commit: `pending`; PR: `pending`; Review: `pending`; Provenance evidence: `pending`; Runtime CI/E2E/Release: `N/A — no runtime modification; reviewer verifies projects/provenance-only diff`.
