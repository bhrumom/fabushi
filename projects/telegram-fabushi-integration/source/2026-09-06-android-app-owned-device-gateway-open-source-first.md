# 2026-09-06 — Android App-owned device gateway open-source-first review

- Project: `FAB-P0001 / TFI`
- Work item: `TFI-M11-ANDROID-INTERACTIVE-001`
- Canonical baseline re-read before implementation: `main@3f633e07cae0b022cce1ff3e6aeb8bfa92aa463d`

## Live repository findings

1. Canonical Android already contains `FabushiAppAgentSurface` with exactly six structured semantic tools, stale-generation protection, action allowlists and sensitive-value restrictions.
2. Canonical main has iOS/macOS interactive App-device workflows, but no Android equivalent and no Android native remote-device gateway transport.
3. The latest Android publication read before implementation is `google-play-v1.2.14-557996528f74`, while global `app-version.json` is already `1.2.35`; therefore the old Android package is not an acceptable final test candidate.
4. The shared product auth layer already has a strict protected GitHub Actions session contract for `gha-<run>-<attempt>-interactive`. Android reuses that existing allowlisted identity instead of broadening the authentication suffix contract. Device ownership is distinguished by `platform=android` and gateway metadata `kind=github-actions-android-app`.
5. The Android logged-in path currently renders `GrokMobileShellAndroid`, while semantic publication lives in the legacy `FabushiScreen` path. This is a likely surface-completeness defect, but it is intentionally not changed before transport is live; the first real `status/snapshot` result must establish the failure before a separate fix PR.

## Design decision

Mirror the proven iOS App-owned security model, adapted to Android packaging:

- The installed Android App owns the official `wss://fabushi-mcp.ombhrum.com/agent` WebSocket connection.
- Device registration obtains its credential from the existing `feature.auth.deviceAgentSession` product API.
- The App advertises only `FabushiAppAgentSurface.ToolNames`; no generic computer/shell primitive is added.
- The GitHub-release Android variant alone can import the bounded refresh-token-free CI session. Google Play and ordinary debug/release variants keep this import disabled.
- The interactive Actions job does not rebuild. It validates an immutable published `android-v*` tag/commit, verifies `SHA256SUMS.txt`, installs that exact signed APK, then authenticates and launches it.
- Continuous Android screen recording and logcat begin before installation. Per-call screenshots are captured from the App-owned gateway trace. Evidence uploads use `always()` semantics.
- A successful run requires all six semantic tools plus a real product logout; otherwise the run stays failed and preserves evidence.

## External dependency check

Android has no platform WebSocket API suitable for the existing gateway protocol. The implementation uses OkHttp's public WebSocket API (`com.squareup.okhttp3:okhttp:5.4.0`), which is the current published stable line checked during this work. The dependency is used only for HTTPS/WSS transport; semantic authorization remains inside `FabushiAppAgentSurface`.

## Rollback

Remove the Android gateway/bootstrap files, the two Android-specific workflows/scripts/tests, the OkHttp dependency and MainActivity lifecycle hook. No server protocol, shared Rust authentication allowlist, Google Play signing flow, or arbitrary remote-control capability is changed by this task.
