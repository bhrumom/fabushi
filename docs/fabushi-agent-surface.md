# Fabushi Agent Surface — Web MCP, App MCP, and semantic computer fallback

Fabushi exposes one additive Agent Surface contract across its Web, Electron,
iOS, and Android products. The contract makes Fabushi itself directly
understandable and operable by an AI without making structured App MCP support a
prerequisite for controlling the rest of the computer.

## One remote connector, dynamic device tools

External MCP clients still add the same account-scoped remote connector:

```text
https://fabushi-mcp.ombhrum.com/mcp
```

After Fabushi OAuth, `list_devices` returns only devices registered to that
account. Each device publishes its own current tool catalogue. A desktop or CI
Runner that contains this implementation therefore advertises both:

- `fabushi.app.*` — the structured Fabushi App MCP surface;
- the complete existing `computer_*` browser/native/coordinate Computer Use
  surface;
- CI-only session tools when the device is a temporary GitHub Actions Runner.

The remote MCP does not hard-code a product version's App MCP schema. The
account-bound device agent lists its local MCP tools and publishes the exact
schema under the existing device lease and socket-generation boundary.

## Shared App MCP tools

All supported surfaces use the same stable names:

| Tool | Purpose |
| --- | --- |
| `fabushi.app.status` | Report whether the structured Fabushi app surface is available, with route/screen/generation. |
| `fabushi.app.snapshot` | Return a redacted semantic UI snapshot with stable IDs and element state. |
| `fabushi.app.find` | Find elements by stable ID, ref, role, accessible name, or text. |
| `fabushi.app.action` | Invoke/focus/edit/select/toggle/scroll using an exact generation. |
| `fabushi.app.wait` | Wait for a structured route, screen, or element condition. |
| `fabushi.app.assert` | Produce a deterministic assertion and observations for CI evidence. |

`fabushi.app.action` requires the current generation. Every relevant mutation,
route change, or semantic-state publication advances that generation. Stale
refs fail closed instead of clicking a different control after the UI changes.
Password, token, secret, cookie, OTP, and payment credential fields are marked
sensitive; their values are not returned and direct App MCP value writes are
rejected. Sensitive input must continue through the existing encrypted
`secure_input_submit` path.

## Web MCP adapter

The main Fabushi Web application registers the shared tools through the WebMCP
imperative API when `document.modelContext.registerTool()` is available. WebMCP
is feature-detected and progressive: unsupported browsers keep the exact same
contract in the trusted `window.__fabushiAppMcp` host surface, so Electron and
deterministic tests do not depend on a browser experimental flag.

The existing Marketplace and MiniApp WebMCP surfaces remain separate and are
not removed. MiniApps continue to run under their origin, permission, and tool
approval boundaries.

## Electron App MCP bridge

The Electron renderer publishes the semantic surface through a private main
process bridge:

- loopback HTTP only;
- one random high-entropy bearer per app process;
- discovery JSON in the Fabushi user-data directory with mode `0600` and parent
  directory mode `0700` where supported;
- fixed operation allowlist, bounded body/result size, bounded concurrency and
  timeout;
- exact request/response IDs and primary trusted renderer sender checks;
- discovery cleanup and pending-request rejection during app shutdown.

The bridge does **not** expose arbitrary JavaScript, shell, reflection, database,
or internal function execution. The packaged private `fabushi-computer` stdio
MCP lists App MCP tools even when the UI is not running; calls then return a
structured unavailable result. Once the signed Fabushi renderer is running,
the same tools operate its live semantic state.

## Native mobile surfaces

The iOS and Android shells implement the same tool names, element model,
generation protection, sensitive-input rejection, wait, and assertion
semantics using native Swift/Kotlin state. Stable App MCP IDs align with SwiftUI
accessibility identifiers and Compose test tags where practical. This lets
native CI/UI agents operate the application by semantic IDs without image
coordinates and gives a future account-bound mobile device transport the same
contract without redesigning the app.

The current remote device-agent transport is packaged for desktop/Runner
runtimes. iOS/Android validate the native Agent Surface through their native
unit/UI test adapters and retain the existing restricted remote-computer and
MiniApp WebMCP surfaces; adding a background mobile device transport must still
obey each platform's lifecycle and account-credential boundaries.

## Control routing for applications without App MCP

App MCP is an optimization for Fabushi, never the only control path. The bundled
MCP exposes `computer_control_route` and keeps every existing `computer_*` tool.
Agents should use this priority:

1. **App MCP** — `fabushi.app.*` for the Fabushi application.
2. **Browser semantics** — DOM/accessibility snapshots, locators, browser CUA,
   dialogs, downloads, and PDF tools for browser pages and WebViews.
3. **Native semantics** — app/window discovery, AX/UIA/AT-SPI trees, stable
   element refs, advertised native actions, and background app state.
4. **Coordinate fallback** — bounded pointer/keyboard/screenshot Computer Use
   for canvases, games, inaccessible remote surfaces, or only after semantic
   paths are proven unavailable.

macOS AX, Windows UI Automation, Linux AT-SPI/X11, browser CDP/DOM, human-input
preemption, OS permissions, local policy, remote session authorization, and
screen/coordinate fallback all remain intact.

## Recording and regression generation

The existing device trace compiler continues to convert successful interactive
calls into regression candidates. App MCP and native typed values are redacted
from traces while routing metadata, stable target IDs, generation, action kind,
and structured result state remain available. AI exploration can therefore be
promoted into deterministic semantic replay without storing user-entered text
or credentials.

## Test and release gates

The implementation is covered by:

- shared WebMCP/App MCP schema tests;
- Electron private-bridge auth, loopback, limits, cleanup, and stale-generation
  tests;
- packaged runtime file/tool handshake verification;
- Electron Playwright interaction through the real private bridge;
- Android unit and Compose semantic-navigation tests;
- iOS unit and SwiftUI/native delivery tests;
- existing Computer Control security, Electron, Native mobile, Runner live
  session, exact-main package, and post-main release gates.
