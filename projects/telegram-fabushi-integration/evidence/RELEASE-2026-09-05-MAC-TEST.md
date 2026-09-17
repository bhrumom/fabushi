# 2026-09-05 Mac test release override

Status: PREPARED

User directive supersedes the prior architecture/execution/test-driven continuation for the current M3 work chain. #2349, #2350 and #2351 are closed by merge on their original architecture base. No SEED/EVIDENCE/M3-DESKTOP-004 follow-up is executed in this release round.

Target extraction into clean canonical main is limited to #2349 diagnostic product/test delta plus #2350 acceptance provenance; unrelated GBF/MSR/MiniApp/Mahayana planning on the architecture base is excluded.

Release version: 1.2.23. Only `.github/workflows/native-electron-release.yml` may perform the release build, and it is manual Mac-only. Required protected-main `CI result` remains as a short control-plane check because ruleset 15857448 cannot be bypassed. Automatic Electron desktop, messaging product, native mobile, computer-control security, commerce, mac hot-package, post-main delivery and version-sync workflows are paused to manual-only for this release round.

Rollback point before canonical-main integration: 586a0952f17ab4b36dab9a69402b837968f5aa3f.
