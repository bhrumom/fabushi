# Status report — TFI-M11-IOS-INTERACTIVE-001 AX close fallback

- Source: canonical main `43ce998fd5fbcae032c179a8814de9ec08d03f4c`.
- Triggering Native mobile run: `34055531700`.
- Android: success.
- iOS: failed at SwiftUI close Button AX scroll-to-visible; artifact `9995961959` retained.
- Repair: test-only semantic element center-coordinate fallback with keep-always screenshot; no local Xcode build/test.
- Status: `IN_PROGRESS` until protected merge and a new canonical-main Native mobile run passes both iOS and Android.
