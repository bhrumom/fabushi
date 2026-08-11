# iOS E2E WebDriver contract

`appium_flow.py` is the CI-side, CDP-like control surface for the iOS app. It speaks the standard Appium WebDriver HTTP protocol to a loopback-only Appium server and executes versioned JSON flow files.

## Flow v1

A flow contains `schemaVersion: 1`, a name, and an ordered `steps` array. Supported actions are:

- `capture`: screenshot + accessibility page source only.
- `wait` / `assertPresent`: wait for a semantic locator to exist.
- `tap`: wait for the locator, then tap it.
- `type`: wait for the locator, focus it, then type text.

Every successful step automatically writes:

- one PNG screenshot;
- one XML accessibility tree;
- one JSONL timeline record.

A failure also attempts to capture the final screenshot and page source before the WebDriver session is closed.

Coordinates are intentionally forbidden in v1. Tests should use Flutter `Semantics.identifier` values through Appium `accessibility id`, or an iOS predicate over those identifiers. This keeps flows independent from screen size and localized copy.

`{{query}}`, `{{pluginId}}`, and `{{bundleId}}` are available as flow variables. See `flows/global_fabushi_search_open.v1.json` for the production-path marketplace install/search/open scenario.

Example invocation:

```bash
python3 fabushi/tool/ios_e2e/appium_flow.py \
  --udid "$IOS_UDID" \
  --bundle-id com.ombhrum.fabushi \
  --query "全球法布施" \
  --flow fabushi/tool/ios_e2e/flows/global_fabushi_search_open.v1.json \
  --artifacts artifacts/ios
```

The app must already be foregrounded. CI launches it separately so the fixed test-account secret never appears in Appium capabilities or Appium log artifacts.

## Marketplace distribution modes

The GitHub workflow intentionally separates deterministic code acceptance from live Marketplace publication state:

- `fixture` (required for pull requests; default for manual runs) starts `marketplace_fixture.py` on loopback. The fixture builds a deterministic tar.gz from the repository's canonical `.agents/plugins/plugins/global-dharma`, computes its SHA-256 and size, and serves only Marketplace browse/release/download HTTP responses. It never sees `codexHome`, the Simulator data container, or the production installer.
- `live` (forced for scheduled nightly runs; selectable manually) points the same app binary at `https://api.ombhrum.com` and requires an approved live `global-dharma` mobile release. Missing live release state is a real canary failure, not a reason to fall back to the fixture.

Both modes launch the app with the selected `MAHAYANA_API_BASE_URL`, preflight the exact release through Control v1 `marketplace.search`, and then use the same Appium flow. Installation itself is always triggered by the UI and executed by the production Rust installer.

The canonical fixture contract can be checked without an iOS runner:

```bash
python3 fabushi/tool/ios_e2e/marketplace_fixture.py \
  --plugin-root .agents/plugins/plugins/global-dharma \
  --package-file /tmp/global-dharma.tar.gz \
  --metadata-file /tmp/global-dharma.json \
  --commit-sha "$(git rev-parse HEAD)" \
  --build-only
```
