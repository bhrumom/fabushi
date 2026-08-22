# Fabushi WeChat Mini Program

This mini program is a native WeChat/Taro implementation. It does not use
`web-view`.

## Architecture

- Runtime: WeChat native components through Taro.
- Shared layer: `@fabushi/shared` and `@fabushi/api-client`.
- Product parity sources:
  - `frontend/packages/shared/src/app-experience.ts`
  - `frontend/apps/web/src/app/host/host-client.tsx`
  - `mobile/android/app/src/main/java/com/ombhrum/fabushi/FabushiScreen.kt`
  - `mobile/ios/Fabushi/FabushiApp.swift`

The mini program reuses the canonical product information architecture, design
tokens, copy, API contracts, and domain data while rendering with native WeChat
components. It does not embed any retired Flutter/Tauri/Capacitor application shell.

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
