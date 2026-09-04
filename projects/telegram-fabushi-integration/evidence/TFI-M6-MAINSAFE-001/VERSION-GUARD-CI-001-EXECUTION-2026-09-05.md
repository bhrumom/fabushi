# TFI-M6-MAINSAFE-001 VERSION-GUARD-CI-001 execution evidence — 2026-09-05

## Identity
- Project/task: `FAB-P0001 / TFI` / `TFI-M6-MAINSAFE-001-VERSION-GUARD-CI-001`
- Canonical base: `dbf22b467d35c8af2a074896c355a41993c8c191`
- Architecture PR/head: `#2340@a514a396cc7f6c1a3a622aba54906d33c00c3e4b`
- Historical blocked PR: `#2341@2241c856fb3da498ac99ade89007fe01dd335183`
- Architecture handoff: #2341 comment `5547466413`
- Execution branch: `fix/tfi-m6-mainsafe-001-version-guard-ci-001`
- Product/CI PR: `#2342`
- Initial implementation commit: `3aa3fac353671a2b7203f242ee12d1ff3119d345`
- First evidence head: `f57fb7ddc72db0db31c7e5ae45d32c786b2bf455`
- Acceptance: `M6-PM-VG-A01`
- Result: `BLOCKED / SCOPE-EXPANSION-REQUIRED`

## Baseline proof
- Live canonical main was re-read before branch creation and remained `dbf22b467d35c8af2a074896c355a41993c8c191`.
- Ruleset `15857448` requires only `CI result` and has no bypass actor.
- Existing `CI result` had no version-contract child dependency.
- Existing `Canonical architecture guardrails` only checks retired Flutter/Tauri/Capacitor workflow commands.
- Existing authoritative version script is `.github/scripts/assert-native-electron-canonical.sh`.

## Implementation proof

Initial compare `dbf22b... -> 3aa3fac...` changed exactly one implementation file, `.github/workflows/ci.yml`, with 42 additions and no deletions.

The implementation adds `Canonical version contract` as an unconditional lightweight job and adds it to the protected aggregate's dependency list. The aggregate explicitly rejects every result other than `success` for this child, so a skipped child cannot satisfy `CI result`.

The job sparse-checks out all direct inputs required by the unchanged canonical script and runs exactly:

`bash .github/scripts/assert-native-electron-canonical.sh`

No version assertion is copied into YAML and no new action/dependency is introduced.

## Why unconditional instead of a new classifier domain

A new version domain would make version-bearing paths count as already classified. On current `ci.yml`, unknown non-doc paths deliberately force all canonical domains. Reclassifying those paths could therefore reduce pre-existing safety behavior. Running this dependency-free guard on every CI event is the smaller semantic change and guarantees a future `mobile/ios/project.yml` PR cannot skip the child.

## First exact-head Actions proof

PR #2342 head `f57fb7ddc72db0db31c7e5ae45d32c786b2bf455` produced CI run `33928830797`.

### Canonical child

Job: `Canonical version contract` / `101203055760`.

Observed steps:
- checkout: SUCCESS;
- `Execute canonical native/Electron version contract`: FAILURE;
- post-checkout: SUCCESS.

Raw log proves actual execution rather than a skipped/simulated gate:

- `Complete job name: Canonical version contract`
- `Run bash .github/scripts/assert-native-electron-canonical.sh`
- `iOS build number drift: canonical=29 project=28`
- `Process completed with exit code 1.`

The checkout log also lists `mobile/ios/project.yml`, `app-version.json`, package/lock files, workflow files, and the unchanged canonical script in sparse-checkout inputs.

### Protected aggregate binding

Job: `CI result` / `101203097569`.

Conclusion: **FAILURE**.

Raw aggregate log proves dependency binding:

- `version_contract_result="failure"`
- `Canonical version contract failed: failure`
- exit code `1`.

Thus the topology objective is operationally proven: a failing canonical child makes the protected required aggregate fail.

### Other CI jobs in the same run

- `Classify CI changes` / `101203055701`: SUCCESS.
- `Canonical architecture guardrails` / `101203073047`: SUCCESS.
- Frontend / Worker / MCP plugin contracts / Electron Feature Host: SKIPPED under the unchanged classifier.

The successful architecture guard remains distinct from the failed canonical version contract and is not used as substitution evidence.

## Blocker interpretation

The child did not fail because it was skipped, miswired, or unable to find its inputs. It failed because canonical main already has the known version drift `iosBuildNumber=29` vs `CURRENT_PROJECT_VERSION=28`.

Correcting that value would require `mobile/ios/project.yml`, explicitly outside this task's allowlist and reserved for the separately frozen version-contract repair. No waiver, conditional skip, script change, or manual status substitution is permitted.

Therefore `M6-PM-VG-A01` cannot pass on this task's current canonical base without scope expansion. Execution returns to architecture.

## Open-source / official provenance

- GitHub Actions official documentation: job `needs`, required status checks, merge queue / `merge_group`, and manual workflows. Adopted semantics only; no copied code.
- `actions/checkout` — GitHub-maintained, MIT; existing repository dependency reused.
- `actions/github-script` — GitHub-maintained, MIT; existing classifier remains unchanged.
- Fabushi FCM ADR-0005 — retained cheap deterministic required gates and aggregate `CI result` while preserving post-main heavy validation.

No local build/test/rustfmt/clippy/E2E was run or used as acceptance evidence.
