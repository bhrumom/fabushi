# TFI-M9-GLOBAL-DHARMA-COMPOSER-EVIDENCE-001

Status: IN_PROGRESS
Project: `FAB-P0001 / TFI`
Parent: `M9-GLOBAL-DHARMA-003`
Source: `projects/telegram-fabushi-integration/source/2026-09-08-global-dharma-composer-evidence-closure.md`
Baseline canonical main: `f443d54d43ecda808c9d52c66bc6ae8dcfe68549`
Primary implementation branch: `fix/tfi-global-dharma-composer-evidence-20260908`
Independent-review follow-up branch: `fix/tfi-global-dharma-composer-clarity-20260908`

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
- [ ] The message textarea remains visibly usable (packaged 1280x800 evidence: width >= 240 px and >= 35% of the composer) while `打开应用` stays a compact 72..120 px action.
- [ ] `03-global-dharma-bot-composer-open-app-adjacent.png` (or successor with the same semantic purpose) clearly shows Bot identity + a recognizable message input + the adjacent `打开应用` control.
- [x] Payment acceptance boundary is frozen in the source record: `FABUSHI_FEATURE_HOST_MODE=test` is permitted for this original simulated-user packaged acceptance, with no production PSP/KYC claim.
- [ ] Existing full packaged journey still proves CNY 108000 lifetime product, checkout callback, entitlement, restore, account projection, WebMCP/UI revision parity and `local.prayer-wheel.start`.
- [ ] Final product change is merged and canonical main SHA is read back.
- [ ] Fresh exact-main packaged run/release evidence contains continuous video(s), screenshots, trace/report/logs/diagnostics, artifact URL(s) and SHA-256 digest(s).
- [ ] Independent post-run video review records PASS against the original journey, including the composer placement and visible input width.

## Current blockers / constraints

- Local container cannot resolve `github.com`, so no local build/test result is accepted.
- The previously available Mac browser/device control heartbeat became stale during this round; therefore browser-driven ChatGPT-Web orchestration and local video claims are fail-closed until that channel returns.
- Heavy validation remains GitHub Actions only.

## Evidence log

- `2026-09-08`: canonical base read as `f443d54d43ecda808c9d52c66bc6ae8dcfe68549`.
- `2026-09-08`: source/acceptance boundary persisted in commit `1a9f992dcc32061e6aeb0d6e6f398971edaa86b8`.
- `2026-09-08`: PR `#2491` merged product/evidence infrastructure to canonical `main@7ea5055b1e0d7ee078d0d21321b5884fa93bead2`.
- `2026-09-08`: exact-main Electron run `34247800385` succeeded and original macOS diagnostics artifact `10065155690` was uploaded with digest `sha256:61210d47e07a505e84dc029efa72911628edf0851e1b5617edefcf9aaf730d24`.
- `2026-09-08`: exact-main evidence publisher run `34249021829` succeeded and created immutable prerelease `global-dharma-evidence-7ea5055b1e0d` bound to the tested SHA.
- `2026-09-08`: independent visual review **REJECTED** that otherwise-green evidence. The dedicated composer screenshot showed `打开应用` stretched across nearly the full composer while the actual `消息` textarea had collapsed to a narrow sliver. The existing same-form/gap/overlap assertions were therefore insufficient to prove a clear usable input beside the button. The direct release remains valid historical evidence but is not accepted as final PASS for this task.
- `2026-09-08`: follow-up tightens both product layout and packaged geometry acceptance: textarea width >= 240 px and >= 35% composer share, open action width 72..120 px, while retaining the original same-form/gap/overlap constraints and screenshot.
