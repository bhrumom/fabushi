# Branch protection, merge queue, and release policy

Fabushi uses a protected-trunk delivery model designed for high throughput without weakening safety.

## Core delivery model

1. Pull requests prove that a change is safe to merge.
2. `main` is protected and should remain deployable.
3. One aggregate required check, `CI result`, represents the selected checks for the exact diff.
4. GitHub merge queue owns the final merge into `main` and validates the queued candidate against the latest target branch.
5. CI is risk-tiered and change-aware; unrelated product suites must not run merely because a PR entered the merge queue.
6. Production CD is also change-aware; an unrelated documentation merge must not deploy Worker, Fabushi Pay, or other products.
7. Sensitive delivery/security changes require explicit authorization and still pass through the merge queue.

## Required GitHub settings for `main`

Configure the repository/ruleset so `main` enforces:

- Require a pull request before merging.
- Require status checks to pass before merging.
- Require `CI result` as the aggregate status check.
- Require GitHub merge queue rather than direct protected-branch merging.
- Require conversation resolution before merging.
- Prefer squash/linear history for normal changes.
- Do not allow force pushes.
- Do not allow branch deletion.
- Restrict protection bypasses to emergency maintainers only and audit every bypass.

## CI risk tiers

### Tier 0 — documentation and project governance

Examples include `projects/**`, repository-root Markdown, and direct `.github/*.md` policy documents.

These changes still produce the required `CI result` on both the PR head and the merge-group candidate, but they do not run unrelated Frontend, Worker, MCP, or Electron suites.

### Tier 1 — known product-domain changes

The CI classifier maps files to domain checks. Multiple affected domains run in parallel.

Current canonical domains include:

- Frontend checks
- Worker checks
- MCP plugin contracts
- Canonical architecture/workflow guardrails
- Electron Feature Host contract

### Tier 2 — unknown/unclassified non-document paths

Unknown runtime paths fail safe by selecting all current canonical domain checks. They must never become green simply because the classifier does not recognize the file.

A follow-up governance task should explicitly classify frequently changed unknown paths instead of leaving them permanently on the expensive fallback.

### Tier 3 — sensitive delivery/security changes

CI/CD workflows/actions/scripts, authentication, payments, deployments, and database-sensitive changes are not eligible for unattended protected-branch merging. They require explicit authorization and merge-queue validation.

## Merge queue behavior

The queue is intentionally retained. It protects `main` from stale-green PRs by testing the synthetic queued candidate on top of the latest base and any earlier queued changes.

The `CI` workflow listens to `merge_group: checks_requested` and classifies the exact range:

`merge_group.base_sha .. merge_group.head_sha`

The queue must **not** force all product suites for every PR. The same risk/domain classification used for PR validation is applied again to the merge-group candidate.

## Aggregate required check

Require only:

- `CI result`

`CI result` depends on the internal jobs selected by the classifier. A selected job must succeed; an unrelated job may be skipped. The classifier itself is also part of the aggregate gate.

This keeps branch rules stable while internal CI can evolve without continually editing required-check settings.

## Automerge policy

Automerge is opt-in, not global.

A PR may be automatically authorized only when all of these are true:

- It targets `main`.
- It is not a draft.
- It comes from this repository, not a fork.
- It has the `automerge` label.
- Its latest head commit has a successful `CI` workflow.
- It does not touch sensitive paths unless explicitly authorized.

The automerge workflow does **not** directly merge into `main`. It arms GitHub-native auto-merge/protected merge behavior. GitHub merge queue remains responsible for final queue entry, merge-group CI, ordering, and merge.

Sensitive paths include CI/CD configuration, deployment scripts, auth, payment, and database-related files. Those changes need explicit maintainer/user authorization even when CI is green.

## CD policy

CD runs only from validated `main` state or explicit manual dispatch.

For workflows triggered after successful `CI` on a `main` push, the first job must resolve the source SHA and determine whether that product's deployment inputs actually changed.

- If the domain changed: continue staging / migration / deploy / smoke gates.
- If the domain did not change: stop after the lightweight impact resolver.
- If impact detection is uncertain because a diff exceeds the safety limit: fail safe by deploying/validating rather than silently skipping.
- Manual dispatch remains an explicit force-deploy path for controlled redeploys and rollback validation.

The production promotion model remains:

1. Validate the exact source commit.
2. Deploy staging where applicable.
3. Run staging API/UI E2E and smoke gates.
4. Run required native/install smoke gates for relevant products.
5. Deploy production.
6. Run production smoke/health validation.
7. Record release/deployment evidence.

Production deployments are serialized by product/environment concurrency groups to prevent races.

## Latency policy

Optimize for developer feedback without bypassing safety:

- Tier 0 docs/governance: classifier + `CI result`; target seconds-to-low-tens-of-seconds runner time, subject to GitHub-hosted runner queueing.
- Tier 1 product code: only impacted suites, parallelized.
- Merge queue: revalidate the same impacted domains on the synthetic candidate.
- Expensive packaging, device E2E, store delivery, and production deployment run only when their product/release path requires them.

Do not make a low-risk change wait for unrelated compilation, device tests, migrations, or production deployments.
