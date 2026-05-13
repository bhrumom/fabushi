# Store screenshots

The store-listing screenshot path uses Flutter's official `integration_test`
`takeScreenshot()` API on real iOS simulators or Android emulators. Keep
Playwright for web/staging E2E tests; store screenshots should come from the
native Flutter app so platform rendering matches App Store and Google Play.

## Run locally

From `fabushi/`:

```bash
flutter pub get
flutter devices

STORE_SCREENSHOT_OUTPUT_DIR=build/store_screenshots/raw/ios \
  flutter drive \
  --driver=test_driver/store_screenshot_driver.dart \
  --target=integration_test/store_screenshots_test.dart \
  -d "iPhone 16 Pro Max"

STORE_SCREENSHOT_OUTPUT_DIR=build/store_screenshots/raw/android \
  flutter drive \
  --driver=test_driver/store_screenshot_driver.dart \
  --target=integration_test/store_screenshots_test.dart \
  -d "Pixel 8 Pro"
```

The raw PNGs are written to `build/store_screenshots/raw/`. In release automation, the same Flutter app screenshot flow writes `screenshot-*.png` files to the release screenshot artifact. Generate App Store
and Google Play final preview images from those raw captures with a separate
post-processing step, because each store has its own allowed dimensions and
marketing-frame rules.
