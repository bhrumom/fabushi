# MSR P0 release — FAB-ARCH-P0-20260904

Execution -> pushed atomic real diff -> independent code review -> GitHub Actions installable test package -> complete simulated-user pass/fail evidence -> architecture/video review -> protected canonical-main merge -> exact-main packaged E2E -> formal release.

Dependency acceptance is a hard prerequisite, never shorthand reuse: MSR-210 cannot pass before `MSR-201 REVIEW-PASS/accepted contract`; MSR-211 cannot pass before `MSR-202`, `MSR-210`, `GBF-409`, and `GBF-411` are review-passed/accepted. Each dependent task must then separately satisfy its own review, CI, protected merge, exact-main packaged E2E and Release evidence.

Every package handoff records exact main SHA, app version, platform, workflow run/job, journey ID, timestamp, installable artifact, full video, step screenshots, trace, HTML/native report and logs. Upload pass and fail with an always-equivalent path, target 90-day retention or record the maximum lower limit. Any missing item blocks release. Branch-only/source-only artifacts are not formal releases.
