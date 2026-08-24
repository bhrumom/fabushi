# FCM-009 — Main post-merge E2E / Release / incremental feedback loop

- **Project ID:** FAB-P0003
- **Project Key:** FCM
- **Task ID:** FCM-009
- **Status:** in-progress
- **Started:** 2026-08-24
- **Updated:** 2026-08-24
- **Branch:** `project/fcm-009-main-e2e-release-loop`
- **Supersedes stale setup PR:** #2062 (same objective, older baseline)

## Objective

建立仓库级持续交付闭环：每个 PR 合并到 `main` 后，立即以跨 run 缓存和同 run 产物复用进行最快安装包构建与真实用户 E2E；全部 required E2E 通过后发布绑定该 `main` SHA 的 GitHub Release，并保持 Electron Release 的版本和 updater 资产可供已安装客户端正常更新。

“上一版已安装 App 必须发现新版、显示头像旁更新按钮、点击下载/替换/重启”的真实升级旅程不再是默认强制完成门禁；它保留为可选/建议性回归，或在修改 updater 本身的高风险任务中由该任务单独提升为 required gate。

同时将“每个任务开工前先研究成熟开源方案”升级为 root Agent 强制门禁。

## Source requirements

- `source/2026-08-24-main-e2e-release-open-source-first.md`
- `source/2026-08-24-updater-proof-optional-clarification.md` — latest clarification; supersedes only the previous mandatory old-client updater-proof interpretation.
- 历史相关需求：PR fast / post-main heavy、跨运行增量缓存、GitHub Release updater。

## Existing implementation reused

- Electron `electron-updater` + GitHub publish provider + update-status events。
- Electron Host source-hash binary cache and same-run artifact handoff。
- `Swatinem/rust-cache` / npm cache。
- Android Rust JNI cache、Gradle build cache、AVD snapshot cache。
- iOS Rust staticlib cache、Xcode DerivedData restore-key cache。
- Electron Playwright packaged-user journey、Android instrumentation、iOS UI tests。

## Open-source baseline reviewed before implementation

1. electron-builder / electron-updater — reuse updater metadata and GitHub provider; do not invent a proprietary updater protocol.
2. GitHub `actions/cache` — content-addressed cross-run cache with exact keys + restore keys.
3. Mozilla `sccache` / `mozilla-actions/sccache-action` — compiler-result cache for Rust small-change rebuilds.
4. Playwright CI guidance — keep simulated user verification on built/package artifacts and parallelize where safe.

## Atomic work

1. `FCM-009.1` Root Agent: mandatory open-source-first research record before implementation.
2. `FCM-009.2` Root Agent: every merged application-affecting task requires canonical-main required build/E2E/release evidence before task closure.
3. `FCM-009.3` Preserve PR fast path; heavy installer/E2E/release belongs to post-main delivery.
4. `FCM-009.4` Add canonical post-main delivery workflow that waits for desktop + native-mobile required E2E for the exact main SHA.
5. `FCM-009.5` Publish only after all required E2E pass; release is immutable and bound to exact main SHA.
6. `FCM-009.6` Ensure monotonic desktop versioning per accepted main build so installed clients can compare updates.
7. `FCM-009.7` Require updater assets: DMG + macOS ZIP + `latest-mac.yml` + blockmap; preserve signed/notarized package provenance.
8. `FCM-009.8` Add cache telemetry and warm/cold timing evidence; extend Rust hot path with compiler-result cache where safe.
9. `FCM-009.9` Optional regression: validate update path from a previous release to the new release in automated macOS E2E. This is non-blocking by default.
10. `FCM-009.10` Protected PR merge + required main delivery run + Release + canonical-main readback + closure records.

## Acceptance criteria

- Every merged PR produces a post-main delivery record for its exact SHA; no silent cancellation because a newer commit arrived.
- Desktop + Android + iOS required simulated-user gates are green before publication.
- Failed required E2E blocks Release and leaves the originating task in-progress/blocked/failed.
- Successful required run publishes installable artifacts to GitHub Release.
- Published desktop version is greater than the previous published desktop version and updater metadata is from the same build as the binaries.
- Release keeps updater-compatible assets/versioning. A previous-installed-App discovery/button/download/install/relaunch journey may be run as optional regression evidence, but is not required for ordinary task/Release closure unless that task explicitly promotes it to a required risk gate.
- Cross-run cache miss clean fallback remains correct; warm small-change runs reuse prior compile/build state.
- Root `AGENTS.md` explicitly requires open-source-first startup and required post-main build/E2E/Release evidence before task completion, while marking old-client updater journey proof optional by default.
- FCM-009 is not marked passed until its required work is merged and the new post-main delivery loop succeeds on canonical `main`; optional updater E2E does not block FCM-009 closure.

## Verification / evidence

- GitHub PR / protected checks / merge queue.
- Main SHA and workflow run IDs.
- Electron desktop result + Native mobile result.
- package/E2E artifacts and screenshots/reports.
- cache hit/miss + duration summaries.
- GitHub Release tag/assets/target commit.
- optional macOS previous-release upgrade/update evidence when run.
- canonical `main` readback.

## Risks

- Same-version releases are invisible to `electron-updater`; monotonic version generation is mandatory.
- Releasing every main merge can race; build/test may run in parallel, but publication order needs serialization and stale-release protection.
- Cache pollution must never override source/toolchain/signature provenance.
- GitHub-hosted runners are ephemeral; “热重载式” means persisted content-addressed cache and artifact reuse, not an actually persistent runner process.
- Signing/notarization secrets may block Release even when tests pass; task remains blocked rather than publishing unsigned substitutes.
- Optional updater-journey coverage can miss a regression between dedicated updater changes; updater-specific tasks should explicitly promote that journey to required when risk warrants it.

## Next action

Continue protected-main delivery repair/optimization until required exact-main desktop/native packaged E2E and Release evidence are green; updater journey proof may run independently as optional regression and does not block closure by default.

## 2026-08-24 — Round 2 native shared-host blocker

- Exact main delivery run for `bc4aa98370fe719abee35f50d7f0bec36bf8bc71` correctly blocked publication: Native mobile run `32678047948` ended `failure`.
- Android Compose simulated-user gate: PASS.
- iOS SwiftUI simulated-user gate: PASS.
- Shared Rust host contract: FAIL during `cargo clippy -p mahayana-app-host --all-targets -- -D warnings` because `wayland-sys` could not locate `wayland-client.pc`.
- Root cause is runner provisioning, not product code: Ubuntu shared-host job omitted the Linux native development packages already installed by the Electron Host job.
- Upstream/proven reference is recorded in `source/2026-08-24-fcm-009-native-wayland-dependency.md`.
- Repair: install the same proven native dependency set before shared-host clippy/test. Release remains blocked until the repaired exact-main native gate is green.

## 2026-08-24 — Round 3 merge-queue hygiene blocker

- PR #2083 entered merge queue and created group SHA `983680ab3290f7d0b48d7f5a59382376028cb023`.
- Two obsolete M3 one-shot workflow files immediately produced failed zero-job push runs (`32679156035`, `32679155565`) on the queue branch.
- These recovery drivers target historical branch/issue/job identifiers and are not part of current canonical product validation.
- They are removed so the `ALLGREEN` merge queue evaluates only current reusable gates instead of stale one-shot automation.

## 2026-08-24 — Round 4 deterministic queue entry

- After current-head PR checks were green, native auto-merge could remain armed without creating a `mergeQueueEntry`, leaving protected delivery stuck before merge-group validation.
- GitHub's explicit `enqueuePullRequest` GraphQL mutation is now used after all required product gates pass.
- This does not bypass protection: the merge queue still creates the merge-group commit and requires its configured `CI result` under the ALLGREEN policy before merging.
- Source/provenance: `source/2026-08-24-fcm-009-explicit-merge-queue-enqueue.md`.

## 2026-08-24 — Round 5 updater-proof clarification

- User explicitly clarified that validating a previous installed App discovering the new Release, showing the profile/avatar update control, clicking it, downloading/installing/replacing, and relaunching **does not have to be mandatory**.
- This journey is therefore optional/non-blocking by default. It may still run automatically or manually for regression evidence.
- Required post-main packaged E2E, Release publication, updater-compatible metadata/assets/versioning, signing/notarization, open-source-first, and warm-build integrity remain unchanged.
- When a task directly changes updater behavior, that task may explicitly promote the updater journey to a required acceptance gate based on risk.
