# TFI-MACOS-INTERACTIVE-001 — restored Electron release-contract drift / 1.2.32

- Project: `FAB-P0001 / TFI`
- Task: `TFI-MACOS-INTERACTIVE-001`
- Electron gate restore: PR `#2382` -> `main@31ac7659b85cce27d31dfa7dcc54537c26e8e15e`
- Version parity repair: PR `#2383` -> `main@8cf204380559d4a997c96ddf6b44ae876dd3eb0d`
- Computer-control security restore: PR `#2385` -> `main@ad9ddc38a99656d0ca09fd196d7ccb162e2a74dd`
- Native-mobile gate restore: PR `#2386` -> `main@46050cdb3cf91c7cdc59548d8153e255c72782ed`
- Native-mobile merge-group CI: `34000172033` (`success`)
- Release-contract PR: `#2384`
- Last release-contract Electron run: `33999996221`, Linux job `101397023335`

## Failure boundary

The exact restored Electron quality gate now reaches the dependency-free packaged-runtime source contracts. The current Native Electron macOS test release already has the required Computer Use install/stage/sign/verify behavior, but the source contract still encoded historical implementation details from the retired unified release and from an old monolithic CI workflow.

The first repair made the Native Electron Computer Use dependency install separately auditable with `working-directory: chatgpt-vps-control`, migrated obsolete unified-release assertions to the live tiered protected-main source gate and immutable prerelease policy, and stopped treating the intentionally superseded manual `electron-macos-hot-package.yml` stub as a fourth full packager. Run `33999996221` proved those assertions progressed and then failed only when the same source test reached the old CI sparse-input assumptions (`/^chatgpt-vps-control/` and path-list entries) that no longer exist in the canonical minimal `CI result` workflow.

That same cycle independently exposed the paused Native mobile gate. It was not folded into this PR: #2386 restored `.github/workflows/native-mobile.yml` byte-for-byte to pre-pause blob `371125ec6caeab447d6d8891210b8e24714b1686`; its direct Native mobile PR gate and reusable catch-all both passed, merge-group CI `34000172033` passed, and protected main advanced to `46050cdb3cf91c7cdc59548d8153e255c72782ed`.

## Atomic repair

PR #2384 has absorbed that protected main and advances to strictly newer comparable macOS test version `1.2.32`; Android version code and iOS build number remain `29`. It changes only the remaining release-contract drift:

- Native Electron release keeps an explicit Computer Use dependency-install working directory before staging;
- live tiered release-source policy is asserted through `require-release-source-gates.sh`, exact protected-main ancestry, immutable release refusal, exact target SHA and checksums;
- the retired hot-package workflow is asserted as manual/paused/superseded, while the three actual packagers remain under Computer Use install/stage/sign/verify ordering assertions;
- the obsolete monolithic-CI path/sparse-input expectations are replaced with strong assertions for the current canonical minimal `CI result`: PR + merge-group triggers, release-control integrity, app/desktop version parity, exact macOS test-release workflow binding, source-gate/immutable-release markers, stable App-target rebase contract, packaged native-helper contract, and iOS interactive hold contract.

No functional product behavior, branch-protection rule, release-source gate, security assertion, App-owned gateway ownership, remote-control opt-in rule, or Computer Use safety policy is weakened. The restored Electron, Computer-control security, and Native mobile gates remain real required evidence.

There is no immutable `v1.2.31` release at this boundary because its exact main source still has the known #2384 Electron source-contract failure. Interactive acceptance must wait for a newer protected-main release whose exact source has all restored gates green.
