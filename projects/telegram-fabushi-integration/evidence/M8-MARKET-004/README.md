# M8-MARKET-004 Evidence — Marketplace 自动安全审核与自动上架

- Project: `FAB-P0001 / TFI`
- Task: `M8-MARKET-004`
- Baseline canonical main: `944461ea020966dd76905c7e601d9e6c121ae4b3`
- Implementation PR: `#2653`
- Bootstrap publication PR: `#2654`
- Hardening branch: `codex/tfi-market-004-stage-in-source-pr-20260916`
- Status: `IN_PROGRESS / SAME_PR_AUTOPUBLISH_HARDENING`

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
   - validates public version/digest against approval proof;
   - same approved version with changed content fails closed and requires a version bump.
5. `.github/workflows/marketplace-security-review.yml`
   - reusable required review: deterministic policy/tests, Semgrep CE, Trivy, Syft/Grype, CodeQL JavaScript/Python/Rust and OSV;
   - read-only source permissions plus code-scanning upload permissions;
   - 90-day evidence artifacts for deterministic/Semgrep/Trivy/SBOM layers.
6. `.github/workflows/ci.yml`
   - protected `CI result` depends on the full Marketplace Security Review, so merge queue cannot bypass any review layer.
7. `.github/workflows/marketplace-auto-publish.yml`
   - final design is same-PR staging, not a second generated PR;
   - triggered from successful `CI` through trusted default-branch `workflow_run`;
   - rejects fork PRs and PRs that also alter security/publisher tooling;
   - re-audits exact source, allows only public catalog/approval-ledger generated diffs, commits them back to the same source PR, dispatches CI on the generated head, then explicitly dispatches existing `automerge.yml` so protected merge queue remains authoritative;
   - does not require a PAT or repository-wide “Actions create/approve PR” permission.
8. BotFather `plugin-builder` policy
   - future official plugins register source/internal marketplace only; developers must not manually author public catalog approvals.

## Verified implementation history

### PR #2653 — security stack

- final exact head: `1c8f36dab2bf4024ef190148f48eedcba6425908`.
- exact-head Marketplace Security Review succeeded after real fixes to Semgrep regex escaping and Trivy action tag; no scanner was removed to make CI green.
- deterministic auditor + generator self-check passed against all 13 existing official plugins.
- Semgrep CE passed.
- Trivy filesystem vulnerability/secret/misconfiguration scan passed.
- Syft SBOM + Grype high/critical gate passed.
- CodeQL JavaScript/TypeScript, Python and Rust passed; Rust extraction was optimized with sparse checkout rather than disabled.
- OSV PR scan passed.
- required `CI result` succeeded.
- sensitive workflow change was explicitly authorized with `[automerge-force]`; PR entered protected merge queue and merge-group revalidation succeeded.
- merged canonical source SHA: `92b505a277b4104afd08ab8c5af01984fd63a6ed`.

### canonical-main independent review

- `Marketplace Security Review` run: `35052391204`.
- deterministic policy: success.
- Semgrep CE: success.
- Trivy: success.
- Syft/Grype: success.
- CodeQL JavaScript/TypeScript: success.
- CodeQL Python: success.
- CodeQL Rust: success.
- OSV **full** dependency scan: success.
- aggregate Marketplace security result: success.

### First real auto-publish + bootstrap

- auto-publish run: `35052478261`.
- exact canonical source was resolved and re-audited successfully.
- generator produced catalog + approval ledger successfully.
- workflow successfully committed and pushed branch `automation/marketplace-publish-92b505a277b4` at `f7c7187fd156438f32b0f4a348a9c185caf7efd6`.
- GitHub repository-level setting blocked the workflow's attempt to create a second PR using `GITHUB_TOKEN`; this was a control-plane permission blocker, not an audit/generator failure.
- bootstrap PR `#2654` was opened from that exact generated branch, passed required CI / protected merge and merged as canonical `efea16b40590ce60ec22474dbb82464bc7c542eb`.
- canonical `frontend/apps/web/public/.well-known/mahayana/marketplace-approvals.json` contains 13 plugin records with `decision: approved`, policyVersion `1`, exact version and immutable digest.

## Hardening decision

The repository-level GitHub setting is deliberately **not** broadened. Instead, the hardening branch removes the second-PR dependency:

1. source plugin PR exact head passes required `CI` / complete Marketplace Security Review;
2. trusted default-branch `Marketplace Auto Publish` resolves the same-repository PR and refuses forks/tooling-changing PRs;
3. it re-audits and generates only the two governed public Marketplace files;
4. generated files are committed back to the same source PR branch (branch push capability was already proven by run `35052478261`);
5. generated head is explicitly dispatched through `ci.yml` and watched to success;
6. workflow adds `automerge` and explicitly dispatches existing `automerge.yml` with the PR number;
7. existing controller applies sensitive-path/product-gate policy and enqueues protected merge; merge-group does final revalidation.

This keeps automatic listing fully inside existing protected governance without PATs, long-lived signing credentials or repository-wide PR-creation permission.

## Remaining closure evidence

This task remains incomplete at this evidence revision until:

- hardening PR exact-head `CI result` succeeds;
- hardening PR protected merge / merge-group succeeds and canonical-main readback confirms the workflow change;
- canonical `Marketplace Auto Publish` manual smoke against an open same-repo non-plugin PR proves safe resolver/no-op behavior;
- the next real same-repo plugin version/new plugin PR records the full generated-file write-back → generated-head CI → explicit automerge dispatch → merge-group → canonical catalog readback chain.

The third-party fork/external-repository path remains intentionally outside this task; it requires the same audit protocol plus a true hostile-code execution sandbox (for example gVisor) before automatic publication can be enabled.
