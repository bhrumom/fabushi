# Branch protection and release policy

This repository uses a mature-team delivery model:

1. Pull requests prove that a change is safe to merge.
2. The default branch is protected and stays deployable.
3. Production deploys happen only from `main` after staging and smoke gates pass.
4. Fully automatic merge is explicit, label-gated, and blocked for sensitive paths.

## Required GitHub settings

Enable these repository settings for `main` under **Settings -> Branches -> Branch protection rules**.

### Main branch protection

- Require a pull request before merging.
- Require status checks to pass before merging.
- Require branches to be up to date before merging, or enable GitHub merge queue.
- Require conversation resolution before merging.
- Require linear history when practical.
- Do not allow force pushes.
- Do not allow deletions.
- Restrict bypasses to maintainers only.

### Required checks

Require this aggregate check instead of every internal job:

- `CI result`

The aggregate check depends on:

- `Flutter quality, tests, build, and web smoke`
- `Cloudflare Worker syntax and deploy dry-run`
- `Playwright E2E contract validation`

### Merge queue

For best protection against stale green PRs, enable GitHub merge queue for `main`.

The `CI` workflow supports the `merge_group` event, so queued merge candidates are validated against the latest `main` before they land.

## Automerge policy

Automerge is opt-in, not global.

A PR can be merged automatically only when all of these are true:

- It targets `main`.
- It is not a draft.
- It comes from this repository, not a fork.
- It has the `automerge` label.
- Its latest head commit has a successful `CI` run.
- It does not touch sensitive paths.

Sensitive paths include CI/CD configuration, deployment scripts, auth, payment, and database-related files. Those changes require a human merge even when CI is green.

## CD policy

CD runs only after a successful `CI` workflow from a `main` push, or by explicit manual dispatch.

The production path is:

1. Build release artifact.
2. Deploy staging.
3. Run staging API and app UI E2E.
4. Run Android native install smoke.
5. Run iOS native install smoke.
6. Deploy production.
7. Run production smoke test.

Production deploys are serialized with a single `cd-production-main` concurrency group. This avoids two production deployments racing each other.

Manual CD dispatch accepts an optional `source_sha` for controlled redeploys and rollback validation.
