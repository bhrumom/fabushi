# GBF-802 — 灰度/回滚演练

- Project ID: FAB-P0004
- Project Key: GBF
- Task ID: GBF-802
- Stage: M8-release-closure
- Objective: 在不破坏生产发布的前提下验证 rollback target 可定位、不可变、可取回、可校验，并验证发布 workflow 对已有 release/tag 不做原地覆盖。
- Requirements: GBR-010.
- Dependencies: GBF-801.
- Status: IN_PROGRESS
- Branch: `gbf/m8-release-closure-20260822`
- Started/Updated: 2026-08-22 19:52+08

## Acceptance
- [ ] rollback drill workflow 选择最新已发布稳定 release 作为 previous-good target；若不存在必须 fail-closed 并给出 blocker，而不是伪造演练。
- [ ] previous-good tag/commit 可解析且 release assets 可列出；存在 SHA256SUMS 时全部校验通过。
- [ ] release workflow 的 immutable-release guard 被静态/执行门禁验证。
- [ ] drill 产生 run id、target tag/SHA、asset/checksum 证据。
- [ ] protected merge + post-main verification.

## Evidence
`evidence/GBF-802/README.md` plus rollback drill workflow evidence.
