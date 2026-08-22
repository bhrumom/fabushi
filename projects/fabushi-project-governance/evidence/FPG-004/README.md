# FPG-004 Evidence Index

Status: in-progress

## Source and decision evidence

- Source requirement: `projects/fabushi-project-governance/source/2026-08-22-FPG-004-global-project-identifiers.md`
- Task record: `projects/fabushi-project-governance/management/tasks/FPG-004-global-project-identifiers.md`
- ADR: `projects/fabushi-project-governance/decisions/ADR-0003-global-portfolio-project-identifiers.md`

## Historical ordering evidence

Initial numbering is derived from the first formal project-folder commits on canonical `main`:

| Project ID | First formal project commit | PR |
|---|---|---|
| FAB-P0001 | `99cd4b227a34b49fc04c3265c1dfdee585344160` | #1975 |
| FAB-P0002 | `eaf273dafc140619b06b46a4d7d234997acde05d` | #1976 |
| FAB-P0003 | `ac94b40d4a05a0211146c2bb5904aa936a7bc928` | #1978 |
| FAB-P0004 | `6d1e9cd7a475e8058d5d8512f5c3a0c21da8ed9c` | #1982 |
| FAB-P0005 | `88db63c328c3cba39971f3942509cb0b582502bc` | #1989 |

## Implementation evidence

- Registry: `projects/PORTFOLIO.json`
- Policy: `projects/PROJECT_ID_POLICY.md`
- Human portfolio index: `projects/README.md`
- Validator: `scripts/check-project-portfolio.py`
- CI gate: `.github/workflows/project-portfolio-governance.yml`
- Project metadata: all current `projects/*/PROJECT.yaml` files.

## Pending evidence before closure

- Validator workflow success on PR head.
- Repository required CI success.
- PR number/review/merge evidence.
- Protected merge / merge queue evidence when applicable.
- Canonical `main` re-fetch showing registry, all project IDs, governance instructions, and CI validator after merge.

Do not mark FPG-004 passed until all pending evidence exists.
