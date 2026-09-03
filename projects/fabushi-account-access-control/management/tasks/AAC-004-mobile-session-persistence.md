# AAC-004 — Mobile durable authenticated session

- Project ID: `FAB-P0008`
- Task ID: `AAC-004`
- Status: `in-progress`
- Started: `2026-09-03`
- Branch: `fix/gbf805-product-parity-20260903`

## User requirement

After fully terminating the mobile Fabushi app and reopening it, an authenticated user must remain logged in. A process restart must not behave like logout. Explicit logout must still revoke/clear the durable account session.

## Root cause

The Rust Product client already stores account sessions in the encrypted `mahayana-secrets` store and production `feature.auth.status` already attempts session restore. The missing native boundary was the encryption passphrase lifecycle: desktop platforms had an OS credential-store-backed path, while the native iOS/Android app-host creation path did not inject a stable OS-protected key. A new app process could therefore not reliably reopen the same encrypted account session.

## Implementation

- `mahayana-secrets` accepts a caller-provided stable storage passphrase without persisting that passphrase itself.
- `HostCreateConfig`, `MahayanaProductClient`, `AppHost`, `UnifiedAppHost` and the mobile FFI carry the passphrase only in process memory and exclude it from serialized Host configuration.
- iOS creates/reads 256-bit random key material from Keychain using `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` and injects its Base64 form directly when constructing the native Rust Host.
- Android creates a non-exportable AES-256 key in `AndroidKeyStore`, uses AES/GCM to wrap a random 256-bit Mahayana storage passphrase, persists only ciphertext/IV in private SharedPreferences, unwraps it after process restart, then injects the passphrase directly into the native Rust Host.
- FeatureHost and AppHost Product clients use the same injected key for their encrypted auth namespace. Existing `feature.auth.logout` remains the canonical explicit logout boundary.

## Security constraints

- No access token, refresh token or storage passphrase is written to `UserDefaults`, plaintext SharedPreferences, renderer state or JSON IPC.
- The mobile passphrase never crosses into the renderer or model context.
- iOS key material is device-only; Android wrapping key is non-exportable from Android Keystore.
- If durable encrypted state is unreadable, existing encrypted-store quarantine/fail-closed behavior applies; the client must not fabricate a logged-in state.

## Verification / acceptance

- [ ] `mahayana-secrets` regression proves the same injected platform passphrase can decrypt the account session after manager recreation and plaintext is absent at rest.
- [ ] iOS production host creation is source-gated to Keychain -> `mahayana_app_host_create_with_storage_passphrase`.
- [ ] Android production host creation is source-gated to Android Keystore -> JNI storage-passphrase constructor.
- [ ] iOS/Android compile and native Host integration gates pass in GitHub Actions.
- [ ] Packaged/signed mobile process-relaunch journey proves login survives full process destruction and recreation.
- [ ] Explicit logout followed by process recreation stays logged out.
- [ ] Protected `main`, exact-main package/E2E and release evidence are recorded before this task becomes complete.
