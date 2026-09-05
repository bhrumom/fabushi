# TFI-MACOS-INTERACTIVE-001 — restore Computer control security gate / 1.2.30

- Project: `FAB-P0001 / TFI`
- Task: `TFI-MACOS-INTERACTIVE-001`
- Base protected main: `8cf204380559d4a997c96ddf6b44ae876dd3eb0d`
- Discovery run: Electron PR run `33999715376`, Linux job `101396275595`
- Paused workflow: `.github/workflows/computer-control-security.yml`
- Exact pre-pause source commit: `586a0952f17ab4b36dab9a69402b837968f5aa3f`
- Exact pre-pause workflow blob: `acfc957e0cfd5e0829e23677cf06455abb6b7782`

## Independent failure

After the Electron desktop quality gate and canonical version parity were restored, the next dependency-free source-contract run reached the repository's Computer-control security contract and found that the actual security workflow was still reduced to a manual `paused` stub whose message says it was paused for the 2026-09-05 Mac test release. This is distinct from the macOS release-source contract drift already isolated in PR #2384.

The last pre-pause workflow on parent `586a0952…` contains the full pull-request/push/manual security gate, cross-platform Node security matrix, Rust computer-control contracts, remote-control platform-worker security, Linux managed-semantic desktop checks, and the aggregate `Computer control security result` job.

## Atomic repair

This slice restores `.github/workflows/computer-control-security.yml` exactly to pre-pause blob `acfc957e0cfd5e0829e23677cf06455abb6b7782` and stages strictly newer comparable macOS test version `1.2.30`. Canonical desktop/native-mobile/iOS marketing semantic versions and the existing exact CI/release guards move together; Android version code and iOS build number remain `29`.

No security assertion, protected-branch rule, product behavior, account/session handling, App-owned gateway ownership, remote-control opt-in rule, or Computer Use safety boundary is weakened. This repair must enter protected main normally, publish only an immutable newer test release, and the newest package may be used for interactive acceptance only when its exact protected-main source also has the restored Electron gate green.
