# TFI-USERSCRIPT-RECOVERY-002 evidence index

Status: `IN_PROGRESS`

## Current evidence

- User screenshot, 2026-09-11 20:20 Asia/Shanghai: bound ChatGPT conversation contains tool-call rows, no final assistant reply, no authorization card, and no Stop control beside the composer.
- Root cause: 2.9.3 only initialized its 15-second `endedAt` clock after observing an actual Stop-to-clear transition; late observation left `endedAt=0` indefinitely until the five-minute fallback.
- Source commit: `25a3efa7e528f7e5869823b90ebce726a52151e2`.
- Source PR: `bhrumom/fabushi-chatgpt-auto-confirm-userscript#2`.
- Lightweight local syntax check: PASS.
- Local regression suite: PASS, 67/67; new late-observation test covers timer start, stable retention, text-change reset and all cancellation guards.
- Source PR #2: merged to `main@db663373e88b603350c24a73aedb991835509b2a`.
- PR CI: run `34599085499`, job `103261737943`, PASS.
- Exact-main CI: run `34599239366`, job `103262227420`, PASS.
- Release: `v2.9.4`, release ID `387022144`, target `db663373e88b603350c24a73aedb991835509b2a`; attached `chatgpt-auto-confirm.user.js` (95,716 bytes).
- Live pre-acceptance observation: the original screenshot route later moved to a fresh route with the same task prompt and an active Stop control. This proves the legacy long fallback eventually retried, but does not prove the new 15-second 2.9.4 path.
- Live root version readback: `2.9.3`; the published 2.9.4 path is not installed yet.
- Parent records: PR #2511, five PR checks PASS, merge-group run `34599706374` PASS, canonical `main@2e5151ed38a29130f6f1165639430a825dc2f2ab` read back.

## Pending closure evidence

- Live Chrome screenshots, complete video and diagnostics for abnormal end → fresh Chat → original prompt resend.

No Fabushi application/native build or E2E was run locally.
