# 61 — 2026-09-05 M6 protected-main-safe parent-stack change log

- Re-read canonical main, #2323/#2332/#2333/#2334, active main ruleset and #2323 review/test-release handoffs.
- Reconstructed `main -> base` as 12 commits and `base -> #2323 head` as 22 commits; verified the exact parent chain with Git `parents[]` pointers.
- Confirmed no independent PR exists with `codex/tfi-m6-repair` as head and that parent task `TFI-M6-CHANNELS-001` is absent from canonical main and remains `IN_PROGRESS / PR pending / CI pending` on the historical branch.
- Classified prior P0/FMT/MOD/UNREAD/CLIPPY evidence as child-stack evidence only, not parent-stack acceptance.
- Rejected retarget/direct merge/bypass/blind cherry-pick/rebase-force-push/catch-all merge-base PR.
- Adopted fresh canonical-main-based semantic reconstruction with immutable old-SHA provenance and duplicate-patch guards.
- Created atomic recovery tasks `TFI-M6-MAINSAFE-001-RUST-CANONICAL`, `002-ELECTRON-PROJECTION`, `003-P0-CREATE-JOIN` with strict sequential dependency, allowlists, Actions/review/queue gates and stop rules.
- Preserved test-release blocker #2334 as authoritative history; no product/test/workflow/Cargo/dependency/version files were modified by architecture.