# GBF-803 Evidence — formal release

The canonical release mechanism is `.github/workflows/native-electron-release.yml`. A valid FAB-P0004 release must originate from a version tag that points to the canonical `main` commit after M2–M8 closure. The tagged commit must already have successful `CI result`, `Electron desktop result`, and `Native mobile result` checks.

The release workflow then independently re-runs the Electron user journey, packages macOS/Windows/Linux Electron artifacts, signs Android APK/AAB, signs the iOS IPA, generates `SHA256SUMS.txt`, and creates an immutable GitHub Release. Missing signing credentials, failed packaging/signing, or a pre-existing mutable release target are hard blockers. This file is intentionally not a success claim; final tag/run/release URLs and checksums must be appended only after the real release succeeds.
