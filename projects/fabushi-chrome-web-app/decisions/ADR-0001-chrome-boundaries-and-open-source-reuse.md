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
