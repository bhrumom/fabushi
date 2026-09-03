# Source of Truth

Canonical project record: `bhrumom/fabushi` `main` → `projects/fabushi-cicd-merge-governance/`.

## Requirement sources

- `source/README.md` preserves the original CI/CD and merge-governance requirement and diagnosed cause.
- `source/2026-08-24-main-e2e-release-open-source-first.md` records the explicit requirement for open-source-first task startup, fast warm/incremental build/test, per-main packaged simulated-user E2E, E2E-gated GitHub Release publication, and the original old-client updater verification requirement.
- `source/2026-08-24-updater-proof-optional-clarification.md` is the latest explicit clarification: previous-installed-App discovery/button/download/install/relaunch verification is optional/non-blocking by default, while required packaged E2E, Release integrity, updater-compatible assets/versioning, open-source-first, and warm-build requirements remain mandatory.

## Precedence

1. Latest explicit user requirement once persisted here.
2. This file and designated dated sources under `source/`; when dated sources conflict, the later explicit clarification supersedes only the conflicting interpretation.
3. Accepted ADRs and current CI/CD model docs.
4. WBS, acceptance matrix, status, risk and task records.
5. Actual GitHub workflow files, rules/check results, PRs, merge queue, Releases and post-release E2E for implementation facts.
6. Conversation memory.

No workflow is considered optimized merely because a document says so; objective GitHub Actions, required packaged user-E2E, Release evidence and protected-main facts are required. Old-client updater journey evidence is optional unless the specific task explicitly promotes it to a required risk gate. A cache hit is acceleration evidence, not release provenance.
