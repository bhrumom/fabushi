# ADR-0001: Chrome boundaries and open-source API reuse

Status: accepted for CWA-006. Date: 2026-09-12.

Use official Native Messaging and Debugger API models and GoogleChrome samples as
architecture references, without copying third-party Bridge code. Keep product/account
calls on com.fabushi.chrome_platform, browser/CDP calls on com.fabushi.browser_control,
and preserve the existing 0.4.1 userscript-runner/content-script contract for bundled
ChatGPT automation. The active installer stages the first-class package and registers both
hosts; runtime script sources are packaged and checked rather than fetched as executable
code from arbitrary URLs.

This is preferred over wholesale branch merging because it keeps the existing MCP/
browser-session boundary, allows separate security review, and keeps credentials
unreachable from extension code. Compatibility is maintained at command/event level while
generation/title/URL checks strengthen stale-claim behavior.

For store delivery, use Google's current Chrome Web Store API v2 upload/fetchStatus/publish
endpoints with a protected GitHub environment and short-lived OAuth access tokens minted
from a refresh token. The workflow is manual and exact-SHA bound, defaults to a redacted
dry run, submits with review enabled, and never places credentials in the extension or
release artifacts. The listing ID remains an external prerequisite because the v2 API
updates an existing item; first-time listing creation stays in the Developer Dashboard.

The browser bridge also retries a transient `Page.captureScreenshot` surface error by
bringing the target forward and requesting the non-surface capture path. This mirrors the
existing desktop CUA fallback and preserves background-tab control without weakening other
CDP error handling.
