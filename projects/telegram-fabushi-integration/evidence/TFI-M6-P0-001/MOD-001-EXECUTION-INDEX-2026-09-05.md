# TFI-M6-P0-001 MOD-001 execution evidence index — 2026-09-05

- Architecture diagnosis: `MOD-001-ARCHITECTURE-DIAGNOSIS-2026-09-05.md` (PR #2330 exact `9f03b5b1e4b823a226e60bf3c791d6d6301c5521`).
- Architecture handoff: `MOD-001-ARCHITECTURE-HANDOFF-2026-09-05.md` (same architecture head).
- Execution evidence: `MOD-001-EXECUTION-2026-09-05.md`.
- Source commits: `a058b3adba5e20fccd19af06398cca19b8987074`, `460d08b380b1b9dca5bdab4d37c75f5cb83f1fc1`.
- First formatting evidence: Mahayana `33902616051` / `101119986549`.
- Source-head verification: Atomic `33902885775` / `101120859973` SUCCESS; Product `33902885769`, Electron `101120860132` SUCCESS, Rust `101120860382` FAILURE after target M6 contract passes; Mahayana `33902885757` / `101120860421`; Developer Fiat `33902885756` SUCCESS; Explicit automerge `33902885785` SUCCESS.
- New semantic blocker: `tests/unread_projection_contract.rs::conversation_management_enforces_owner_admin_boundaries_and_removal` -> `Engine(CommunityNotFound(ConversationId("group:management-contract")))`.
- Classification: `NEW-SEMANTIC-FAILURE / EXECUTION-MOD-BLOCKED`.
