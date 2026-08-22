# Owners

## Product ownership

- Product: Fabushi Telegram-class self-hosted messaging integration
- Repository: `bhrumom/fabushi`
- Authoritative branch: `main`
- Authoritative project path: `projects/telegram-fabushi-integration/`

## Ownership model

| Area | Accountable owner | Working boundary |
|---|---|---|
| Product scope / acceptance | Fabushi product owner | `source/`, PRD, roadmap, acceptance matrix |
| Messaging architecture | Fabushi maintainers | `native/mahayana-messaging/`, protocol and state machine |
| Product Host integration | Mahayana maintainers | `third_party/mahayana/mahayana-rs/` Host/Feature Host boundaries |
| Desktop Messenger | Fabushi desktop maintainers | `desktop/` Electron Messenger V2 and native edge |
| iOS / Android integration | Fabushi native maintainers | native clients consuming the shared Rust messaging contract |
| CI / release evidence | Fabushi repository maintainers | `.github/workflows/`, merge queue and release evidence |
| Project record | Task owner for each active WBS item | this project folder, updated before task closure |

## Rules

- New communication business logic belongs to the canonical `native/mahayana-messaging/` domain unless an ADR explicitly changes that decision.
- Legacy Telegram runtime/provider paths are migration-only and must not receive new product features.
- Every active task must name its WBS/task ID in the PR and keep evidence in this project folder.
- A task is not complete until required CI is green, protected-branch merge completes, and canonical `main` is re-verified.
