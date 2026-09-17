# FCM-025 evidence — ordinary-device no-build / disk safety

## 2026-09-17 implementation round

- Source requirement: `source/2026-09-17-ordinary-device-no-build-disk-safety.md`.
- Root policy: `AGENTS.md` section `CRITICAL: Ordinary devices are control/edit surfaces, never build surfaces`.
- Decision: `decisions/ADR-0006-ordinary-device-build-isolation.md`.
- Verification intentionally uses no local compiler/build/test. Only low-footprint Git inspection/editing and `git diff --check` are used on `bhrum2`; required GitHub checks and protected merge provide canonical delivery evidence.
- Implementation PR #2695 head `81766dbdfff81fdf1054735f073649e2b9e88ef6` passed required `No-test release governance`, `Project portfolio governance`, and `CI result`.
- Protected merge queue merge-group run `35198069214` completed `success`.
- PR #2695 merged at canonical `main` commit `8f06463b5eb7389252d459d28709ab889651aaa6`.
- Canonical readback of `AGENTS.md` confirms the seven-rule `CRITICAL: Ordinary devices are control/edit surfaces, never build surfaces` section, including explicit coverage of `bhrum2`, prohibited build/cache classes, low-footprint allowed operations, fail-closed low-space behavior, bounded prebuilt-artifact deployment, and no implicit local-build exception.
- No local build/test or dependency installation was run for this task; `bhrum2` was used only for low-footprint Git/text/GitHub orchestration allowed by the new policy.
