# 2026-09-07 — workflow_run exact-source binding repair

## User requirement / observed failure

Canonical product SHA `43ce998fd5fbcae032c179a8814de9ec08d03f4c` was still running its own Electron/mobile gates when post-main run `34055670967` appeared as a failure. The controller run displays the latest default-branch SHA, while its actual `workflow_run` payload was triggered by Electron run `34055345371` for older accepted source `cf80b3a0b6ddc0670ddd58deb9c8d2c30aeb2075`, whose Electron result was cancelled. The `cf80` failure remains real and must not be rewritten as success, but it is not `43ce` evidence.

## Open-source / upstream review

- GitHub Actions official `workflow_run` documentation: downstream `GITHUB_SHA` / `GITHUB_REF` are the default branch, while the triggering run is exposed through `github.event.workflow_run`; `completed` fires regardless of upstream conclusion. Source: https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows#workflow_run
- GitHub REST workflow-runs API exposes the triggering run's `head_sha`, `event`, `head_branch`, status and conclusion for independent source readback. Source: https://docs.github.com/en/rest/actions/workflow-runs

No external code is copied. Fabushi keeps its existing exact-SHA delivery model and adds readback/evidence at its control-plane boundary.

## Decision

1. Preserve `github.event.workflow_run.head_sha` as delivery source of record.
2. Read back `actions/runs/<upstream-id>` and require `head_sha`, `event=push`, `head_branch=main`, and conclusion to match the event payload before native waiting/publication.
3. Distinguish controller/default-branch SHA from upstream source SHA in Actions run name and summary.
4. Always upload `post-main-source-binding.json` before fail-closing on a non-success upstream result.
5. Do not weaken FCM-009: cancelled/failed accepted-SHA Electron results remain failed delivery evidence; each later canonical SHA owns an independent Electron/mobile/post-main record.
