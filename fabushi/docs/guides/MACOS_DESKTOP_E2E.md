# macOS Desktop E2E

## Runner

The macOS desktop suite uses Flutter's official `integration_test` runner:

```bash
flutter test integration_test/macos_desktop_e2e_test.dart \
  -d macos \
  -r expanded \
  --dart-define=FABUSHI_E2E_OFFLINE=true
```

`FABUSHI_E2E_OFFLINE=true` keeps CI deterministic:

- the home AI/OpenClaw flow returns a fixed local response;
- remote conversation and online-count polling are skipped;
- payment buttons are rendered and asserted, but no real payment is launched.

## Coverage

Current macOS E2E coverage:

- Home UI: "大乘", "本机 OpenClaw", quick prompts, composer input.
- Local OpenClaw/AI: prompt entry, send action, deterministic response.
- Global dharma composer: plus menu, "全球法布施" mode, region selector.
- Local desktop function: "本地转经轮" selection for premium users.
- Zen room: 2D/3D controls, practice button, start/guarded practice flow.
- Profile: logged-in header, practice record card, membership card.
- Practice records: cloud-sync status UI.
- Membership/payment: package cards, buy buttons, purchase/redeem history tabs.

## Adding New Tests

1. Add stable keys to important controls using the `dacheng.<area>.<name>` naming pattern.
2. Add shared navigation or setup helpers to `integration_test/support/macos_e2e_harness.dart`.
3. Add user-facing coverage to `integration_test/macos_desktop_e2e_test.dart`.
4. Keep external side effects behind `FABUSHI_E2E_OFFLINE` or a service mock.
5. Make Action logs useful: call `app.logStep('...')` before each meaningful workflow step.

## GitHub Actions

- `.github/workflows/macos-desktop-e2e.yml` runs the suite on PRs, pushes to `main`, and manual dispatch.
- `.github/workflows/desktop-platform-build.yml` manually builds `macos`, `windows`, `linux`, or `all`.
- Both workflows upload verbose logs as artifacts so failures can be diagnosed from GitHub without a local build.
