# M8-MARKET-004 Evidence — Marketplace 自动安全审核与自动上架

- Project: `FAB-P0001 / TFI`
- Task: `M8-MARKET-004`
- Baseline canonical main: `944461ea020966dd76905c7e601d9e6c121ae4b3`
- Implementation branch: `codex/tfi-market-004-auto-review-publish-20260916`
- Status: `IN_PROGRESS / PR_AND_CI_PENDING`

## Implemented evidence seams

1. `scripts/marketplace_security.py`
   - dependency-free deterministic audit policy;
   - all registered plugin directories are hashed into an immutable content digest;
   - blocks symlinks, manifest/version/runtime-path violations, high-confidence credentials/private keys and remote/decode-to-execution patterns;
   - invalidates a changed digest under an already-approved version.
2. `scripts/audit-official-plugin-marketplace.py`
   - emits `fabushi.marketplace.audit.v1` JSON with exact source SHA and per-plugin findings.
3. `scripts/generate-official-plugin-marketplace.py`
   - deterministically generates the public catalog and `fabushi.marketplace.approvals.v1` ledger only from approved current plugin source.
4. `scripts/check-official-plugin-marketplace.py`
   - preserves the existing pre-ledger migration contract;
   - once the ledger exists, validates public version/digest against approval proof while permitting a newer internal version to wait for canonical-main auto-publish.
5. `.github/workflows/marketplace-security-review.yml`
   - reusable required review: deterministic policy/tests, Semgrep CE, Trivy, Syft/Grype, CodeQL and OSV;
   - read-only source permissions plus code-scanning upload permissions;
   - always-retained evidence for deterministic/Semgrep/Trivy/SBOM layers.
6. `.github/workflows/ci.yml`
   - protected `CI result` depends on the full Marketplace Security Review, so merge queue cannot bypass any review layer.
7. `.github/workflows/marketplace-auto-publish.yml`
   - runs only from a successful Marketplace Security Review of current canonical `main` (or explicit manual canonical SHA);
   - re-audits source, generates catalog + approval ledger, creates a generated-only PR, explicitly dispatches required `CI result`, and requests auto-merge through protected main/merge queue.
8. BotFather `plugin-builder` policy
   - future official plugins register source/internal marketplace only; developers must not manually author public catalog approvals.

## Required closure evidence

This task must remain incomplete until all of the following are recorded here:

- implementation PR number + exact head SHA;
- required `CI result` success for current PR head;
- Marketplace Security Review child results for deterministic, Semgrep, Trivy, Syft/Grype, CodeQL, OSV;
- protected merge / merge-group evidence;
- canonical-main SHA readback;
- canonical-main `Marketplace Security Review` success;
- `Marketplace Auto Publish` run showing either generated publication PR or an exact no-op;
- if publication PR is generated: its required CI, merge queue, canonical-main readback and public catalog/approval-ledger content proof.

No completion claim is valid before those artifacts exist.
