# MSR-001 Evidence

Status: passed on canonical `main`.

## Existing implementation baseline
- Canonical convergence PR: #1971.
- Merged: 2026-08-22 02:44:32Z.
- Merge commit: `5dcfaee4b8fb12896f9ac92c6dbc51317d10b942`.
- PR changed 49 files with Mahayana-owned kernel/workspace/orchestrator/model/MCP/agent boundaries.

## Provenance baseline on main
`third_party/mahayana/mahayana-rs/SOURCES.lock` records Codex and Grok Build reviewed commits and requires Mahayana-owned public contracts/state machines.

## Historical reconciliation
- #1963: closed, not merged, superseded.
- #1968: closed, not merged, superseded by #1971 convergence.
- #1967: obsolete reverse-sync `main -> feat/mahayana-independent-kernel`; points at a superseded branch and is not canonical implementation evidence.

## Project-baseline evidence
- Branch: `docs/mahayana-sovereign-runtime-project`.
- Head commit: `a78de9b728ea2bdb9669aa1a6b57fa693479d711`.
- PR: #1989.
- PR CI run: `32559149040` — success.
- Protected merge commit: `88db63c328c3cba39971f3942509cb0b582502bc`.
- Canonical `main` re-read after merge confirmed `projects/mahayana-sovereign-runtime/` and its mandatory enterprise scaffold.
