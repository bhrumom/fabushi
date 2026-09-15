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

No completion evidence is claimed until the production deployment and online readback are successful.
