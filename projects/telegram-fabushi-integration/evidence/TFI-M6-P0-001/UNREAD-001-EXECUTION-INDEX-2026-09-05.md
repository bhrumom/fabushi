# UNREAD-001 execution evidence index — 2026-09-05

- Authority: `TFI-M6-P0-001-UNREAD-001`, architecture PR `#2331@a5850f12ebef51a9862e8a466eb79f00af224491`, handoff comment `5544693181`.
- Execution starting head: `#2323@553c5efd5a6119298d0a0da8512a1ac931fcc61c`.
- Semantic fixture commit: `7d158e1742b2d9e56d101c90d3d81408dcd41947`.
- Primary evidence: `projects/telegram-fabushi-integration/evidence/TFI-M6-P0-001/UNREAD-001-EXECUTION-2026-09-05.md`.
- Semantic-head Product Gate: run `33905736673`; Rust job `101130104184`; Electron job `101130104372`.
- Proven PASS before stop: rustfmt; all-targets tests; `unread_projection_contract` 4/4; MOD continuity `m6_channels_topics_contract` 5/5; Electron; TFI Atomic; Developer Fiat Commerce; Explicit automerge.
- Deterministic new blocker after target PASS: messaging clippy at `src/engine.rs:597` (`dead_code`) and `src/service.rs:684` (`collapsible_match`), both outside frozen UNREAD-001 scope. Media/media-clippy/Feature-Host steps were skipped downstream.
- Classification: `EXECUTION-UNREAD-BLOCKED / NEW-SEMANTIC-FAILURE / SCOPE-EXPANSION-REQUIRED / CI-BLOCKED / CLOSURE-BLOCKED`.
- Required next owner: architecture group. No fresh code-review request is permitted while required CI is red.
