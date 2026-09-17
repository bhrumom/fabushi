# FCM-023 — Test-first all-platform release and MCP-only formal validation

- Project ID: `FAB-P0003`
- Project Key: `FCM`
- Task ID: `FCM-023`
- Started: `2026-09-16`
- Updated: `2026-09-16`
- Status: `in-progress`

## Objective

Replace the historical automatic/post-main E2E release model with the latest user-requested fast release model: merge accepted PRs, publish an all-platform test release without behavioral testing, then for a formal candidate manually start GitHub Actions runners whose installed Fabushi Apps self-register controllable devices and perform behavioral acceptance only through the Fabushi official MCP.

## In scope

- Persist the new policy in root `AGENTS.md` and FCM source-of-truth records.
- Preserve prior root instructions verbatim as `AGENTS.legacy.md`; supersede only conflicting test/release rules.
- Remove behavioral-test requirements from test-tier source gating.
- Disable the automatic post-main E2E delivery chain and release-to-interactive auto chain.
- Keep manual/App-owned runner capability as the formal-validation direction.
- Merge all currently mergeable open PRs as requested; record those blocked by GitHub mergeability/protection/conflicts instead of claiming success.
- Publish a strictly newer all-platform test release from accepted canonical main without product tests where the available Actions interfaces permit it.
- Before stable publication, require successful Fabushi-official-MCP device control; no fallback to autonomous E2E.

## Out of scope

- Bypassing GitHub authentication/branch protection that the active installation does not permit.
- Claiming MCP validation when the official MCP account connection fails or a device is absent.
- Real-money purchases, passwords or OTP entry during device testing.

## Acceptance criteria

1. `AGENTS.md` contains the no-test test-release rule, manual-only E2E rule, Action-runner/App-owned device rule and Fabushi-official-MCP-only formal test rule.
2. FCM `SOURCE_OF_TRUTH.md` points to the 2026-09-16 requirement as latest authority.
3. Test-tier `require-release-source-gates.sh` requires only exact protected-main ancestry/provenance and no behavioral-test check.
4. Historical automatic `Post-main E2E Release delivery` no longer auto-starts from main/Electron completion.
5. Historical automatic macOS test-release→interactive chain no longer starts from `workflow_run`.
6. Any remaining platform interactive E2E is manual-only before it may be used as formal validation; test release itself does not dispatch it.
7. Open PRs are actually merged where GitHub permits; failures remain explicit blockers.
8. A new all-platform test release is actually dispatched/published without behavioral tests, or the exact control-plane blocker is recorded.
9. Stable release is published only after Fabushi official MCP controls the exact candidate device(s) successfully; if MCP is unavailable, stable remains blocked.

## Verification method

- Canonical GitHub readback of changed files and PR merge states.
- GitHub Actions/release run evidence for test publication.
- Fabushi official MCP `list_devices`/device control/finish evidence for formal acceptance.
- No local build/test.

## Open-source survey

This is governance/release orchestration over existing repository-owned workflows and the existing App-owned MCP control path; no new custom test framework is introduced. Existing GitHub Actions `workflow_dispatch` manual trigger semantics and the repository's existing interactive runner/App-owned device architecture are reused.

## Branch / PR

- Branch: `project/fcm-023-mcp-release-policy-20260916`
- PR: pending at task creation.

## Current evidence / blockers

- Existing `interactive-runner-mcp.yml` already launches an installed packaged Fabushi App with `FABUSHI_E2E=0`, waits for the App-owned controllable device and an external finish signal; this is the target architecture to retain.
- At task start, Fabushi official MCP account/device calls return a connection-layer HTTP 400, so formal MCP validation is currently blocked and must not be claimed as passed.
- Open PR set contains historical stacked/records-only/draft/product PRs; each merge must be attempted against live GitHub rather than inferred from descriptions.

## Next action

Merge this policy change, re-read canonical main/open PRs, publish the no-test all-platform test candidate, then retry Fabushi official MCP and only proceed to stable publication after exact-candidate MCP validation succeeds.