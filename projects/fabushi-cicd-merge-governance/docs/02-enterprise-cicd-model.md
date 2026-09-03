# Enterprise CI/CD & Merge Model

## Merge lifecycle

`branch -> PR impact classification -> selected required checks -> CI result -> merge queue -> merge-group impact classification -> selected checks -> main -> change-aware CD`

## Risk tiers

### Tier 0 — docs / project governance

Examples: `projects/**`, repository-root Markdown, `.github/*.md`.

Required path: classifier + aggregate `CI result`; merge queue remains mandatory but must not force unrelated product suites.

### Tier 1 — product-domain code

Run only checks mapped to affected domains (Frontend, Worker, MCP, Electron, etc.). If multiple domains change, run them in parallel.

### Tier 2 — unknown/unclassified runtime path

Fail safe by selecting all canonical checks. Never silently mark green simply because the path classifier does not know the file.

### Tier 3 — sensitive delivery/security infrastructure

CI/CD workflows/actions/scripts, auth, payment, deployment and database-sensitive paths are not eligible for unattended direct merging. They require explicit authorization and merge queue validation.

## Merge queue

The merge queue is retained because it validates a synthetic candidate containing the PR on top of the latest target branch/queued changes. `merge_group.base_sha..head_sha` must be classified exactly like a PR diff; merge-group events must not blindly force all domains.

## Automerge

Automerge is an authorization mechanism, not a protection bypass. An authorized low-risk PR may be armed/enqueued automatically only after its PR-head CI is green. GitHub merge queue still owns the final merge and reruns the required gate on the merge-group candidate.

## CD

Production workflows triggered after successful main CI must independently determine whether their product domain changed. If not, they exit at the lightweight resolver stage. A docs-only merge must never run migrations or production deploy steps for Worker or Fabushi Pay.
