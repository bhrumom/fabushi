# 2026-09-07 iOS shell-overlay / Marketplace recovery evidence

## Exact failing lineage

- canonical main: `dca0fea5f93567df3928b9a3ee14855ed0da2c67`
- Native mobile run: `34056507262`
- Native iOS job: `101549283506`
- result artifact: `9996206512` / `ios-native-xcresult`
- artifact archive: `https://api.github.com/repos/bhrumom/fabushi/actions/artifacts/9996206512/zip`
- artifact digest: `sha256:a22cad9e330858ed56bec59115385c0b113b2546297b328d5406c6e82fc2fc0b`

## Observed failure

`testHomeMatchesConversationLayoutAndMarketplaceRemainsReachable()` failed on both the first run and retry with `XCTAssertTrue failed` inside `FabushiUITests.openMarketplace(in:)`.

The result activity tree proves:

1. `remote-computer-close` existed but was not hittable.
2. The #2461 fallback retained a screenshot named `remote-computer-close-not-hittable` and then used an element center-coordinate tap.
3. `remote-computer-surface` subsequently disappeared, so the close-surface disappearance assertion itself passed.
4. The next hierarchy contained authenticated Grok home controls including `grok-mobile-legacy`, while `profile-avatar` was absent.
5. Therefore the center-coordinate fallback hit the overlaying `grok-mobile-back` shell control and left the legacy workbench, making the old `openMarketplace(in:)` precondition invalid.

## Atomic repair

- Remove all non-hittable element center-coordinate tapping from the close helper.
- Tap identifier/label close controls only when `isHittable` is true.
- For the known `remote-computer-close` overlay case only, retain a keep-always screenshot and use the explicit hittable `grok-mobile-back` shell control.
- Add `ensureLegacyWorkbench(in:)` before Marketplace navigation: existing `app-shell` is accepted; otherwise require authenticated `grok-mobile-home`, tap `grok-mobile-legacy`, then require `app-shell` before opening profile/Marketplace.
- Preserve `remote-computer-surface.waitForNonExistence(timeout: 10)` unchanged.

## Verification policy

No local Xcode/Gradle/build/test. Local work is limited to text editing and `git diff --check`. Real validation must be GitHub Actions on the PR head and then the protected canonical main SHA. Until those runs and packaged visual evidence exist, acceptance remains `PENDING`.
