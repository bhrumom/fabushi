# GBF-204 Evidence — native capability handlers

- Static catalog parity: 156 methods, all implemented.
- Semantic stub gate: 156/156 pass.
- Security tests verify administrator permission ceiling, fail-closed OS secret encryption, encrypted-at-rest Secret Vault with no plaintext list leakage, managed attachment path containment, HTTPS-only downloads, and recursive telemetry redaction.
- Native edge remains trusted-sender gated; no generic renderer IPC bypass is retained.
