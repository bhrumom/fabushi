# Source intake

## User requirement — 2026-09-01

Fuse RustDesk capabilities into Fabushi so one account registers, discovers and monitors multiple devices, then progressively supports secure direct/relay remote desktop, input, clipboard, file transfer, display, audio, sessions, permission policy, audit, recovery and desktop/mobile/Web surfaces. Do not claim unimplemented capability; use GitHub Actions rather than local heavy builds.

## Pinned upstream evidence

| Repository | Revision | Observed package version | License |
|---|---|---|---|
| rustdesk/rustdesk | f28ac38ccfa662fd06639a062e0d06249860b142 | 1.5.0 | AGPL-3.0 |
| rustdesk/hbb_common | b2b1ac453d1d694046f63be20d792d608dac1c93 | submodule protocol baseline | AGPL-family upstream component; verify notices per distribution |
| rustdesk/rustdesk-server | a7736be5e40f85bfc141120dce587e836e5d4b80 | 1.1.17 | AGPL-3.0 |

Protocol evidence includes `RegisterPeer`, `RegisterPk`, direct punch-hole and relay messages, control-permission bits, video/audio frames, mouse/key events, clipboard, file actions and display/session messages. This project records behavior/mappings without copying protobuf or implementation source into Fabushi.
