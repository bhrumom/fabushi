# TFI-MACOS-INTERACTIVE-001 — release-governance defect before v1.2.27

- Project: `FAB-P0001 / TFI`
- Task: `TFI-MACOS-INTERACTIVE-001`
- Status: `TESTING`

## Trigger

PR #2378 repaired the App-owned stale-generation control defect and merged as `main@9dae2ea92ad055b4f5af2dfd4b99e872d200c840`. Its product contract CI passed, but GBF rollback drill run `33974694259`, job `101329226922`, failed at `Require immutable-release and canonical-gate guards in the current release workflow`.

The exact failure was deterministic: `.github/workflows/native-electron-release.yml` did not invoke the repository's canonical `.github/scripts/require-release-source-gates.sh`, while GBF still expected canonical source-gate and immutable-release guards. The push-triggered v1.2.26 release run `33974806955` started from the affected main before this governance defect was closed.

## Truth disposition

`v1.2.26` is excluded from App-owned acceptance even if its packaging/notarization/publish steps finish successfully. A signed package is not a valid test candidate when its release-source gate was not executed. No `@fabushi test` matrix result from v1.2.26 may satisfy this task.

## Atomic repair — PR #2380

- Stage strictly newer macOS test version `1.2.27`; Android/iOS build counters stay unchanged.
- Bind the exact current protected-main SHA before build.
- Invoke `.github/scripts/require-release-source-gates.sh` before dependency install/build/signing with:
  - `RELEASE_TARGET=macos`
  - `RELEASE_TIER=test`
- Preserve the canonical test-tier policy: exact source must be on protected main and its `CI result` must be successful.
- Preserve formal desktop/mobile policies centrally in `require-release-source-gates.sh`; no product assertion is weakened.
- Fail closed when the target GitHub release already exists; never mutate an existing release.
- Align GBF to verify the central per-tier policy rather than require unrelated formal mobile gate literals inside a macOS-only test workflow.

## PR proof before final evidence-record commit

On head `a7db88264fc8671507bbe4ced6b9723c01866344`:

- CI run `33975043714`: SUCCESS; it checked v1.2.27 binding, macOS-only workflow scope, canonical release-gate invocation, immutable-release refusal, and the stable-target regression contract.
- Delivery governance run `33975043716`: SUCCESS.
- GBF rollback drill run `33975043707`: SUCCESS, including previous-good release download/checksum verification and the exact canonical/immutable guard step that failed in `33974694259`.

Because this evidence record itself advances the PR head, the final head must repeat the applicable lightweight checks before protected merge. After merge, only the guarded v1.2.27 release and its canonical App-owned interactive run may advance the TFI acceptance matrix.
