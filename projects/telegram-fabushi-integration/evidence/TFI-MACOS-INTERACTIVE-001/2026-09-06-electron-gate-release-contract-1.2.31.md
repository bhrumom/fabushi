# TFI-MACOS-INTERACTIVE-001 — restored Electron gate release-contract drift / 1.2.31

- Project: `FAB-P0001 / TFI`
- Task: `TFI-MACOS-INTERACTIVE-001`
- Version-parity protected main: `8cf204380559d4a997c96ddf6b44ae876dd3eb0d`
- Security-gate protected main: `ad9ddc38a99656d0ca09fd196d7ccb162e2a74dd`
- Version-parity PR: `#2383`
- Security-gate PR: `#2385`
- Security-gate merge-group CI: `33999910843` (`success`)
- Release-contract PR: `#2384`
- Discovery Electron PR run: `33999715376`
- Failing Electron Linux job: `101396275595`

## Failure boundary

The exact restored Electron gate passed canonical architecture/version parity and then exposed one independent packaged-release source-contract drift. The macOS test release already installs the same Computer Use dependencies, but hid that install inside a combined shell step while the contract requires a separately auditable `working-directory: chatgpt-vps-control` install before bundle staging. The source test also retained assertions for the old unified release and for `electron-macos-hot-package.yml` as though that workflow were still a full packager.

The hot-package workflow is now intentionally a manual paused stub that says it is superseded by the single Native Electron macOS test release workflow. It must not be treated as a fourth packager. The three actual full packagers remain explicitly checked for Computer Use install, signed-helper staging before `electron-builder`, and post-package Computer Use verification.

The same discovery run also revealed the separately paused Computer-control security gate. That governance failure was isolated in PR #2385, restored byte-for-byte to pre-pause blob `acfc957e0cfd5e0829e23677cf06455abb6b7782`, and protected-queue merged as `main@ad9ddc38a99656d0ca09fd196d7ccb162e2a74dd` after merge-group CI `33999910843` passed. PR #2384 has now absorbed that protected main instead of weakening its existing security assertions.

## Atomic repair

Because `1.2.30` belongs to the independent security-gate repair, this release-contract PR advances to strictly newer comparable macOS test version `1.2.31`. Android version code and iOS build number remain `29`. This PR changes only:

- canonical semantic-version metadata/guards from `1.2.30` to `1.2.31`;
- the macOS test release dependency install into explicit Electron and Computer Use working-directory steps before bundle staging;
- stale unified-release assertions so they verify the live tiered canonical source gate, protected-main ancestry, immutable-release refusal, exact release target SHA, checksums, and GitHub prerelease creation;
- stale hot-package assertions so they verify that the superseded workflow is explicitly paused/manual and contains no packaging command, while all actual packagers remain fully asserted.

The restored full Computer-control security workflow and its `Computer control security result` assertion remain intact. No product behavior, protected-branch rule, release-source gate, account/session handling, App-owned gateway ownership, Computer Use safety policy, or functional coverage is weakened.

Any `v1.2.30` release is intermediate governance evidence only. Interactive acceptance may begin only from the newest immutable protected-main release whose exact source has the restored real Electron quality gate and restored security gate green.
