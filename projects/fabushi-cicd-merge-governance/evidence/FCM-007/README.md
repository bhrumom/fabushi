# FCM-007 evidence — 2026-08-23 PR convergence

## Scope

Evidence for converging the live 2026-08-23 Fabushi pull-request intake into canonical `main` while preserving protected delivery and avoiding stale-stack duplication.

## Canonical landing chain

| Area | Effective PR | Canonical merge commit |
|---|---:|---|
| Mahayana sovereign runtime | #2017 | `6ac1f62ada974956e0ba34c275fd56c4b8fd7c63` |
| Grok Bot final convergence | #2036 | `012569a9ad62925ac33311043439787d45072e2a` |
| Telegram M3→M4→M5 final convergence | #2038 | `8220fdd091c9a9303c194a7257029ba9e4191ccc` |
| Mahayana default CLI vendor-boundary blocker | #2042 | `79e6ed19185c66aaf25691fd2c1d0dec0565f96c` |

DeepSeek integration #1995 and project-registry repair #2040 landed earlier in the same convergence sequence.

## Supersession evidence

- Mahayana #1992/#2000/#2004/#2014: final convergence #2017 explicitly carried the effective auth/secrets/runtime stack and landed on main; lower stacks were then closed.
- #2018: duplicate fix was already represented on canonical main; closed rather than replaying stale history.
- #1967: reverse synchronization from main into an old feature branch, not a main-target effective delta; closed.
- Grok #2032: live changed-file comparison showed all 11 M7 paths are represented in merged #2036; closed only after this comparison.
- Telegram #2037: only post-fork delta was formatting of the M4 contract; canonical #2038 contains the formatted final contract and permanent M4 implementation.
- Telegram #2022: accepted M3 unread/desktop work is carried by #2038. Its unique post-fork `rama-error = 0.2.0-alpha.3` pin was rejected because Mahayana Fast Checks run `32609265654`, job `97119463578`, failed that pinned crate with Rust E0658 `error_generic_member_access`.

## Blocker repair evidence

### Permanent project identity

#1995 introduced the DeepSeek project while the permanent portfolio registry was missing its ID. #2040 repaired the registry before later convergence so branch synchronization could not delete/reuse a permanent FAB project ID.

### Mahayana default dependency graph

Telegram #2038 merge-ref validation exposed default `mahayana-cli` reachability into vendor `codex-core-plugins` and `codex-tui`. #2042 repaired this by adding first-party `mahayana-plugin-archive-compat` and `mahayana-tui-compat` packages and resolving the historical CLI dependency keys to those packages. The source-boundary checker was not weakened.

Final-head validation observed:

- source ownership boundary: success;
- rustfmt: success;
- Mahayana-owned compatibility package tests: success;
- auth/secrets, product client, kernel/bridge, orchestration/workspace, model/agent, MCP and MiniApp fast-check stages: success;
- global Rust workspace test: success;
- project portfolio governance: success;
- #2042 protected/native auto-merge completed to canonical main as `79e6ed19185c66aaf25691fd2c1d0dec0565f96c`.

A non-blocking Native mobile shared-host job on the pre-merge #2042 head exposed a separate runner prerequisite gap (`wayland-client.pc` / `libwayland-dev`). That job did not block #2042 protected merge and no unverified CI-workflow hotfix was included in canonical #2042. This evidence records the observation without falsely claiming it as part of FCM-007 product convergence.

## Final canonical verification before governance-record merge

- canonical `main`: `79e6ed19185c66aaf25691fd2c1d0dec0565f96c`;
- original 13 intake PRs open: **0**;
- effective product/convergence PRs open: **0**;
- live repository open-PR search returned only the FCM governance closure-record PR.

The final governance-record PR carries only FAB-P0003 task/WBS/matrix/status/changelog/evidence synchronization. After that PR merges, a final live open-PR search is required and should return zero.
