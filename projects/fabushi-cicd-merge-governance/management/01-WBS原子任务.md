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
| FCM-009 | Main post-merge E2E / Release / incremental feedback loop | yes | FCM-009.1–FCM-009.10 all pass with protected merge + real post-main Release evidence | in-progress |
| FCM-009.1 | Require open-source-first research before implementation | yes | root Agent + task record require upstream architecture/license/security/maintenance review | implemented |
| FCM-009.2 | Require post-main package/E2E/Release evidence before task closure | yes | root Agent blocks product-task completion until exact-main packaged E2E + Release/updater proof | implemented |
| FCM-009.3 | Preserve PR fast path and move heavy package/E2E post-main | yes | Electron/native PR checks are lightweight; installer/emulator/simulator/Playwright heavy work runs on main | implemented |
| FCM-009.4 | Run full canonical desktop + Android + iOS user gates for every main SHA | yes | main push uses SHA-isolated concurrency; Electron and Native mobile result are exact-SHA green | implemented |
| FCM-009.5 | Publish only tested exact-SHA artifacts | yes | post-main workflow reuses exact Electron run artifacts and waits exact-SHA native result before Release | implemented |
| FCM-009.6 | Give every main desktop delivery a monotonic update-comparable version | yes | Electron main package version is `major.minor.<electron-run-number>` and all platform manifests agree | implemented |
| FCM-009.7 | Preserve updater assets and signed/notarized macOS provenance | yes | DMG + ZIP + `latest-mac.yml` + ZIP blockmap validated before Release | implemented |
| FCM-009.8 | Reuse compiler/build state and expose cache telemetry | yes | source-hash host/JNI/staticlib + Gradle/AVD/DerivedData + sccache stats and warm cache summaries | implemented |
| FCM-009.9 | Prove old macOS Release can detect/click/install new Release | yes | release-published macOS E2E launches prior app, waits update cloud, clicks, and verifies bundle version replacement | implemented |
| FCM-009.10 | Protected merge + canonical main delivery + Release closure | yes | PR merged, exact-main desktop/native gates green, stable Release published, release E2E green, main readback | pending |

`implemented` means the branch contains the implementation but canonical protected merge/post-main acceptance is still pending. FCM-009 must remain `in-progress` until FCM-009.10 has objective GitHub Actions + Release evidence.
