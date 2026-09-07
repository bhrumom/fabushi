# GBF-509 — iOS cloth ghost visual parity and cross-platform brand release

- **Project ID:** FAB-P0004
- **Project Key:** GBF
- **Task ID:** GBF-509
- **Status:** in-progress
- **Started:** 2026-09-07T20:39:00+08:00
- **Branch:** `fix/desktop-energy-ghost-white-release`
- **Energy dependency:** `MSR-106`

## User-visible requirement

Ship one new Fabushi version that:

1. makes the desktop Bot/avatar renderer use the same lightweight cloth/ghost silhouette and two-eye visual language as the current iOS `ClothGhostAvatar`;
2. changes the desktop canonical palette from dark to white/light;
3. uses the same cloth-ghost product mark for desktop, iOS, and Android application icons;
4. preserves the existing desktop idle-energy fix and closes the remaining background avatar/CSS motion drain;
5. merges through protected `main` and publishes the new desktop/mobile release artifacts.

## Existing iOS source of truth

`mobile/ios/Fabushi/GrokMobileShell.swift` owns `ClothGhostShape` / `ClothGhostAvatar`: a single lightweight animated vector silhouette, two capsule eyes, identity-derived palette, and a 30 FPS TimelineView rather than a physics/3D engine. Desktop now adapts that visual grammar instead of maintaining a separate mascot family.

## Open-source-first decision

- Electron's official `WebPreferences.backgroundThrottling` defaults to `true` and throttles background animations/timers while integrating with Page Visibility. We retain that platform behavior and add an application-level hard pause on `document.visibilityState` + focus loss instead of adding another scheduler/runtime.
- XcodeGen's official project specification supports target `preBuildScripts` and `basedOnDependencyAnalysis`; the iOS AppIcon generation is integrated there instead of introducing an image-generation package.
- Android uses the existing Gradle `Exec` task primitive and makes `preBuild` depend on deterministic icon generation.
- The icon generator uses Node standard-library modules only (`fs`, `path`, `zlib`) and writes deterministic PNGs, avoiding an additional graphics dependency in release runners.

References:
- https://www.electronjs.org/docs/latest/api/structures/web-preferences
- https://github.com/yonaskolb/XcodeGen/blob/master/Docs/ProjectSpec.md
- https://docs.gradle.org/current/kotlin-dsl/gradle/org.gradle.api.tasks/-exec/index.html

## Implementation slices

- `frontend/apps/web/src/app/host/fabushi-avatar-runtime.tsx`
  - iOS cloth-ghost geometry and palette semantics;
  - `data-avatar-style="ios-cloth-ghost"` / runtime v2;
  - hidden/unfocused hard stop, 15 FPS ambient cap, 30 FPS active cap.
- `desktop/src/ios-white-desktop-theme.css` + `desktop/src/main.tsx`
  - canonical light palette loaded after legacy styles;
  - compositor CSS animations paused while the document lifecycle marker is paused.
- `desktop/scripts/prepare-desktop-window-branding.mjs`
  - Windows native title bar overlay becomes white with dark symbols;
  - migration from the previous dark branded anchor remains idempotent and fail-closed.
- `assets/brand/fabushi-cloth-ghost.svg`
  - canonical static product mark source matching the iOS cloth-ghost silhouette.
- `scripts/generate-cloth-ghost-icons.mjs`
  - deterministic desktop 1024 PNG, complete iOS AppIcon set, Android legacy/round/adaptive foreground assets.
- Native build integration:
  - desktop npm prebuild/prestart;
  - Android Gradle `preBuild` dependency;
  - iOS XcodeGen `preBuildScripts`.
- Release version: `1.2.57`, Android/iOS build number `30`.

## Acceptance

- [ ] Desktop renderer typecheck/build passes.
- [ ] BotMark motion guard passes with iOS cloth-ghost v2 and hard background pause markers.
- [ ] Desktop window-branding tests pass and assert white Windows title chrome.
- [ ] Deterministic icon generator produces valid PNGs for desktop/iOS/Android target sizes.
- [ ] Android native build/quality gate passes with generated launcher assets.
- [ ] iOS native XcodeGen/build gate passes with generated AppIcon assets.
- [ ] PR CI passes against current protected `main`.
- [ ] PR merges to protected `main`; canonical main SHA is read back.
- [ ] Exact-main packaged desktop E2E/Release passes and publishes `v1.2.57` artifacts.
- [ ] Exact-main Android release and Apple delivery pipelines publish/upload the matching 1.2.57 mobile build.
- [ ] Release evidence is recorded under `evidence/GBF-509/` and linked from project status/acceptance/changelog.

## Non-goals

- No new mascot physics/3D engine.
- No background animation when Fabushi is hidden or unfocused.
- No third-party graphics runtime added solely for icon generation.
