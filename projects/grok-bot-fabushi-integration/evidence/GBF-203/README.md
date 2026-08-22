# GBF-203 Evidence — Host process lifecycle

`MahayanaHostProcess` now tracks a monotonic generation and terminal closed state. Pending requests are generation-bound. Stale stdout/error/exit events from an old child cannot resolve/reject requests owned by a replacement child. `health()` reports state/generation/pid/pending/lastExit; `restart()` deterministically rejects only the active generation and starts a fresh host.

Fault tests cover normal request/health, unexpected process failure and recovery, stale late exit, explicit restart, and terminal close.
