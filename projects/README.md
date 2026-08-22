# Fabushi Project Portfolio

Canonical machine registry: [`PORTFOLIO.json`](./PORTFOLIO.json)  
Identity policy: [`PROJECT_ID_POLICY.md`](./PROJECT_ID_POLICY.md)

| Project ID | Project Key | Project | Canonical path | First formal main commit |
|---|---|---|---|---|
| `FAB-P0001` | `TFI` | Fabushi Telegram 全量融合 | `projects/telegram-fabushi-integration/` | `99cd4b227a34b49fc04c3265c1dfdee585344160` |
| `FAB-P0002` | `FPG` | Fabushi Project Governance | `projects/fabushi-project-governance/` | `eaf273dafc140619b06b46a4d7d234997acde05d` |
| `FAB-P0003` | `FCM` | Fabushi CI/CD & Merge Governance | `projects/fabushi-cicd-merge-governance/` | `ac94b40d4a05a0211146c2bb5904aa936a7bc928` |
| `FAB-P0004` | `GBF` | Grok Bot -> Fabushi 全量能力与源码融合 | `projects/grok-bot-fabushi-integration/` | `6d1e9cd7a475e8058d5d8512f5c3a0c21da8ed9c` |
| `FAB-P0005` | `MSR` | Mahayana Sovereign Runtime | `projects/mahayana-sovereign-runtime/` | `88db63c328c3cba39971f3942509cb0b582502bc` |

## Next Project ID

The registry high-water mark is authoritative. At this migration baseline the next allocatable ID is:

`FAB-P0006`

Do not reserve or allocate it from chat memory. Always re-read `PORTFOLIO.json` on canonical `main` immediately before creating a new independent project.

## Identifier semantics

- `FAB-Pxxxx`: immutable portfolio Project ID across all Fabushi projects.
- Project Key (`TFI`, `FPG`, `FCM`, `GBF`, `MSR`, ...): mnemonic namespace for requirements/tasks/milestones.
- Task IDs (`MSR-103`, `FPG-004`, ...): project-internal work identifiers; they are not portfolio Project IDs.

Project IDs are never reused, even after archive, cancellation, consolidation, split, or rename.
