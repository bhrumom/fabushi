# WBS 原子任务

| Task ID | Atomic task | Required | Acceptance | Status |
|---|---|---:|---|---|
| FCM-001.1 | Fix merge-group impact classification | yes | merge-group diff no longer force-all; correct base/head | passed |
| FCM-001.2 | Add docs fast path + unknown fail-safe | yes | docs selects no product jobs; unknown code selects all | passed |
| FCM-001.3 | Make automerge merge-queue-aware | yes | no direct protected-branch REST merge | passed |
| FCM-001.4 | Gate Worker CD by changed inputs | yes | unrelated main changes stop after impact resolver | passed |
| FCM-001.5 | Gate Fabushi Pay CD by changed inputs | yes | unrelated main changes stop after impact resolver | passed |
| FCM-001.6 | Update enterprise branch/merge policy | yes | policy matches implementation | passed |
| FCM-001.7 | Validate PR + merge queue + record timing | yes | required CI success and merge through queue | passed |
| FCM-002 | Establish CI latency SLO dashboard/measurement | yes | Actions metadata observer tracks validation-surface P50/P95 + queue delay and stores artifacts | passed |
| FCM-003 | Classify Agent/Skill governance paths without weakening runtime fail-safe | yes | `.agent/skills/**` governance-safe; runtime/unknown safety preserved | passed |
| FCM-004 | Align Apple/Google store delivery with canonical release gates | yes | exact SHA is on protected main and required CI/platform gates are green before build/upload | passed |
| FCM-005 | Add narrow sensitive-path ownership and governance contract | yes | CODEOWNERS covers Tier-3 paths without catch-all; contract validates invariants | passed |
| FCM-006 | Close project records and verify canonical main | yes | full enterprise scaffold + PR/CI/merge evidence + post-merge main verification | passed |
| FCM-007 | Converge all 2026-08-23 intake PRs into canonical main | yes | every intake PR merged or proven superseded; no accepted change lost; final intake open count = 0 | passed |
| FCM-008 | Build latest canonical macOS Electron package and provide download | yes | exact product source; Developer ID signed; Apple notarized + stapled; Gatekeeper accepted; target-Mac launch; permanent release gate merged and reverified | passed |
| FCM-009 | Main post-merge E2E / Release / incremental feedback loop | yes | all required FCM-009 items pass with protected merge + real post-main Release evidence; optional FCM-009.9 does not block closure | in-progress |
| FCM-009.1 | Require open-source-first research before implementation | yes | root Agent + task record require upstream architecture/license/security/maintenance review | implemented |
| FCM-009.2 | Require post-main package/E2E/Release evidence before task closure | yes | root Agent blocks product-task completion until exact-main required packaged E2E + verified Release | implemented |
| FCM-009.3 | Preserve PR fast path and move heavy package/E2E post-main | yes | Electron/native PR checks are lightweight; installer/emulator/simulator/Playwright heavy work runs on main | implemented |
| FCM-009.4 | Run full canonical desktop + Android + iOS user gates for every main SHA | yes | main push uses SHA-isolated concurrency; Electron and Native mobile result are exact-SHA green | implemented |
| FCM-009.5 | Publish only tested exact-SHA artifacts | yes | post-main workflow reuses exact Electron run artifacts and waits exact-SHA native result before Release | implemented |
| FCM-009.6 | Give every main desktop delivery a monotonic update-comparable version | yes | Electron main package version is `major.minor.<electron-run-number>` and all platform manifests agree | implemented |
| FCM-009.7 | Preserve updater assets and signed/notarized macOS provenance | yes | DMG + ZIP + `latest-mac.yml` + ZIP blockmap validated before Release | implemented |
| FCM-009.8 | Reuse compiler/build state and expose cache telemetry | yes | source-hash host/JNI/staticlib + Gradle/AVD/DerivedData + sccache stats and warm cache summaries | implemented |
| FCM-009.9 | Optionally prove old macOS Release can detect/click/install new Release | no | advisory release E2E may launch prior app, observe update cloud, click, and verify bundle replacement; failure is non-blocking by default | optional |
| FCM-009.10 | Protected merge + canonical main delivery + Release closure | yes | PR merged, exact-main desktop/native required gates green, stable Release published, main readback | pending |
| FCM-009.11 | Retain mandatory pass/fail visual evidence for every canonical-main required E2E | yes | step screenshots + complete video + trace/report/log + exact-SHA metadata retained on pass and failure | implemented |
| FCM-009.12 | Stabilize peer-switch E2E against dynamic peer-list reorder | yes | bind peers by stable test IDs; preserve #2122 header/info-panel identity assertions; exact-main Electron Linux/macOS/Windows journeys green | in-progress |
| FCM-009.13 | Make workflow_run delivery source identity explicit and independently verifiable | yes | downstream run records controller SHA separately from upstream Electron source/run, API readback matches push/main/head SHA/conclusion, and binding JSON is retained before fail-closed conclusion gate | in-progress |
| FCM-010 | Reduce PR CI hot-path latency with targeted classification and warm caches | yes | PR uses targeted Mahayana fast checks; heavyweight embedded-Codex matrix is post-merge; runtime edits avoid force-all; Next/Worker/Rust caches restore safely; protected merge evidence recorded | in-progress |
| FCM-010.1 | Move heavyweight embedded-Codex desktop matrix off PR while preserving Mahayana targeted PR checks | yes | PR uses `mahayana-fast-checks`; push/main/manual uses Ubuntu/macOS/Windows heavyweight matrix | implemented |
| FCM-010.2 | Restore Mahayana Cargo build state across canonical heavy runs | yes | rust-cache restore/save visible and cold fallback passes | implemented |
| FCM-010.3 | Classify isolated Mahayana runtime changes without unknown force-all | yes | classifier selects only affected architecture domain | implemented |
| FCM-010.4 | Restore Next.js incremental build cache | yes | `.next/cache` restored/saved on frontend run | implemented |
| FCM-010.5 | Restore Fabushi Pay Worker Rust build state | yes | pay Worker target cache restored/saved on worker run | implemented |
| FCM-010.6 | Merge optimized CI through protected main | yes | required PR checks/queue succeed and canonical main readback confirms definitions | pending |
| FCM-010.7 | Verify post-merge heavyweight validation and cache behavior | yes | exact-main embedded-Codex run starts on all three OSes and cache steps execute | pending |
| FCM-010.8 | Enforce one product platform per runner allocation | yes | Electron PR uses one Linux runner; main uses one macOS, one Windows, one Linux runner; native main uses one Android and one iOS runner; release packaging uses one runner per product platform with only a non-build control-plane publisher | implemented |
| FCM-012 | Repair production D1 migration and deploy marketplace through Platform Control Plane Action | yes | protected merge; D1 migration succeeds; Worker deploy succeeds; official marketplace search is live | in-progress |

`implemented` means the implementation exists but canonical protected merge/post-main acceptance may still be pending. `optional` means useful regression evidence that is not a default task-completion gate. FCM-009 must remain `in-progress` until FCM-009.10 has objective GitHub Actions + Release evidence; FCM-009.9 is not required for closure. FCM-009.12 remains `in-progress` until its repair is merged and the exact canonical-main Electron gate is green on all required desktop platforms. FCM-010 remains `in-progress` until its optimized PR is merged and measured on canonical `main`. FCM-012 remains `in-progress` until the production Action and live marketplace search acceptance checks pass.
| FCM-013 | Release Fabushi 1.2.1 across canonical desktop/mobile/web/backend channels | yes | protected merge + exact-main platform gates + immutable releases + store delivery evidence + runtime verification | in-progress |

| FCM-014 | Release Fabushi 1.2.2 across canonical desktop/mobile/web/backend channels | yes | protected merge + exact-main platform gates + immutable releases + store delivery evidence + runtime verification | in-progress |
| FCM-015 | Release Fabushi 1.2.6 from canonical main and repair false Linux AppImage blockmap gate | yes | all intake PRs dispositioned; protected merge; exact-main required gates; v1.2.6 five-platform assets; supported delivery channels; install/upgrade/runtime verification | in-progress |
| FCM-016 | Release Fabushi 1.2.7 with canonical automatic store delivery | yes | all intake PRs dispositioned; protected merge; exact-main required gates; immutable five-platform Release; Android GitHub/Google Play + Apple Store delivery; production deploy; install/upgrade/runtime verification | in-progress |
