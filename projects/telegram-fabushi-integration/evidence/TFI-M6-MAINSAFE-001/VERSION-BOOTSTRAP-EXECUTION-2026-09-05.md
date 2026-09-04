# TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001 execution evidence — 2026-09-05

## Identity

- Project: `FAB-P0001 / TFI`
- Atomic task: `TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001`
- Requirement / acceptance: `M6-PM-VB-R01` / `M6-PM-VB-A01`
- Canonical base read back immediately before execution: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Replacement branch: `fix/tfi-m6-mainsafe-001-version-bootstrap-001`
- Replacement PR: `#2343`
- Initial product/bootstrap commit: `496ddefc0866f2d0568d0c3d618cfcede2e6c98c`
- Architecture records-only source: `#2340@7d0325ae324f295847b1f6a6dd7bec30ae959c73`
- Architecture handoff comment: `5547662428`

The final execution head is the branch tip after this execution-record commit. GitHub Actions evidence is authoritative live repository state and is additionally written to the PR handoff comment because a commit cannot truthfully contain the future run/job IDs for checks that only start after that commit exists.

## Fresh-main and allowlist proof

Live GitHub readback before branching proved:

- canonical `main` exact SHA remained `dbf22b467d35c8af2a074896c355a41993c8c191`;
- `app-version.json` was unchanged and authoritative with `version=1.2.22`, `androidVersionCode=29`, `iosBuildNumber=29`;
- `mobile/ios/project.yml` still had `MARKETING_VERSION=1.2.22`, `CURRENT_PROJECT_VERSION=28`;
- `.github/scripts/assert-native-electron-canonical.sh` was unchanged and requires the iOS mirror to equal the canonical build number;
- active ruleset `15857448` still required `CI result`, used the merge queue, and had no bypass actor;
- historical #2341 remained OPEN / UNMERGED at `2241c856fb3da498ac99ade89007fe01dd335183`;
- historical #2342 remained OPEN / UNMERGED at `570b874318bfe42406c6f46f51798baed8c89e48`.

No baseline-moved or historical-PR mismatch blocker was observed.

## Implemented change

Only the frozen implementation/config transaction was applied:

1. `.github/workflows/ci.yml`
   - adds the already-proven unconditional lightweight job named `Canonical version contract`;
   - sparse-checks out the direct inputs of the existing canonical assertion;
   - executes exactly `bash .github/scripts/assert-native-electron-canonical.sh`;
   - adds `canonical-version-contract` to `CI result.needs`;
   - requires `needs.canonical-version-contract.result` to be exactly `success` before the existing diff-selected aggregate loop;
   - preserves the existing `pull_request`, `merge_group`, `push`, classifier and domain-gate behavior.
2. `mobile/ios/project.yml`
   - changes only `CURRENT_PROJECT_VERSION: 28` -> `29`.

The canonical script, `app-version.json`, ruleset/branch protection, other workflows, Android, Electron, application/test source, Cargo/dependencies and release/version logic were not modified.

Task-specific records under `projects/telegram-fabushi-integration/**` are documentation/governance evidence only.

## Open-source-first record

Candidates reviewed:

- official GitHub Actions `jobs.<job_id>.needs`, `needs.<job_id>.result`, required-status and `merge_group` semantics;
- repository-proven #2342 topology;
- existing `actions/checkout@v5` (MIT);
- existing classifier `actions/github-script@v7` (MIT).

Adopted: the official/repository-native topology above, with no new dependency and no copied third-party code.

Rejected:

- inline or duplicated version comparison in YAML — violates the unchanged single-authority script contract;
- manual dispatch/rerun/different-SHA evidence — not durable exact-head required-gate proof;
- skipped/neutral/special-case bootstrap — creates a bypass;
- ruleset relaxation or optional status — outside scope and weakens protected-main truth;
- third-party checkout replacement — no need and no benefit over the existing MIT action.

License/source impact: no new package, source copy, asset or notice requirement is introduced.

## Validation policy and lightweight checks

No local build, test, rustfmt, clippy or E2E was run. No large build cache was created.

Lightweight validation consisted of GitHub source/diff/state inspection:

- fresh canonical-main SHA and protected ruleset readback;
- canonical script readback;
- exact #2341 one-value iOS patch readback;
- exact #2342 canonical-child / `CI result` topology readback;
- historical #2342 run `33928934236`, child `101203371687`, aggregate `101203476417` as topology/failure provenance only, never as current acceptance evidence.

Heavy/current acceptance is GitHub Actions on the final #2343 head only.

## Historical PR provenance / disposition

- #2341 exact head `2241c856fb3da498ac99ade89007fe01dd335183`; blocker comment `5547296411`; historical version-only provenance.
- #2342 exact head `570b874318bfe42406c6f46f51798baed8c89e48`; blocker comment `5547556953`; historical guard-only provenance.
- architecture handoff comment `5547662428` freezes #2343-style atomic replacement.

#2341 and #2342 remain OPEN / UNMERGED. This execution does not close, merge, rebase, retarget or force-push them. Their future closure may only record `superseded` after replacement provenance exists; #2343 now supplies that replacement provenance, but closure is deliberately deferred rather than performed in this atomic execution.

## Acceptance state at record creation

Static implementation and provenance: `IMPLEMENTED`.

Still required on the final exact #2343 head before execution handoff:

- `Canonical version contract` job must be present, not skipped/neutral, actually run the unchanged script, and conclude `success`;
- same-head `CI result` must conclude `success`;
- all other applicable repository PR gates, including Project portfolio governance, Developer Fiat Commerce and the explicit PR/automerge gate, must truthfully conclude `success` or otherwise satisfy their documented non-applicable semantics without being substituted for the required canonical child;
- if the required canonical child does not run or fails, execution terminal state is `REQUIRED-CANONICAL-VERSION-GUARD-NOT-RUN / BLOCKED` or the truthful failure equivalent, with no bypass.

The exact live run/job IDs and final conclusions are posted to #2343 only after those checks complete. Independent code review is not part of this execution and is the only next group if the exact-head gates pass.
