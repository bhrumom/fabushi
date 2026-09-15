# TFI-USERSCRIPT-RECOVERY-017 Evidence

- Project: `FAB-P0001` / `TFI`
- Task: `TFI-USERSCRIPT-RECOVERY-017`
- Status: `IN_PROGRESS`

## Required evidence

- PR head and Platform Control Plane CI results;
- protected canonical-main merge and readback;
- production Worker deployment run, migration/deploy logs and health smoke;
- live `api.ombhrum.com` Chrome catalog response showing userscript `2.9.30`, source commit `480ebe61ba039f15e7023bbc0253ea23c373aba0`, asset size `224113` and SHA-256 `d15040a5d420b0fa4cc38b195f178143a2d22a166e3357f88c7159c6b7a3b14a`;
- direct release metadata response for `chatgpt-auto-confirm@2.9.30`.
- Chrome `0.6.6` packaged artifact containing the Service Worker alarm checker, persisted update status, action badge, startup/Marketplace polling UI, and versioned packaged E2E screenshots/video/trace/report.

Product implementation and production readback are complete; task completion remains blocked only by the Chrome Web Store item being locked by an existing review submission.

## 2026-09-15 exact-main client auto-discovery readback

- Canonical main: `bc22336c5b6d645576575ea4e4919b4658d6f13a`.
- Chrome workflow `34923735666` passed. The `0.6.6` package includes the background checker and the required packaged journey evidence bundle (checkpoint screenshots, complete video segments, trace, HTML report, journey/native logs).
- Production catalog still returns userscript `2.9.30` with the pinned source/hash/size above.
- Web Store publish workflow `34923905837` reached the protected API but returned `400 FAILED_PRECONDITION / NOT_UPDATEABLE`: an existing item submission is still in review. The package was not falsely reported as publicly published; retry is required after that review completes.
- Full machine-readable record: `2026-09-15-client-auto-discovery-main-readback.json`.

## 2026-09-15 live-catalog-first main readback

- Canonical main: `05297b21a684ba826d41bde5c113508103ce196f`.
- Chrome workflow `34925924905` passed; artifact `10379573729` contains `fabushi-chrome-0.6.7.zip` (120660 bytes, SHA-256 `6f2d81af55f7e30e47adb070adf02750e32dce819997e7c0d00dadc868badb80`) and the complete `CWA-007` screenshot/video/trace/report/log bundle.
- The package uses the live Chrome catalog first and only falls back to a connected Host when the live endpoint fails; stale concurrent responses are discarded.
- Web Store publish run `34926076850` again returned `400 FAILED_PRECONDITION / NOT_UPDATEABLE` because an existing submission remains in review. The 0.6.7 package is ready but not claimed as publicly published.
- Full machine-readable record: `2026-09-15-live-catalog-fix-main-readback.json`.
