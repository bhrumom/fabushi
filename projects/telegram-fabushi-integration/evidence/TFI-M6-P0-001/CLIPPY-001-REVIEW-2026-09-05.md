# CLIPPY-001 independent review evidence — 2026-09-05

- Project: `FAB-P0001 / TFI`
- Task ID: `TFI-M6-P0-001-CLIPPY-001`
- Review ID: `TFI-M6-P0-001-CLIPPY-001-REVIEW-001`
- Verdict: `REVIEW-PASS-CLIPPY-001`
- Execution PR: `#2323`
- Reviewed execution exact head: `1c314ef514f71e5a1320ddea0803078923a4858c`
- Audited base: `9e88a2e9c030fe05147460dfa580366cf9aa433d`
- CLIPPY delta start: `373bc52ad1cc2052c32acd81be4606c0a18dd89b`
- Production fix: `90d337e8d04ce8c463c7228cac1053158f8268ed`
- Formatting-only follow-up: `0899258257e2efb8c24bb7fa951f4ae6180bbb10`

## Repository and governance facts read

The review read and cross-checked the real repository state at the exact execution head, including root `AGENTS.md`, `projects/PORTFOLIO.json`, TFI `SOURCE_OF_TRUTH.md`, `PROJECT.yaml`, `README.md`, the CLIPPY architecture task and architecture records in PR `#2332`, the execution records added on `#2323`, PR metadata, changed-file lists, commit chain, architecture handoff comment `5545043051`, execution handoff comment `5545254387`, and final Actions run/job logs.

`#2323` is open/unmerged during this review. `#2332` is also open/unmerged and records-only.

## Exact CLIPPY execution delta

GitHub compare `373bc52ad1cc2052c32acd81be4606c0a18dd89b...1c314ef514f71e5a1320ddea0803078923a4858c` returns exactly 4 commits and 6 changed files. Only two are production files:

- `native/mahayana-messaging/src/engine.rs`
- `native/mahayana-messaging/src/service.rs`

The other four are append-only TFI CLIPPY execution/evidence records. No test, workflow, Cargo, dependency, or unrelated source file occurs in this isolated execution delta.

## `engine.rs`

The diff removes private enum variant `CommunityAdminAction::PostMessages` and its matching `require_community_admin` mapping arm. No other selector mapping changes.

Critical authorization semantics were checked in the real file: `AdminRights.post_messages` remains present and channel-send authorization still checks `member.admin_rights.post_messages` before allowing administrator sends. No publicization, dummy construction, `allow`, `expect`, or lint-suppression mechanism was introduced.

Conclusion: minimal dead-selector removal, no permission broadening.

## `service.rs`

The pre-fix form checked a found target member, then matched `Owner | Administrator`, then rejected when `!caller_is_owner`. The post-fix form expresses the same condition as a match guard over `community.members.get(target_actor_id)`.

Preserved facts:

- same target lookup;
- same protected statuses;
- same caller-owner predicate;
- same exact error message: `admins cannot remove owner/admin members`;
- same position before the downstream remove command/event sequence;
- same non-matching fallthrough.

The subsequent `0899258257e2efb8c24bb7fa951f4ae6180bbb10` change is only rustfmt layout.

Conclusion: Clippy-clean control-flow rewrite is semantically equivalent.

## Official/open-source evidence

Official references used for review:

1. Rust dead-code lint: <https://doc.rust-lang.org/rustc/lints/listing/warn-by-default.html#dead-code>
2. Clippy `collapsible_match`: <https://rust-lang.github.io/rust-clippy/master/index.html#collapsible_match>
3. Rust Reference match guards: <https://doc.rust-lang.org/reference/expressions/match-expr.html#match-guards>
4. Clippy CI documentation: <https://doc.rust-lang.org/clippy/continuous_integration/index.html>

The project fix follows these references by removing a private unused selector and rewriting equivalent nested control flow rather than suppressing diagnostics.

## Historical failure provenance

### Pre-fix Product Rust

- run: `33905958987`
- job: `101131173899`
- checked PR merge ref based on CLIPPY starting head
- `cargo test --all-targets`: PASS
- unread suite: 4/4 PASS
- M6 suite: 5/5 PASS
- `cargo clippy ... -- -D warnings`: FAIL
- exact diagnostics: dead `PostMessages` variant and `clippy::collapsible_match`

This independently reproduces the architecture root-cause statement from raw Actions logs.

### Formatting-only intermediate failure

- run: `33908703028`
- job: `101139744051`
- failure showed only a rustfmt layout diff in the same `service.rs` match guard
- `0899258257e2efb8c24bb7fa951f4ae6180bbb10` applies that layout without semantic expansion

## Final exact-head Actions

Final successful runs all correspond to execution head `1c314ef514f71e5a1320ddea0803078923a4858c`. Raw logs show PR merge ref `9b31dbf8393517374a301e0b2d5f190283a95a16` with identity `Merge 1c314ef514f71e5a1320ddea0803078923a4858c into 9e88a2e9c030fe05147460dfa580366cf9aa433d`.

- Mahayana fast checks: run `33908826737`, job `101140150034` — PASS.
- Messaging Product Gate: run `33908826692`.
  - Product Electron job `101140149849` — PASS.
  - Product Rust job `101140150096` — PASS; actual commands include rustfmt, `cargo test --all-targets`, unread 4/4, M6 5/5, messaging Clippy `-D warnings`, deterministic media tests, media Clippy `-D warnings`, production Feature Host bridge/contact projection tests.
- TFI M6 P0-001 atomic gate: run `33908826775`, job `101140150126` — PASS.
- Developer Fiat Commerce: run `33908826638`, five jobs all PASS:
  - `101140149713`
  - `101140149752`
  - `101140149774`
  - `101140149815`
  - `101140149917`
- Explicit automerge: run `33908826736`, job `101140150279` — GitHub workflow/job conclusion `success`, but the job log explicitly says `PR #2323 does not have the automerge label; skipping.` Therefore this is a successful gate execution/no-op, not merge authorization and not a merge.

No task-required project check/job is skipped and no old-head green result is substituted. Linux-only action internals may skip Windows setup substeps; these are not project checks.

## Branch protection / merge gate fact

The active `main-merge-queue` ruleset requires merge queue and status context `CI result`, with no bypass actor. The final PR-head results above are review evidence only. They do not replace canonical-main merge-group revalidation/readback.

## Review decision and residual risk

Verdict: `REVIEW-PASS-CLIPPY-001`.

No review finding was identified in semantics, execution scope, or CI evidence. Authorization-sensitive code remains the main residual risk category, but the exact diff preserves the live `post_messages` check and owner/admin removal protection.

Allowed next stage: **MERGE gate only**. The review does not merge anything.

Mandatory later gates remain: protected canonical `main` merge/readback; exact-main packaged build; simulated-user E2E by the test-release group; complete video, key screenshots, trace/report/log evidence; review-group video/evidence readback; only then formal release.