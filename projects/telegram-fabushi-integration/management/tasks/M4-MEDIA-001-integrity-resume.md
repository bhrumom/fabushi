# M4-MEDIA-001 — Media integrity and resilient transfer contracts

- **Project ID**: `FAB-P0001`
- **Project Key**: `TFI`
- **Task ID**: `M4-MEDIA-001`
- **Stage**: `M4 媒体与文件`
- **WBS**: `M4.T01`–`M4.T03`, `M4.T07`–`M4.T08`
- **Status**: `IN_PROGRESS`
- **Started**: `2026-08-22`
- **Depends on**: M3 desktop interaction landing for final retarget; canonical blob/media core already exists

## Objective

Strengthen the existing Fabushi-owned `FileBlobStore` / `MediaTransferQueue` rather than replacing them: verify declared content hashes, prove process-restart resumability/range reads, and bind retry/offset semantics to current GitHub product gates.

## Live audit

Already implemented:
- `.part` resumable uploads and persisted `.part.json` metadata;
- `upload_status` recovery;
- strict append offset validation;
- bounded range downloads;
- transfer queue states, pause/fail/retry count/progress and verification byte accounting;
- blob commands use the narrow `BlobsWrite` access scope.

Confirmed gap:
- `BlobMetadata.content_hash` exists but `finish_upload` currently accepts a completed byte count without verifying the declared content hash.

## Acceptance criteria

1. Support a canonical `sha256:<lowercase-hex>` content-hash format when `content_hash` is supplied.
2. `finish_upload` rejects hash mismatch and does not publish the partial blob as complete.
3. Matching hash publishes the blob and preserves metadata.
4. An interrupted upload can be reconstructed by a new `FileBlobStore` instance, resume from `upload_status.uploaded_bytes`, finish, and support bounded range reads.
5. Wrong resume offsets are rejected without corrupting partial content.
6. `MediaTransferQueue` failed transfer may restart from the same transferred offset and increments retry count; invalid offsets/verification mismatches remain explicit failures.
7. Current Rustfmt/all-target tests/Clippy and messaging product gates pass before landing.

## Expected scope

- `native/mahayana-messaging/src/blob_store.rs`
- focused Rust contract tests (in-module or integration)
- M4 WBS/evidence/status records

## Completion rule

Implementation alone is not completion. Final M4 task status requires current-head GitHub Actions, protected merge, and canonical-main verification. Desktop media UX and thumbnail/cache/media-type coverage remain separate M4 tasks if not objectively covered by this task.
