# FCM-010.12 — canonical closure evidence

## Protected implementation

The direct native-platform release gate repair completed through protected PR #2527 and merged as canonical main commit `2a6cf4dbb64f0625a9dc147bb21b9949b018a219` on 2026-09-11.

PR #2527 explicitly preserved the authoritative behavior:

- Android formal release requires `Native Android`.
- iOS formal release requires `Native iOS`.
- Combined release requires both platform checks.
- Post-main delivery waits on both direct exact-SHA checks.
- The historical `Native mobile result` string is only a non-authoritative compatibility sentinel and cannot be consumed by release-gate decision logic.

## Canonical main Actions proof

On exact canonical SHA `2a6cf4dbb64f0625a9dc147bb21b9949b018a219`:

- `CI result` completed successfully. The relevant run IDs observed were `34626752944` and `34626710587`.
- `Native Android` completed successfully in workflow run `34626808279`.
- `Native iOS` completed successfully in the same workflow run `34626808279`.
- Querying check-runs for the retired aggregate check name `Native mobile result` returned `total_count: 0`.
- Post-main delivery run `34628057521` completed successfully for the same source SHA, proving the downstream release controller accepted the direct Android/iOS checks without waiting for a second aggregation-only runner.

## Acceptance result

All FCM-010.12 acceptance items are satisfied. The redundant aggregation-only GitHub-hosted runner has been removed from the authoritative native/release path, and canonical Actions prove the delivery loop completes using the real Android/iOS platform checks directly.

This closes the measured `native-pr-fast` queue waste identified by FCM-010.11 without weakening Android, iOS, release, security, or exact-source correctness gates.