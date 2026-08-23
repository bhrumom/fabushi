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
| FCM-009.1 | Split PR-fast and post-main-heavy events | yes | PR/merge-group has no E2E/installer/debug package jobs; protected main owns heavy gates | planned |
| FCM-009.2 | Incremental Electron desktop builds | yes | native Host/compiler/dependency/renderer reuse across runs with safe cache keys | planned |
| FCM-009.3 | Incremental Android builds | yes | Gradle/JNI/SDK/AVD reuse; clean fallback works | planned |
| FCM-009.4 | Incremental iOS builds | yes | Rust staticlib/Cargo/SwiftPM/DerivedData reuse keyed by Xcode/SDK/project inputs | planned |
| FCM-009.5 | Layer Node dependency/build caches | yes | npm/pnpm cache scopes are lockfile/toolchain aware and reusable across runs | planned |
| FCM-009.6 | Select only affected platforms after main merge | yes | unrelated desktop/mobile platforms skip heavy work | planned |
| FCM-009.7 | Add cache and warm-build telemetry | yes | hit/miss + cold/warm durations captured in Actions evidence | planned |
| FCM-009.8 | Add governance contract for CI/heavy-lane separation | yes | workflow regression test rejects PR E2E/package/debug heavy jobs | planned |
| FCM-009.9 | Prove real warm-cache acceleration | yes | consecutive small-change runs show correct reuse; target >=50% warm-vs-cold reduction | planned |

FAB-P0003 is active again for G4. Historical FCM-001..008 completion evidence remains immutable; FCM-009 is the current active workstream.
