# FCM-025 evidence — ordinary-device no-build / disk safety

## 2026-09-17 implementation round

- Source requirement: `source/2026-09-17-ordinary-device-no-build-disk-safety.md`.
- Root policy: `AGENTS.md` section `CRITICAL: Ordinary devices are control/edit surfaces, never build surfaces`.
- Decision: `decisions/ADR-0006-ordinary-device-build-isolation.md`.
- Verification intentionally uses no local compiler/build/test. Only low-footprint Git inspection/editing and `git diff --check` are used on `bhrum2`; required GitHub checks and protected merge provide canonical delivery evidence.
- PR / merge-group / canonical-main evidence: pending protected merge.
