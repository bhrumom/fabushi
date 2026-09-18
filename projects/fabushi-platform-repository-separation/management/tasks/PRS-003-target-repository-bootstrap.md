# PRS-003 — Target repository bootstrap

- Project ID: `FAB-P0013`
- Project Key: `PRS`
- Task ID: `PRS-003`
- Source requirement: `PRS-REQ-001`
- Status: `passed`
- Started: `2026-09-18`
- Updated: `2026-09-18`
- Source baseline: `cbe65975f3c4c077fa64af4171ebe3d2900185ad`

## Objective

Create one public GitHub repository per planned platform/shared boundary, including a standalone CLI
repository, and establish a readable `main` bootstrap before source extraction.

## Acceptance criteria

1. All 13 planned repositories exist under `bhrumom`, are public, and expose a readable `main`.
2. Each bootstrap commit contains only a migration README and no secrets or product-source copy.
3. URLs and exact bootstrap SHAs are recorded in the inventory and `evidence/PRS-003-repository-bootstrap.md`.
4. Existing `bhrumom/fabushi-chatgpt-auto-confirm-userscript` is reused rather than duplicated.
5. Source extraction, branch protection, CODEOWNERS, independent CI, packaged/E2E checks and Releases
   remain explicit follow-on gates; this task does not claim them complete.

## Verification

- `gh repo view` readback: 13 public repositories.
- `gh api` readback: each target has a `main` bootstrap commit matching the evidence table.
- No local application build, test, history rewrite, or packaging was performed.

## Evidence / branch / PR

- Evidence: `evidence/PRS-003-repository-bootstrap.md`.
- Repository bootstrap commits: see evidence table and inventory.
- Governance record PR: [#2706](https://github.com/bhrumom/fabushi/pull/2706), merged to canonical `main`
  at `a5724908bbe1579e0766677faf81353827bddbf2`.
- Canonical-main readback after the record merge: `9b7e0abbdaff5863ac815417fc7364414fe1f191`.
- Post-main product delivery: `N/A` — this task created repository bootstrap metadata only; no product
  source, build, runtime, or release behavior changed.

## Risks / next action

The repositories are intentionally bootstrap-only. Next configure repository governance, then run
Core/CLI/platform extraction in GitHub-hosted fresh mirrors with source/target refs and checksums.
