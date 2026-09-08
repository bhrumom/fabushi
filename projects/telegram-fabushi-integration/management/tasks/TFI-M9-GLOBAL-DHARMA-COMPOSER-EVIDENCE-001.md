# TFI-M9-GLOBAL-DHARMA-COMPOSER-EVIDENCE-001

Status: IN_PROGRESS
Project: `FAB-P0001 / TFI`
Parent: `M9-GLOBAL-DHARMA-003`
Source: `projects/telegram-fabushi-integration/source/2026-09-08-global-dharma-composer-evidence-closure.md`
Baseline canonical main: `f443d54d43ecda808c9d52c66bc6ae8dcfe68549`
Execution branch: `fix/tfi-global-dharma-composer-evidence-20260908`

## Atomic objective

Close only the remaining desktop Global Dharma acceptance gaps without adding Android/iOS prerequisites:

1. Make the Bot `打开应用` action a real message-composer control adjacent to `messenger-input`.
2. Add packaged DOM + geometry assertions and a dedicated placement screenshot.
3. Freeze deterministic non-charging Fabushi Pay test-provider acceptance for the original simulated-user request while requiring the canonical PaymentIntent/checkout-callback/entitlement/restore/prayer-wheel chain.
4. Merge through normal PR review/checks, then rerun packaged evidence on the exact resulting canonical `main`, record direct video/diagnostics artifact links and SHA-256 digests, and perform an independent video review.

## Acceptance checks

- [ ] Composer has exactly one visible `miniapp-bot-open`; its header event source is not user-visible.
- [ ] Visible control and `messenger-input` have the same closest composer form.
- [ ] Bounding boxes prove same-row vertical overlap and horizontal adjacency with gap <= 24 px.
- [ ] `03-global-dharma-bot-composer-open-app-adjacent.png` (or successor with the same semantic purpose) clearly shows Bot identity + input + control.
- [x] Payment acceptance boundary is frozen in the source record: `FABUSHI_FEATURE_HOST_MODE=test` is permitted for this original simulated-user packaged acceptance, with no production PSP/KYC claim.
- [ ] Existing full packaged journey still proves CNY 108000 lifetime product, checkout callback, entitlement, restore, account projection, WebMCP/UI revision parity and `local.prayer-wheel.start`.
- [ ] Product change is merged and canonical main SHA is read back.
- [ ] Fresh exact-main packaged run/release evidence contains continuous video(s), screenshots, trace/report/logs/diagnostics, artifact URL(s) and SHA-256 digest(s).
- [ ] Independent post-run video review records PASS against the original journey, including the composer placement.

## Current blockers / constraints

- Local container cannot resolve `github.com`, so no local build/test result is accepted.
- The previously available Mac browser/device control heartbeat became stale during this round; therefore browser-driven ChatGPT-Web orchestration and local video claims are fail-closed until that channel returns.
- Heavy validation remains GitHub Actions only.

## Evidence log

- `2026-09-08`: canonical base read as `f443d54d43ecda808c9d52c66bc6ae8dcfe68549`.
- `2026-09-08`: source/acceptance boundary persisted in commit `1a9f992dcc32061e6aeb0d6e6f398971edaa86b8`.
