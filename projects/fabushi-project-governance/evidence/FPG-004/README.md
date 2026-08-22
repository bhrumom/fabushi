# FPG-004 Evidence Index

Status: passed

## Source and decision evidence

- Portfolio Project ID: `FAB-P0002`
- Project Key: `FPG`
- Task: `FPG-004`
- Source requirement: `projects/fabushi-project-governance/source/2026-08-22-FPG-004-global-project-identifiers.md`
- Task record: `projects/fabushi-project-governance/management/tasks/FPG-004-global-project-identifiers.md`
- ADR: `projects/fabushi-project-governance/decisions/ADR-0003-global-portfolio-project-identifiers.md`

## Historical ordering evidence

Initial numbering is derived from the first formal project-folder commits on canonical `main`:

| Project ID | Project Key | First formal project commit | PR |
|---|---|---|---|
| `FAB-P0001` | `TFI` | `99cd4b227a34b49fc04c3265c1dfdee585344160` | #1975 |
| `FAB-P0002` | `FPG` | `eaf273dafc140619b06b46a4d7d234997acde05d` | #1976 |
| `FAB-P0003` | `FCM` | `ac94b40d4a05a0211146c2bb5904aa936a7bc928` | #1978 |
| `FAB-P0004` | `GBF` | `6d1e9cd7a475e8058d5d8512f5c3a0c21da8ed9c` | #1982 |
| `FAB-P0005` | `MSR` | `88db63c328c3cba39971f3942509cb0b582502bc` | #1989 |

## Implementation evidence

- Registry: `projects/PORTFOLIO.json`
- Policy: `projects/PROJECT_ID_POLICY.md`
- Human portfolio index: `projects/README.md`
- Validator: `scripts/check-project-portfolio.py`
- CI gate: `.github/workflows/project-portfolio-governance.yml`
- Project metadata: all current `projects/*/PROJECT.yaml` files.
- Root enforcement: `AGENTS.md` global Project ID allocation gate.
- Governance enforcement: `.agent/skills/fabushi-project-governance/SKILL.md` plus project-folder/task-lifecycle references.

## Pull request and CI evidence

- Implementation PR: `#1996` — `feat(governance): establish immutable global project IDs`.
- Final PR head used for the successful validation round: `a50dd46b2bedf152356c14ac195021ffc9443013`.
- `Project portfolio governance` run `32561929188`:
  - job `Validate immutable Project IDs` — success;
  - checkout history — success;
  - baseline registry materialization — success;
  - registry/project metadata validation — success.
- Repository `CI` run `32561929208` — success:
  - Classify CI changes — success;
  - Frontend checks — success;
  - Worker checks — success;
  - Electron Feature Host contract — success;
  - MCP plugin contracts — success;
  - Canonical architecture guardrails — success;
  - final `CI result` — success.
- Explicit automerge run `32561929220` — success.
- A direct merge attempt after checks returned `Pull Request is in the merge queue`, proving the PR was routed through the protected merge queue rather than bypassing it.
- PR #1996 merged at `2026-08-22T08:21:57Z`.
- Canonical merge commit: `87462b14017b08f0f4dcd6f97fbea67b5c12d791`.

## Canonical `main` verification

Post-merge reads from GitHub `main` confirmed:

1. `projects/PORTFOLIO.json` contains exactly the five migrated canonical projects with unique `FAB-P0001`–`FAB-P0005` identities and `next_sequence=6`.
2. `projects/telegram-fabushi-integration/PROJECT.yaml` = `FAB-P0001 / TFI`.
3. `projects/fabushi-project-governance/PROJECT.yaml` = `FAB-P0002 / FPG`.
4. `projects/fabushi-cicd-merge-governance/PROJECT.yaml` = `FAB-P0003 / FCM`.
5. `projects/grok-bot-fabushi-integration/PROJECT.yaml` = `FAB-P0004 / GBF`.
6. `projects/mahayana-sovereign-runtime/PROJECT.yaml` = `FAB-P0005 / MSR`.
7. Root `AGENTS.md` requires every new independent project to re-read the live registry, allocate exactly the current `next_sequence`, update the registry, and create matching project metadata atomically.
8. `.github/workflows/project-portfolio-governance.yml` is present on `main` and enforces the validator for relevant project/governance changes.

## Acceptance result

All FPG-004 required acceptance criteria passed. The portfolio identity system is implemented, automated, protected by CI/merge governance, and verified on canonical `main`.

## Next allocation note

`FAB-P0006` is the current next candidate according to the verified registry high-water mark. It is **not reserved**. A future genuinely independent project must re-read canonical `main` immediately before allocation and use whatever `next_sequence` is live at that time.
