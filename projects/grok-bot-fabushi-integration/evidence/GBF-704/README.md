# GBF-704 Evidence — secret/log/privacy audit

Operational telemetry is intentionally metadata-only. Electron edge traces contain `edge`, `method`, `correlationId`, `status`, `code`, and `durationMs`; they exclude args, results, URLs and tokens. Native diagnostic persistence recursively redacts keys matching secret/token/password/authorization/cookie/credential/private-key semantics, with nested redaction tests proving plaintext does not reach the diagnostics file.

Sensitive input is separately encrypted to the target device with ECDH P-256 + AES-GCM, challenge-bound through AAD, optionally expiring, one-time consumed, and rotated on reconnect. Secret Vault writes require OS-backed encryption and list operations never reveal secret values.

M7 release closure requires both static anti-regression checks and the existing executable denial/redaction/replay tests to remain green.
