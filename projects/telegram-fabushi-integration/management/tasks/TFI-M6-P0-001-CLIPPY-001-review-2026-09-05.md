# TFI-M6-P0-001-CLIPPY-001 独立代码复审记录 — 2026-09-05

- Project: `FAB-P0001 / TFI`
- Task ID: `TFI-M6-P0-001-CLIPPY-001`
- Review ID: `TFI-M6-P0-001-CLIPPY-001-REVIEW-001`
- Review status: `REVIEW-PASS-CLIPPY-001`
- Reviewed execution exact head: `1c314ef514f71e5a1320ddea0803078923a4858c`
- Audited execution base: `9e88a2e9c030fe05147460dfa580366cf9aa433d`
- CLIPPY execution start: `373bc52ad1cc2052c32acd81be4606c0a18dd89b`
- Architecture records-only PR/head: `#2332` / `abf740153ef6ee5962c6da24f67b68a8b7f26f63`
- Production fix commit: `90d337e8d04ce8c463c7228cac1053158f8268ed`
- Same-scope rustfmt commit: `0899258257e2efb8c24bb7fa951f4ae6180bbb10`
- Architecture handoff comment: `#2323` comment `5545043051`
- Execution handoff comment: `#2323` comment `5545254387`
- Reviewer branch: `review/tfi-m6-p0-001-clippy-001-independent-20260905`

## Review scope

This is an independent review and evidence-only task. It does not implement application code, alter tests/workflows/Cargo/dependencies, merge any PR, run or replace packaged E2E, test-release, or formal release.

The review isolates the CLIPPY execution delta as:

`373bc52ad1cc2052c32acd81be4606c0a18dd89b..1c314ef514f71e5a1320ddea0803078923a4858c`

GitHub compare reports exactly 4 commits and 6 changed files:

1. `native/mahayana-messaging/src/engine.rs`
2. `native/mahayana-messaging/src/service.rs`
3. `projects/telegram-fabushi-integration/management/tasks/TFI-M6-P0-001-CLIPPY-001-execution-2026-09-05.md`
4. `projects/telegram-fabushi-integration/evidence/TFI-M6-P0-001/CLIPPY-001-EXECUTION-2026-09-05.md`
5. `projects/telegram-fabushi-integration/management/50-2026-09-05-P0-CLIPPY-001-执行状态与验收.md`
6. `projects/telegram-fabushi-integration/management/51-2026-09-05-P0-CLIPPY-001-执行变更日志.md`

The architecture records-only PR `#2332` and historical FMT/MOD/UNREAD changes are not counted as CLIPPY execution changes.

## `engine.rs` semantic review — PASS

The production delta removes only the private, never-constructed `CommunityAdminAction::PostMessages` selector and the corresponding `require_community_admin` mapping arm. The remaining selector set and mappings are unchanged.

The live authorization contract is preserved. `AdminRights.post_messages` remains defined, and channel sending still rejects an administrator without `member.admin_rights.post_messages` using the existing authorization path. The review found no `allow`, `expect`, dummy construction, publicization, workflow change, lint suppression, or lint-gate weakening in the CLIPPY delta.

## `service.rs` semantic review — PASS

For Community-backed `RemoveConversationParticipant`, the implementation rewrites the Clippy-reported nested condition into a match guard without changing the checked values or failure path. The following are preserved exactly:

- target member lookup via `community.members.get(target_actor_id)`;
- protected statuses `MemberStatus::Owner | MemberStatus::Administrator`;
- the `!caller_is_owner` condition;
- error text `admins cannot remove owner/admin members`;
- the location of this validation before the removal command/event path;
- fallback behavior for all other actions.

The follow-up commit `0899258257e2efb8c24bb7fa951f4ae6180bbb10` only applies the rustfmt line layout requested by the failed formatting iteration and does not add a third semantic change.

## Open-source-first evidence

The repair matches official Rust/Clippy guidance and does not suppress the lints:

- Rust `dead_code` lint: <https://doc.rust-lang.org/rustc/lints/listing/warn-by-default.html#dead-code>
- Clippy `collapsible_match`: <https://rust-lang.github.io/rust-clippy/master/index.html#collapsible_match>
- Rust Reference match guards: <https://doc.rust-lang.org/reference/expressions/match-expr.html#match-guards>
- Clippy CI guidance: <https://doc.rust-lang.org/clippy/continuous_integration/index.html>

Removing a dead private selector and using an equivalent match guard are smaller and more maintainable than `allow`/`expect` suppression.

## Exact-head CI evidence

All task-relevant successful runs were checked against the final execution head, including raw job logs where applicable. The PR merge ref used by the final runs is `9b31dbf8393517374a301e0b2d5f190283a95a16`, whose log identity is `Merge 1c314ef514f71e5a1320ddea0803078923a4858c into 9e88a2e9c030fe05147460dfa580366cf9aa433d`.

| Workflow | Run | Job(s) | Review result |
| --- | --- | --- | --- |
| Mahayana fast checks | `33908826737` | `101140150034` | PASS |
| Messaging Product Gate | `33908826692` | Electron `101140149849`; Rust `101140150096` | PASS |
| TFI M6 P0-001 atomic gate | `33908826775` | `101140150126` | PASS |
| Developer Fiat Commerce | `33908826638` | `101140149713`, `101140149752`, `101140149774`, `101140149815`, `101140149917` | 5/5 PASS |
| Explicit automerge | `33908826736` | `101140150279` | workflow/job SUCCESS; intentional no-op because PR lacks `automerge` label |

The Product Rust job actually executed and passed rustfmt, `cargo test --all-targets`, unread 4/4, M6 5/5, messaging Clippy with `-D warnings`, deterministic media tests, media Clippy with `-D warnings`, and the production Feature Host/bridge/contact projection test set. The Electron job passed. No task-required project check or job was skipped. Platform-internal action substeps such as the Windows rustup installer are conditionally skipped on Linux and are not task gates.

No local build/test was used as a substitute for these GitHub Actions results.

For historical causality, the pre-fix Product Rust failure `33905958987 / 101131173899` failed exactly on the dead private selector and `clippy::collapsible_match`; the later formatting-only failure `33908703028 / 101139744051` showed only the `service.rs` rustfmt layout that `0899258257e2efb8c24bb7fa951f4ae6180bbb10` corrected.

## Risk and gate decision

The touched code is authorization-sensitive, so the principal risk is accidental permission broadening. Exact diff review found no such broadening: the live `post_messages` check remains, and the participant-removal guard is semantically equivalent.

Decision: `REVIEW-PASS-CLIPPY-001`.

This permits progression to the **MERGE gate only**. No merge is performed by this review. Before release, the protected canonical `main` merge/readback must succeed; then the test-release group must run an exact-main packaged build plus simulated-user E2E and preserve complete video, key screenshots, trace/report/log evidence. The video/evidence must be reviewed, and only after those gates pass may the formal release group publish.

The reviewer PR number and its final records-only head are intentionally bound in the `#2323` review handoff comment after the reviewer PR is created, avoiding recursive self-reference in this commit.