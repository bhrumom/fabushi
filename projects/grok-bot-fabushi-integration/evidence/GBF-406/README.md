# GBF-406 Evidence — one-time sensitive input

Sensitive values use per-device ECDH P-256 -> AES-GCM encryption with challenge id as authenticated additional data. Decrypt now consumes the challenge exactly once and optionally enforces expiry. Device reconnect rotates the secure channel/key and advertises a fresh connection generation, invalidating prior encrypted envelopes. Tests cover target/challenge binding, placeholder whole-value substitution, replay rejection and expiry rejection.
