# 58 — 2026-09-05 M6 protected-main-safe recovery acceptance

## Architecture acceptance
- canonical main/base/head and exact ancestry are read from GitHub, not inferred from summaries;
- parent 12 commits and child 22 commits remain distinguishable;
- no parent review is inferred from P0/FMT/MOD/UNREAD/CLIPPY child review evidence;
- no retarget/direct merge/rebase/force-push/bypass is performed;
- architecture PR changes only `projects/telegram-fabushi-integration/**`.

## Per-product-task acceptance
Every task 001-003 must independently satisfy all of:
1. start from the then-current exact canonical main;
2. remain inside its frozen product/test allowlist;
3. record immutable source-commit provenance and duplicate/equivalence check;
4. fresh independent code-review PASS on the exact main-based diff;
5. all current required GitHub Actions PASS on exact head, including repository `CI result`;
6. protected merge queue acceptance without bypass;
7. exact accepted canonical-main readback before the dependent task begins.

## Global completion acceptance
- all intended parent/P0 semantics are either accepted on main or proven already equivalent;
- temporary atomic workflow from #2323 is absent from the recovery product path;
- #2323 is not treated as merged merely because its historical child checks were green;
- test-release remains blocked until all main-safe layers close.