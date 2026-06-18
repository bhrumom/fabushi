# Embedded OpenClaw runtime assets

Release builds should contain one platform directory under this folder, for example:

```text
assets/openclaw/macos-arm64/node/bin/node
assets/openclaw/macos-arm64/openclaw/bin/openclaw.js
assets/openclaw/macos-arm64/openclaw/package.json
assets/openclaw/macos-arm64/openclaw/node_modules/...
```

The app copies these assets to the per-user application support directory on first desktop launch, sets executable permissions, and starts `openclaw gateway --port 18789` automatically. End users do not install Node, npm, or OpenClaw separately.

Use `scripts/build_openclaw_desktop_bundle.sh` in CI/release packaging to populate the platform folders before `flutter build macos/windows/linux`.
