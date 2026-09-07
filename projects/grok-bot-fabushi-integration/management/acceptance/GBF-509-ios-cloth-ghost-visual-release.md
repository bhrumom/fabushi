# GBF-509 Acceptance Traceability

| Requirement | Implementation | Verification | Evidence | State |
|---|---|---|---|---|
| Desktop idle/background avatar work stops | `fabushi-avatar-runtime.tsx`; existing `BotMark.useAvatarMotionAllowed` | BotMark CI guard + Electron packaged gate + target-Mac measurement | `evidence/GBF-509/README.md`; MSR-106 | IN_PROGRESS |
| Ambient 15 FPS / active 30 FPS cap | `fabushi-avatar-runtime.tsx` | `.github/scripts/assert-bot-mark-motion.py` | `evidence/GBF-509/README.md` | IN_PROGRESS |
| CSS motion pauses on hidden/unfocused app | `ios-white-desktop-theme.css` + root lifecycle marker | renderer build + packaged visual E2E | `evidence/GBF-509/README.md` | IN_PROGRESS |
| Desktop avatar matches iOS cloth-ghost language | `fabushi-avatar-runtime.tsx` adapted from native `ClothGhostAvatar` grammar | renderer typecheck + packaged screenshot/video | `evidence/GBF-509/README.md` | IN_PROGRESS |
| Desktop canonical palette is white/light | `ios-white-desktop-theme.css`; white Windows titlebar overlay | desktop renderer + branding unit test + packaged visual E2E | `evidence/GBF-509/README.md` | IN_PROGRESS |
| One product mark across desktop/iOS/Android | `assets/brand/fabushi-cloth-ghost.svg`; `generate-cloth-ghost-icons.mjs` | deterministic PNG validation + native builds | `evidence/GBF-509/README.md` | IN_PROGRESS |
| iOS App Store icon has no alpha channel | generator emits RGB PNG for opaque app icons | asset catalog/archive/App Store delivery | `evidence/GBF-509/README.md` | IN_PROGRESS |
| Android launcher uses same mark | Gradle `generateFabushiAppIcons` before `preBuild` | Native mobile quality gate + Android release | `evidence/GBF-509/README.md` | IN_PROGRESS |
| iOS launcher uses same mark | XcodeGen target `preBuildScripts` | Native iOS build + Apple delivery | `evidence/GBF-509/README.md` | IN_PROGRESS |
| Coordinated release version | `app-version.json`, desktop/mobile package, iOS project, release-control workflows | CI release-control integrity | `evidence/GBF-509/README.md` | IN_PROGRESS |
| Protected-main delivery | PR -> protected main -> exact-main desktop/mobile delivery | GitHub CI/release run IDs + canonical readback | `evidence/GBF-509/README.md` | IN_PROGRESS |
| Idle-energy closure | packaged 1.2.57 on target Mac settles without sustained double-digit renderer/GPU/host CPU | target-Mac process/energy sample | MSR-106 + GBF-509 evidence | IN_PROGRESS |

No row may become `PASSED` from branch code alone. Exact check/run/release evidence is required.
