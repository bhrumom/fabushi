# Fabushi WeChat Mini Program

This mini program is a native WeChat/Taro implementation. It does not use
`web-view`.

## Architecture

- Runtime: WeChat native components through Taro.
- Shared layer: `@fabushi/shared` and `@fabushi/api-client`.
- Flutter parity sources:
  - `fabushi/lib/core/design_system/colors.dart`
  - `fabushi/lib/core/design_system/app_theme.dart`
  - `fabushi/lib/screens/globe_home_screen.dart`
  - `fabushi/lib/screens/meditation_room_screen.dart`
  - `fabushi/lib/screens/my_profile_screen.dart`

Flutter does not officially compile a standard Flutter app to WeChat Mini
Program native components. This app therefore reuses Flutter information
architecture, design tokens, product copy, API contracts, and domain data while
rendering the UI with native mini-program components.

## Commands

```bash
npm run typecheck
npm run build:weapp
npm run open:weapp
npm run preview:weapp
```

`open:weapp` and `preview:weapp` require WeChat DevTools CLI. If it is not in
the default location, set:

```bash
WECHAT_DEVTOOLS_CLI=/path/to/wechat-devtools/cli npm run preview:weapp
```

## Preview Checklist

- Home: edit the donation draft, copy it, switch to AI.
- Sutra: search a sutra, select it, open AI question from the reader panel.
- Practice: start, pause, add chant count, finish and save the local record.
- AI: send a prompt and search public dharma resources.
- Me: open service entries and verify reuse-boundary copy.

## WeChat Console Setup

- Replace `touristappid` in `project.config.json` with the real AppID before
  upload or QR preview.
- Add API request domains used by the AI gateway to the mini-program domain
  allowlist.
