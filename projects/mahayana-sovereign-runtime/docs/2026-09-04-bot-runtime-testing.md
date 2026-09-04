# MSR P0 testing — FAB-ARCH-P0-20260904

Every authoritative task carries unit/contract/integration/E2E/security/performance acceptance. Required runtime matrices include: one Bot/one session idempotency; two Bots isolation; restart/recovery; direct/group/topic context; MiniApp reinstall/update; interruption/resume; capability allow/deny; approval approve/deny/expire; revoked device; stale generation; uninstalled/unavailable MiniApp; duplicate invocation; redaction; provider failure; result correlation; semantic capability preferred and Computer Use fallback only when genuinely unavailable and independently authorized.

## Canonical-main packaged evidence contract
For each application-affecting journey, write into the originating task: exact accepted canonical-main SHA, app version, platform, GitHub Actions workflow run **and job**, journey/test ID, timestamp, installable/package artifact identity, complete video, step-labelled screenshots, trace/action evidence, HTML/test report or native equivalent, and logs/debug output. Pass and fail evidence uploads through an `always()`-equivalent path. Target retention is 90 days where allowed; otherwise use the maximum platform/repository limit and record that constraint. Missing any required identity/artifact means the task cannot pass. Source-only/unpackaged tests do not satisfy closure.

Heavy build/test/E2E only in GitHub Actions; no local build/test.
