# AAC-003 exact-main run #977 root-cause follow-up

Exact-main Electron run `32973176951` (run number 977, SHA `9699ba5c0400f93d235f0853be9003e6ea7977b2`) proved the first #2153 repair partially successful: the stable `fabushi-motion-v2` BotMark nodes were visible again and marketplace search/install E2E passed. The run still failed the Linux pre-package user journey for two independent reasons.

## 1. First-login reset incorrectly armed the reauthentication reload

`clearAccountScopedDesktopCaches()` is intentionally called when the initial auth probe reports `loggedIn=false`, so `MAHAYANA_ACCOUNT_SESSION_RESET_EVENT` is not exclusive to logout. The first version of `account-session-sync.ts` armed on every reset. During normal first login it raced DesktopShell's own 900 ms auth probe and reloaded `app://bundle/index.html` after the Messenger had already become interactive. Playwright correctly observed controls detaching during send/create/scroll actions.

The synchronizer is now armed only when the reset event is observed while `messenger-workspace` is actually mounted. That distinguishes manual logout / terminal session revocation from first-login bootstrap without introducing another global state flag. Once reauthenticated, it reloads only if DesktopShell has not already restored the workspace.

## 2. Grok renderer migration also removed the stable motion-tier attribute

Run #977 found the profile BotMark itself, but the existing contract expected `data-motion-tier="ambient"` for an idle, non-emphasized, non-pointer-follow mark. The pre-Grok implementation derived this from `idle`, `sleeping`, `drowsy`, `bored`, and `powering-down` states.

That exact semantic tier function is restored while the Grok renderer remains unchanged. The BotMark architecture gate now requires the semantic motion-tier binding in addition to `data-engine="fabushi-motion-v2"` and `data-renderer="grok-mark"`.

AAC-003 remains `in-progress` until a later exact-main run passes Linux/macOS/Windows packaged user journeys and publishes a desktop GitHub Release newer than 1.0.941.
