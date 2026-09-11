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

## 2026-09-11 CLI-first continuation

`source/2026-09-11-cli-first-decoupled-test-loop.md` is the latest explicit requirement for decoupled functional/UI testing, rapid headless feedback, bounded automated repair, existing-PR integration and verified full-platform test delivery. Its durable task is `management/tasks/FCM-FAST-20260911.md`. The existing packaged safety gates remain intact; the fast inner loop is additional evidence, not a replacement for native/platform acceptance.

The WeChat article is a requested reference whose contents could not be retrieved. Do not attribute an unverified design or claim implementation parity to it. The implementation follows the explicit user request and inspected repository/upstream sources.

Reports must distinguish implementation, selected-suite verification, per-journey evidence completeness, protected-main integration, unattended AI executor operation, and full-platform release. None implies the others. Dated round records under `evidence/FCM-FAST-20260911/` preserve failures and exact-source results without retroactively upgrading earlier runs.
