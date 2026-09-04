# MSR P0 testing — FAB-ARCH-P0-20260904

Required contract coverage: one Bot/one session idempotency; two Bots isolation; restart/recovery; direct+group+topic continuity; MiniApp reinstall/update; interruption/resume; capability allow/deny; approval approve/deny/expire; revoked device; uninstalled MiniApp; stale generation; duplicate invocation; redaction; provider failure; typed result correlation.

Heavy build/test/E2E runs only in GitHub Actions. Packaged cross-project journeys must retain pass and fail videos, step screenshots, trace, report and logs.