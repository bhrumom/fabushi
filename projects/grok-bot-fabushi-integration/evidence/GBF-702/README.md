# GBF-702 Evidence — denial/replay security tests

High-risk denial paths are automated and fail closed:

- Electron edge rejects untrusted senders and missing handlers.
- local tool permission cannot exceed the administrator ceiling.
- secret operations fail closed when OS-backed encryption is unavailable.
- secret vault persistence never stores plaintext values.
- managed attachments reject path escapes and non-HTTPS downloads.
- diagnostic persistence recursively redacts nested token/password/authorization values.
- remote computer requests reject stale generation and wrong device before native execution.
- browser sessions reject unsafe target/scheme/claim combinations.
- sensitive input rejects challenge replay and expiry and binds ciphertext to the challenge through AES-GCM AAD.

Authoritative evidence is produced by Electron, Mahayana and computer-control GitHub Actions; M7 closure does not substitute documentation for those executable tests.
