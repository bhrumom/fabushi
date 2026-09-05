# M3-DESKTOP-003 — Exact-head test-driven acceptance evidence

- Verdict: `TEST-FAIL/BLOCKED`
- Product PR: `#2349`
- Product exact head: `ec2ca86e7873b340115d3acc69b8b1d2dacda2f0`
- Product base: `arch/fabushi-bot-miniapp-mahayana-20260905@8fb9c16493f6b78a466356137820b57f200f4ed0`
- Workflow: `Electron desktop quality gate`
- Workflow dispatch run: `33959034172` / run number `1673`
- Event: `workflow_dispatch`
- Workflow conclusion: `success`

## Exact-head proof

The manual workflow dispatch resolved and checked out exact product SHA `ec2ca86e7873b340115d3acc69b8b1d2dacda2f0`. The workflow run metadata associates the run with product PR #2349 and architecture base SHA `8fb9c16493f6b78a466356137820b57f200f4ed0`.

All matrix jobs completed successfully:

- Electron Windows: job `101287508002`
- Electron Linux: job `101287508113`
- Electron macOS: job `101287508115`
- Electron desktop result: job `101288301323`

## Packaged returning-user measurements

The tested exact head did **not** reproduce the reported approximately one-minute delayed-completion symptom on any successful packaged measurement. The total Playwright suite runtime is not treated as startup latency.

| Platform | renderer→conversation list | renderer→composer | launch→conversation list | packaged | outcome |
| --- | ---: | ---: | ---: | --- | --- |
| Linux retry | 302.3 ms | 408.8 ms | 647 ms | true | target metric passed |
| macOS | 342.1 ms | 1396.9 ms | 631 ms | true | target metric passed |
| Windows | 458.9 ms | 563.3 ms | 737 ms | true | target metric passed |

The successful traces contain P0-P9, `rootCauseClaim: null`, and exact-head SHA evidence. No approximately 60-second interval appears in the measured P0-P9 path. This record does not infer a bottleneck from the configured history/snapshot constants.

## Required artifacts observed

Exact-head diagnostic artifacts:

- Linux diagnostics `9967402245`, SHA-256 `459ae98ca816b91e6812b9fb7f97eb51d71efe4e6c1f9483c917ce2f4990db1c`
- Windows diagnostics `9967396270`, SHA-256 `6d19fb52024b2ba7da713fd735f90a8d8ffae947ea408d5254f124c752dc9f63`
- macOS diagnostics `9967377178`, SHA-256 `97f9feb033dca295c21e589a6af831eb957242f146356b466c624c6d425e184c`

Each successful returning-user result preserves `startup-performance.json`, `startup-critical-path.json`, and `trace.zip`. HTML Playwright reports and screenshot assets are present in the diagnostics bundles.

## Blocking findings

### BLOCKER — required returning-user video/app-main logs are incomplete

The returning-user startup result directories do not contain a dedicated `.webm` recording for this test. The `.webm` files observed in the diagnostics bundles belong to the separate Grok visual-evidence test. No explicit app/main log artifact for the returning-user packaged run was found. The task contract requires trace, video, screenshots, app/main logs, and exact-head SHA; therefore acceptance fails closed.

### HIGH — Linux packaged returning-user test is flaky

On Linux the packaged returning-user test failed on its first attempt at `desktop/e2e/messenger.spec.ts:367` because `seededConversationId` was the empty string. Playwright then retried the test and the retry passed with the 302.3 ms measurement. The final Linux job is green but the task-critical scenario is not deterministic on first execution.

## Root-cause boundary

No root cause or bottleneck classification is accepted in this test record. The requested one-minute symptom was not reproduced on this exact head, and the evidence package is incomplete. Any follow-up must remain diagnostic/test-only and must not infer a cause from timing constants.

## Gate decision

- Protected canonical-main merge gate: **NOT AUTHORIZED**
- Test/release promotion: **NOT STARTED**
- Stable release: **NOT STARTED**

## Unique next action

Within the frozen M3 diagnostic/test boundary, make the returning-user setup deterministic and preserve a dedicated video plus app/main logs for that exact packaged scenario; then produce a new exact head and rerun `Electron desktop quality gate` via `workflow_dispatch` for renewed test-driven acceptance.
