# TFI-M6-MAINSAFE-001 VERSION-BOOTSTRAP independent review evidence — 2026-09-05

## Terminal review marker

`REVIEW-FAIL-VERSION-BOOTSTRAP-001`

Reviewed object: product PR `#2343`, exact base `dbf22b467d35c8af2a074896c355a41993c8c191`, exact product head `bf62cd9769cc24ae29fcf03c16a1f662bc7019aa`.

## Repository / provenance readback

- canonical `main` re-read: `dbf22b467d35c8af2a074896c355a41993c8c191`;
- #2343: OPEN / UNMERGED, 2 commits, 14 changed files;
- product/bootstrap commit: `496ddefc0866f2d0568d0c3d618cfcede2e6c98c`, parent exact canonical base;
- execution-record/final head: `bf62cd9769cc24ae29fcf03c16a1f662bc7019aa`, parent product/bootstrap commit;
- #2341 remains OPEN / UNMERGED at `2241c856fb3da498ac99ade89007fe01dd335183`;
- #2342 remains OPEN / UNMERGED at `570b874318bfe42406c6f46f51798baed8c89e48`;
- #2340 remains OPEN / UNMERGED at `7d0325ae324f295847b1f6a6dd7bec30ae959c73` and is architecture provenance only;
- active ruleset `15857448` requires `CI result`, uses ALLGREEN squash merge queue, and has no bypass actor.

## Diff / semantic review

### `.github/workflows/ci.yml`

Observed additions are narrowly scoped:

- unconditional `canonical-version-contract` job named `Canonical version contract`;
- read-only checkout of the canonical assertion's direct inputs;
- exact command `bash .github/scripts/assert-native-electron-canonical.sh`;
- `canonical-version-contract` added to `ci-result.needs`;
- aggregate explicitly rejects anything except `needs.canonical-version-contract.result == success`;
- existing `pull_request`, `merge_group`, `push`, `workflow_dispatch`, permissions, classifier and existing selected-domain jobs are preserved.

No inline duplicate version comparison was added. No special skip/neutral exemption or ruleset relaxation exists. Static propagation design is acceptable.

### `mobile/ios/project.yml`

The only semantic change is `CURRENT_PROJECT_VERSION: 28 -> 29`. `MARKETING_VERSION` stays `1.2.22`. Live `app-version.json` remains unchanged at `version=1.2.22`, `androidVersionCode=29`, `iosBuildNumber=29`.

### Other changed paths

All remaining changed paths are task-specific records under `projects/telegram-fabushi-integration/**`. There is no changed `app-version.json`, canonical assertion script, other workflow, Android/Electron/application/test source, Cargo/dependency, release logic, root AGENTS, or portfolio registry.

## Live Actions evidence

All automatic workflow runs attached by GitHub metadata to exact product head `bf62cd9769cc24ae29fcf03c16a1f662bc7019aa` are completed:

- CI run `33930830358`: SUCCESS, attempt 1, event `pull_request`;
- Project portfolio governance `33930830262`: SUCCESS, attempt 1;
- Developer Fiat Commerce `33930830444`: SUCCESS, attempt 1;
- Explicit automerge `33930830191`: SUCCESS, attempt 1;
- Native mobile quality gate `33930830217`: SUCCESS, attempt 1;
- Computer control security gate `33930830313`: SUCCESS, attempt 1;
- current exact-product-head in-progress check query: `total_count=0`.

Selected CI jobs all conclude SUCCESS:

- `101208897129` Classify CI changes;
- `101208897330` Canonical version contract;
- `101208917493` Canonical architecture guardrails;
- `101208917496` Worker checks;
- `101208917520` Frontend checks;
- `101208917532` MCP plugin contracts;
- `101208917551` Electron Feature Host contract;
- `101209082820` CI result.

`CI result` raw log proves `version_contract_result="success"` and its aggregate step succeeded.

Computer-control run `33930830313` has nine top-level jobs and all are SUCCESS, including both `rust-contracts (macos-latest)` and `rust-contracts (windows-latest)` plus final `Computer control security result`.

Native mobile run `33930830217` has `Native Android` SUCCESS and `Native mobile result` SUCCESS; expected PR-fast-path heavyweight inner steps are skipped by existing workflow policy and are not being treated as canonical-version evidence.

## Blocking raw-log fact

The canonical child job status is green, but its downloaded raw log demonstrates that the authoritative script did **not** execute on the exact product commit.

Relevant log sequence:

- the checkout action fetched `+265ceea6496b21ffdbd53d4fa8fc0b3374edd3ac:refs/remotes/pull/2343/merge`;
- it checked out `refs/remotes/pull/2343/merge`;
- it printed `HEAD is now at 265ceea Merge bf62cd9769cc24ae29fcf03c16a1f662bc7019aa into dbf22b467d35c8af2a074896c355a41993c8c191`;
- `git log -1 --format=%H` returned `265ceea6496b21ffdbd53d4fa8fc0b3374edd3ac`;
- only then did `Run bash .github/scripts/assert-native-electron-canonical.sh` execute and return success.

GitHub PR metadata independently reports `merge_commit_sha=265ceea6496b21ffdbd53d4fa8fc0b3374edd3ac`, confirming that value is the synthetic PR merge commit, not the final product head `bf62cd9769cc24ae29fcf03c16a1f662bc7019aa`.

This directly conflicts with the frozen exact-head acceptance and the #2343 PR body statement that `Canonical version contract` must actually execute the script “on that exact head” and that historical/different-SHA green results are not reused. It also contradicts execution handoff comment `5547838312`, which says no different-SHA evidence was used.

GitHub's official Actions semantics explain the mechanism: open `pull_request` workflows use the PR merge ref / merge commit as the default checkout target; the PR head commit is separately exposed through `github.event.pull_request.head.sha`. The review does not prescribe or implement a code change, but the current evidence cannot be truthfully labeled exact-product-head script execution.

## Review disposition

Static implementation/config scope: acceptable.

Dynamic frozen acceptance: failed.

Terminal review: `REVIEW-FAIL-VERSION-BOOTSTRAP-001`.

Protected canonical-main MERGE gate is not authorized. No test release or stable release may begin from this review. The defect must return to the appropriate architecture/execution path, obtain a new exact-head implementation/evidence result, and undergo a fresh independent review.

## Future gate order after a future PASS

Only after a future independent review passes:

1. test-release group advances the accepted product PR through protected canonical-main merge queue and reads back exact canonical main;
2. test-release group executes packaged build + simulated-user E2E against exact canonical main and retains complete video, key screenshots, trace/report/log;
3. evidence returns to code review for content verification;
4. stable release follows only after that later review passes.
