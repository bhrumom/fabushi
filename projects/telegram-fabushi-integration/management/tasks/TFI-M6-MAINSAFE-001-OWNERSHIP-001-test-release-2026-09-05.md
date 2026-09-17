# TFI-M6-MAINSAFE-001-OWNERSHIP-001 — protected merge / exact-main test-release task

- Project: FAB-P0001 / TFI
- Session role: test release only
- Local record date: 2026-09-05 (+08:00)
- Product PR: #2336
- Reviewed product head: `8760b7587f6d576262e5993a72b5c5112ff595db`
- Product base before merge: canonical `main@688465e94647d4c866f6b1d7b4884145b2f4a9da`
- Review handoff: #2336 issue comment `5546493085`, verdict `REVIEW-PASS-OWNERSHIP-001`
- Reviewer records-only PR: #2338, base `8760b7587f6d576262e5993a72b5c5112ff595db`, head `0978409518bb7cd3e173fd275b3569d3611e0508`, intentionally open/unmerged
- Architecture records-only PR: #2337, head `ea9b5b62d22ed73b9de350075797ea4c54eb69e4`, intentionally open/unmerged

## Scope and non-goals

This test-release round was authorized to:

1. advance only reviewed product PR #2336 through the repository's protected canonical-main merge queue;
2. read back the exact accepted canonical-main SHA;
3. consume GitHub-hosted exact-main packaged / simulated-user workflows;
4. create a traceable test/pre-release only if every required packaged/E2E/evidence gate passed;
5. write only `projects/telegram-fabushi-integration/**` records.

It was not authorized to rebase, retarget, force-push, bypass protection, merge #2338/#2337 as product code, modify application/workflow/version configuration, perform local builds/tests/packages, or publish a stable release.

## Protected-main result

`main-merge-queue` ruleset id `15857448` applied to `refs/heads/main` and required merge queue `SQUASH + ALLGREEN` with required status `CI result`; no user bypass was available.

Only #2336 received the repository's `automerge` label. Explicit automerge run `33920248647`, job `101176673378`, enqueued the reviewed head through the repository workflow. GitHub created queue ref `gh-readonly-queue/main/pr-2336-688465e94647d4c866f6b1d7b4884145b2f4a9da` and merge-group SHA `dbf22b467d35c8af2a074896c355a41993c8c191`.

Protected merge-group verification:

- canonical CI run: `33920323994`
- required job: `101177336627` / `CI result` — SUCCESS
- merge-queue fallback run: `33920289602`
- fallback required job: `101176799668` / `CI result` — SUCCESS

PR #2336 merged at `2026-09-04T21:18:43Z` (`2026-09-05T05:18:43+08:00`). GitHub canonical `main` was read back after merge and resolved to exactly:

`dbf22b467d35c8af2a074896c355a41993c8c191`

## Exact-main acceptance result

Final state: **TEST-FAILED / PACKAGED-BLOCKED**.

No test tag, GitHub test/pre-release, updater publication, or stable release was created.

Reasons:

1. Electron desktop exact-main Linux job `101177474099` failed before packaging/E2E because canonical version guard reported `iOS build number drift: canonical=29 project=28`. Accepted-main `app-version.json` declares iOS build 29 while `mobile/ios/project.yml` declares `CURRENT_PROJECT_VERSION: 28`. Fixing this requires product/version configuration changes outside this records-only session.
2. Native iOS exact-main job `101177474816` reached real SwiftUI unit + simulated-user UI tests and failed `testAccountSettingsAndMessagingFlow()` at `mobile/ios/FabushiUITests/FabushiUITests.swift:97`: expected `Messenger`, observed `Messaging unavailable`. Five tests ran with one failure.
3. Requested release-evidence contract is not fully met by the existing workflows: Linux produced no package/video/trace/report because it failed before packaging; generic Playwright config uses screenshots only on failure; the available full video observed in desktop diagnostics is Grok visual evidence rather than an ownership-specific full messaging journey; child evidence names do not encode exact main SHA/platform/run/job/journey/timestamp as requested; native artifacts are retained 14 days rather than the requested 90-day target.
4. The passing packaged desktop journeys do not, by themselves, prove the whole ownership acceptance set (send + subscribe/unsubscribe + community join approval + unread projection) as one explicit packaged ownership-targeted journey.

## Gate policy decision

The macOS/Windows packaged successes, Android success, and Messaging Product Gate success are retained as failed-round collateral evidence only. They cannot waive the Linux required packaged failure, the native iOS behavioral failure, or the missing evidence contract.

Therefore this round stops before test-version delivery and before video-evidence review handoff.

## Single next action

An authorized execution/config owner must create a separate reviewed product/config/workflow PR from current canonical main that resolves both observed product/config blockers and, where workflow changes are required, closes the evidence-contract gap:

- synchronize canonical iOS build number (`29`) with the generated iOS project version;
- repair the iOS simulated-user messaging surface so `testAccountSettingsAndMessagingFlow()` sees `Messenger` instead of `Messaging unavailable`;
- ensure the required packaged ownership journey captures per-step screenshots, complete video, trace/report/log with exact-SHA/platform/run/job/journey/time naming and repository-permitted retention.

After normal independent code review and protected-main merge of that separate fix, a **new** test-release session must lock the new accepted canonical-main SHA and rerun all exact-main packaged/native acceptance from scratch.