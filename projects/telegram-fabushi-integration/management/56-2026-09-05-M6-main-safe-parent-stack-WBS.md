# 56 — 2026-09-05 M6 protected-main-safe parent-stack WBS

Status: `ARCHITECTURE-MERGE-BLOCKED / RECOVERY-PLANNED`

| Order | Task | Base rule | Fresh review | Merge prerequisite |
| --- | --- | --- | --- | --- |
| A0 | `TFI-M6-MAINSAFE-ARCH-001` | canonical `main@688465e...` records-only | architecture record audit | records PR only; no product merge |
| A1 | `TFI-M6-MAINSAFE-001-RUST-CANONICAL` | then-current canonical main | required | exact-head required Actions PASS |
| A2 | `TFI-M6-MAINSAFE-002-ELECTRON-PROJECTION` | canonical main after A1 merge/readback | required | A1 canonical + exact-head required Actions PASS |
| A3 | `TFI-M6-MAINSAFE-003-P0-CREATE-JOIN` | canonical main after A2 merge/readback | required | A1+A2 canonical + residual review/Actions PASS |

No parallel product execution is authorized because each upper layer must recompute its residual against the accepted squash-merged canonical main. #2323/#2332/#2333/#2334 remain immutable historical inputs and are not rewritten.

Test-release is outside this WBS until A1-A3 are accepted on canonical main and #2323 residual/equivalence is resolved.