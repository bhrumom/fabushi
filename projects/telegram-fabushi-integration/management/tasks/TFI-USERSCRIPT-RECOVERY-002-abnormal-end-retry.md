# TFI-USERSCRIPT-RECOVERY-002 — 会话异常结束后的新会话重发

- Project ID: `FAB-P0001`
- Project Key: `TFI`
- Task ID: `TFI-USERSCRIPT-RECOVERY-002`
- Status: `IN_PROGRESS`
- Started: `2026-09-11T20:25:00+08:00`
- Updated: `2026-09-11T20:37:00+08:00`
- Source: `source/2026-09-11-userscript-abnormal-end-retry.md`
- Requirements: `TFI-USR-AR-R01`–`TFI-USR-AR-R05`
- Source baseline: userscript `main@9ace3f40858e0c8b56e87b39971f8b6741441200` (`2.9.3`)
- Parent baseline: `bhrumom/fabushi main@6dbd4c9a3e59c03ef2b7c3a672a6feb210840ded`
- Source branch: `codex/abnormal-end-retry-20260911`
- Parent branch: `codex/tfi-userscript-abnormal-end-retry-20260911`

## Objective

Reliably detect a bound ChatGPT conversation that has stably stopped without a final reply or authorization card, including when supervision did not witness the Stop control transition, then use the existing bounded fresh-conversation resend path.

## In scope

- Start the short abnormal-end grace period from a stable clear observation even when the first scan occurs after Stop disappeared.
- Preserve current safeguards and four-attempt ceiling.
- Add focused regression coverage, publish the next userscript version, and retain canonical-main/live evidence.

## Out of scope

- Retrying ambiguous initial sends whose server acceptance is unknown.
- Retrying rate limits, security verification, unrelated conversations or active authorization cards.
- General ChatGPT renderer redesign.

## Acceptance criteria

- [x] `TFI-USR-AR-A01`: A first observation with no Stop/final/card starts a short stable timer without requiring a witnessed Stop transition.
- [x] `TFI-USR-AR-A02`: Stable absence reaches `no-final-reply` after 15 seconds and resets on text/state change.
- [x] `TFI-USR-AR-A03`: Stop, approval, final, blocker, cooldown and ownership safeguards remain fail-closed.
- [x] `TFI-USR-AR-A04`: Existing retry handler creates a fresh conversation intent, clears the old target and remains bounded to four attempts.
- [x] `TFI-USR-AR-A05`: Source syntax and full regression CI pass on PR head and exact canonical source main.
- [x] `TFI-USR-AR-A06`: Monotonically newer release is published from the accepted source SHA.
- [ ] `TFI-USR-AR-A07`: Live Chrome evidence proves missing Stop/final/card → automatic fresh Chat → original prompt resend, with screenshots/video/diagnostics.
- [x] `TFI-USR-AR-A08`: Parent records merge through the protected queue and are read back from canonical main.

## Open-source-first survey

- `microsoft/playwright` (Apache-2.0): official locator guidance favors current user-facing state plus retry/stability checks instead of depending on a single transient DOM transition. Adapt the stability principle; no code copied and no dependency added.
- `browser-use/browser-use` (MIT): its agent loop distinguishes completed output from missing output, counts failures and applies finite retry/termination. Adapt the bounded watchdog lesson; no code copied.
- A new automation framework is rejected because the defect is one missing timer-start transition in the existing state machine.

## Verification plan

- Lightweight local: `node --check chatgpt-auto-confirm.user.js`; `npm test` only. No Fabushi app/native/E2E build locally.
- GitHub: source PR CI and exact-main CI.
- Live: published-version Chrome journey with full evidence required by the parent project.

## Implementation / evidence

- Version: `2.9.4`
- Source commit: `25a3efa7e528f7e5869823b90ebce726a52151e2`
- Source PR: `bhrumom/fabushi-chatgpt-auto-confirm-userscript#2`
- Source PR CI: run `34599085499`, job `103261737943`, PASS
- Canonical source main: `db663373e88b603350c24a73aedb991835509b2a`
- Exact-main CI: run `34599239366`, job `103262227420`, PASS
- Release: `v2.9.4`, release ID `387022144`, target `db663373e88b603350c24a73aedb991835509b2a`, `.user.js` asset 95,716 bytes
- Parent record commit: `4bed810c80ec63499ade4db5c4ebb67273ee2ae2`
- Parent PR: `bhrumom/fabushi#2511`; all five PR checks PASS; merge-group run `34599706374` PASS
- Parent canonical main readback: `2e5151ed38a29130f6f1165639430a825dc2f2ab`
- Live installed-version readback: `2.9.3`; update to 2.9.4 remains required before A07 can run
- Local lightweight syntax: PASS
- Local regression: PASS, 67/67
- Added `abnormalEndSince`: first eligible clear observation starts the clock; stable text retains it; changed text restarts it; ownership/Stop/card/final/blocker/rate-limit cancel it.
- Existing `classify` and bounded resend state machine are reused without changing the four-attempt ceiling.

## Risks and blockers

- Too-short or unguarded idle classification could duplicate a still-starting request; retain ownership, route hydration, blocker/rate-limit, card, Stop and text-stability checks.
- The installed browser may remain on an older published version until the user clicks the Fabushi extension update.

## Next action

Install/update the live browser to 2.9.4, run the abnormal-end journey with complete evidence, and merge/read back the parent evidence records.
