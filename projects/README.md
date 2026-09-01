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
| `FAB-P0006` | `FAM` | Fabushi Always-on Marketing | `projects/fabushi-always-on-marketing/` | `173e7f793987b6d0a9303b55e2060e2584552da9` |
| `FAB-P0007` | `DHRF` | DeepSeek Harness Rust Fusion | `projects/deepseek-harness-rust-fusion/` | `11fd9d32d5b7edf09882ff5308be55b566e1a6d4` |
| `FAB-P0008` | `AAC` | Fabushi Account Access Control | `projects/fabushi-account-access-control/` | `52b7c10889e585660b7d2a22a40781c22f31b7a1` |
| `FAB-P0009` | `RDF` | RustDesk -> Fabushi 核心能力融合 | `projects/rustdesk-fabushi-fusion/` | `d69bf418ed19df6ec7f1d0581646283a49461ba7` |

## Next Project ID

The registry high-water mark is authoritative. The next allocatable ID is `FAB-P0010`.
Always re-read `PORTFOLIO.json` on canonical `main` immediately before allocating it.

## Identifier semantics

- `FAB-Pxxxx`: immutable portfolio Project ID.
- Project Key: stable mnemonic requirement/task namespace.
- Task IDs: project-internal work identities; they are not portfolio Project IDs.

Project IDs are never reused.
