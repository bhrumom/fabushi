# MSR P0 testing, release and security addendum — 2026-09-04

- Project: `FAB-P0005/MSR`
- Program: `FAB-ARCH-P0-20260904`

Testing proves one Bot/one durable session, restart/recovery, MiniApp reinstall/update, group context and interruption, plus capability allow/deny/approval/revoke/stale/unavailable/redaction/result correlation. Security separates Bot identity from device authority: same-account presence, pairing, control enablement, target/session/generation and per-call policy are distinct checks. Approval deny/expire, revoked/stale device and unavailable MiniApp fail closed. Semantic capability is preferred; Computer Use fallback is permitted only when semantic capability is genuinely unavailable **and** device/policy/approval preconditions independently pass.

Release follows task -> real-diff review -> GitHub Actions installable package -> complete pass/fail simulated-user evidence -> protected canonical main -> exact-main packaged E2E -> formal release. Evidence identity is exact main SHA/app version/platform/workflow run+job/journey ID/timestamp plus full video/step screenshots/trace/HTML-native report/logs and package identity, uploaded on an always-equivalent path. Target retention 90 days or recorded maximum lower limit. Missing evidence blocks pass. Local build/test is forbidden.
