# Evidence index — FAB-ARCH-P0-20260904 / TFI

This directory records architecture evidence only. It is **not** implementation/test/release evidence.

Verified GitHub facts on 2026-09-04:
- canonical main: `688465e94647d4c866f6b1d7b4884145b2f4a9da`
- audited repair branch: `codex/tfi-m6-repair@9e88a2e9c030fe05147460dfa580366cf9aa433d`
- compare: ahead 12, behind 0
- branch changes span Rust messaging core/protocol/service, Electron consumer, M6 contract tests and TFI records.
- `RespondCommunityJoin` type-shape blocker and Community-aware create gap were directly re-read from branch files.

Future execution evidence belongs under each task-specific evidence directory and must retain both pass and fail videos/screenshots/traces/reports/logs per root `AGENTS.md`.