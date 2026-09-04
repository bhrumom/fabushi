# TFI-M6-MAINSAFE-001-VERSION-CONTRACT-001 — historical canonical iOS build-number mirror attempt

- Project: `FAB-P0001 / TFI`
- Status: `HISTORICAL / BLOCKED / IMPLEMENTATION-EXISTS-UNREVIEWED / SUPERSEDED-BY-VERSION-BOOTSTRAP-001`
- Baseline: `main@dbf22b467d35c8af2a074896c355a41993c8c191`
- Product implementation PR: `#2341`, exact head `2241c856fb3da498ac99ade89007fe01dd335183`, OPEN / UNMERGED
- Execution blocker handoff: #2341 comment `5547296411`
- Superseding task: `TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001`
- Parent boundary: `TFI-M6-MAINSAFE-001`; completed `OWNERSHIP-001` is not reopened and downstream fixture/evidence/release tasks remain separately gated.

## Verified historical product scope

- canonical `app-version.json`: version `1.2.22`, Android version code `29`, iOS build number `29`;
- canonical `mobile/ios/project.yml`: `CURRENT_PROJECT_VERSION: 28` on this baseline;
- #2341 implements exactly `mobile/ios/project.yml CURRENT_PROJECT_VERSION 28 -> 29` as its only semantic product/config change; the other four files are TFI records;
- no evidence shows this one-value patch itself is wrong.

## Why #2341 remains blocked

Frozen acceptance required actual current-head execution of `.github/scripts/assert-native-electron-canonical.sh` inside the protected required topology. #2341's base did not contain a canonical-version child in `CI result`; its green `Canonical architecture guardrails`/Native mobile/other workflows do not substitute for that missing script execution.

## Dependency-cycle update

The former disposition (`VERSION-GUARD-CI-001` first, then `VERSION-CONTRACT-002`) is superseded. Historical #2342 proved that guard-only topology does execute correctly but truthfully fails against the same canonical 29/28 drift, causing required `CI result` to fail. Therefore the two halves cannot enter protected main sequentially from this baseline.

The one-value repair proven by #2341 is now folded into the same-head `TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001` transaction together with the required `ci.yml` topology.

## Historical disposition

Architecture does not review, merge, close, rebase, retarget, or force-push #2341. It remains durable pre-required-topology provenance and must never be merged as a shortcut.

Only after a fresh-main bootstrap replacement PR exists and records provenance to #2341 exact head `2241c856...`, #2342 exact head `570b874...`, and blocker comments `5547296411` / `5547556953` may the appropriate execution/product owner close #2341 as superseded.

## Historical allowlist and prohibitions

Historical #2341 correctly limited its semantic implementation to:

- `mobile/ios/project.yml`: `CURRENT_PROJECT_VERSION: 28` -> `29` only.

Under this historical task do not edit workflows, canonical script, `app-version.json`, Android, package versions, application/test source, Cargo/dependencies, release/version semantics, or use manual/skipped/historical evidence as the missing guard proof.

## Superseding records

- `management/tasks/TFI-M6-MAINSAFE-001-VERSION-BOOTSTRAP-001.md`
- `evidence/TFI-M6-MAINSAFE-001/VERSION-BOOTSTRAP-CYCLE-DIAGNOSIS-2026-09-05.md`
- `decisions/ADR-0013-version-bootstrap-atomic-required-gate.md`
