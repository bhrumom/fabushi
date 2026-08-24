# GBF-408 — Local Docker execution environment

- Project ID: `FAB-P0004`
- Project Key: `GBF`
- Task ID: `GBF-408`
- Status: `IMPLEMENTED`
- Started: `2026-08-24 18:05 +08:00`
- Updated: `2026-08-24 20:07 +08:00`
- Completed: —
- Branch: `codex/gbf-provider-router`
- Commit / PR: unified PR head / [#2106](https://github.com/bhrumom/fabushi/pull/2106)

## Objective and scope

Provide the reference's optional local-container execution effect without adding a second Agent/Host. Process tools continue through Mahayana capability and approval checks; only the final execution adapter changes. Docker installation, daemon management and arbitrary image selection are out of scope.

## Acceptance and verification

1. Host remains default and legacy settings remain compatible.
2. Docker selection requires a discovered CLI and digest-pinned image.
3. Every container is disposable and owner-labelled, has network disabled, read-only root, dropped capabilities, no-new-privileges and bounded PID/memory/CPU resources.
4. Only the canonical active workspace is mounted read/write; `/tmp` is bounded tmpfs.
5. Process denial and approval behavior is identical to Host mode; Rust/Node tests and packaged E2E must pass.

## Open-source survey and decision

The reconstructed local Docker connector was studied for ownership, image and readiness failure modes but not copied. Microsoft [`devcontainers/images`](https://github.com/devcontainers/images/blob/main/src/base-ubuntu/.devcontainer/Dockerfile) (MIT) was selected from the [official MCR catalogue](https://mcr.microsoft.com/en-us/artifact/mar/devcontainers/base/tag/ubuntu24.04) and pinned to `sha256:c5cc2b45...b0705`. A disposable-command adapter fits Fabushi's existing native engine more safely than importing the reference gateway/runtime.

## Implementation

- Added `ProcessExecution::LocalDocker` under the native engine's existing process tool path.
- Added strict immutable-image validation and a pinned Ubuntu 24.04 default.
- Passed persisted sandbox choice through Electron Host generation environment and restarted only when the choice changes.
- Added secret-free readiness and disabled selection when Docker/pinning prerequisites are absent.

## Evidence, risks and next action

Lightweight static inspection only. Code-head security `32725103937`, platform `32725103983`, native-mobile `32725103902` and multi-platform contracts `32725103959` passed. The final unified-head Rust rerun and packaged Windows/macOS/Linux behavior remain required. Daemon availability and first image acquisition can still fail at execution time and must surface as a recoverable tool error.
