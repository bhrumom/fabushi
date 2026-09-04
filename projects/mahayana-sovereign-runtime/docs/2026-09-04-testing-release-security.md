# MSR P0 testing, release and security addendum — 2026-09-04

- Project: `FAB-P0005/MSR`
- Program: `FAB-ARCH-P0-20260904`

Testing: prove one Bot/one session across restart, concurrent conversations, MiniApp reinstall/update, group context and interrupted turn recovery. Capability tests cover allow/deny/approval/revoke/stale references, redaction, tool-result correlation and no bypass to native/device/MiniApp providers.

Security: Bot identity is not authority to control a device. Same-account presence, pairing, control enablement, target/session/generation and per-call policy all remain separate checks. MiniApp tool schemas are admitted/validated before exposure. Secrets never appear in capability inventory or chat result envelopes.

Release: execution -> code review -> GitHub Actions test artifact -> full simulated-user video/trace/report -> architecture/video review -> protected canonical main -> exact-main packaged E2E -> formal release. Retain pass and fail evidence. Local build/test is forbidden.