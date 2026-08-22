# GBF-407 Evidence — crash/reconnect / stale request safety

Remote desktop sessions receive a monotonic generation and every remote screenshot/action carries target device + generation; stale generation and wrong-device requests fail before native execution. Browser native-messaging bridge has reconnect/re-register coverage and fresh instance generation. Sensitive channel rotates on reconnect and challenges are one-time. Cross-platform CI remains required for final E2E/release state.

2026-08-22 CI refresh: M4 was reconciled with the current self-hosted messaging dependency manifest and the Mahayana workspace lock was regenerated at `acb7bfd2590e82f004bb59aa477f058471f6457a`. This records the dependency-closure rerun only; GBF-407 remains TESTED until the full M4 cross-platform gates pass and PR #2019 is merged to `main`.
