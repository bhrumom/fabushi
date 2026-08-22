# GBF-407 Evidence — crash/reconnect / stale request safety

Remote desktop sessions receive a monotonic generation and every remote screenshot/action carries target device + generation; stale generation and wrong-device requests fail before native execution. Browser native-messaging bridge has reconnect/re-register coverage and fresh instance generation. Sensitive channel rotates on reconnect and challenges are one-time. Cross-platform CI remains required for final E2E/release state.
