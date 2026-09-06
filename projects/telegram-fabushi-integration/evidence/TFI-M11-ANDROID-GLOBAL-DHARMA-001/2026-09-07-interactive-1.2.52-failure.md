# 2026-09-07 — Android 1.2.52 packaged interactive failure evidence

- Release: `android-v1.2.52-262491811` -> `380b6ed5a96a5b6d1295267e07d9c8dc45fa84ab`.
- Release run: `34050780156` / job `101533889951` SUCCESS; artifact `9994614114`.
- Interactive run: `34051316405` / job `101535343430` FAILURE.
- Fresh App-owned device: `gha-34051316405-1-interactive`.
- Evidence artifact: `9994884584`, digest `sha256:dfad88db72093413f625963f1f9ff7898266e81a9211a09b41d99cc304d3d852`.
- Report digest: `sha256:3410cbef8b7e74ea1c34e915a66eac9a429cd2ad713e67c44b8750f92a64e10c`; status `failed-timeout`.
- Gateway trace digest: `sha256:731c2ecc1a481b5ab0d880eb1684c5d45ce39be675e4744850085d963bdf52cb`.
- APK digest read back from evidence: `sha256:0060616070e5c223a27b5426b594bb7328a1cb7f421d5e6d91c830e271adb1e7`.
- Six semantic tool classes all have successful calls, but two actions failed `stale_app_surface_generation`; terminal channel failed refresh with `transport_error:IllegalStateException`, so logout and complete Global Dharma acceptance were not reached.
- Evidence payload has 21 checkpoint screenshots, device trace, logcat, APK/release checksum and six MP4 recording segments. No concatenated `android-session.mp4` exists; full single-video evidence remains PENDING.
