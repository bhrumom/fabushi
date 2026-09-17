# 2026-09-12 — Native summary runner queue root cause

Project: `FAB-P0003 / FCM`
Task: `FCM-010.12`
Intake: `[Fabushi:dc7a68a4-8194-41dd-bc00-aa6074cf0323]`

## Evidence from real GitHub Actions history

The schema-v2 latency observer exposed `native-pr-fast` P95 at 1350 seconds even though the native pull-request path performs only lightweight formatting/manifests checks. Two slow successful runs were inspected through the Actions jobs API:

- Native workflow run `34085360999`: `Native Android` waited roughly 17 minutes for its GitHub-hosted runner and then executed for about 27 seconds. The follow-up `Native mobile result` job then waited roughly another 7 minutes to execute a few seconds of aggregation.
- Native workflow run `34085360708`: `Native Android` waited roughly 3 minutes and executed for about 23 seconds. The follow-up `Native mobile result` job then waited roughly 19 minutes and executed for about 3 seconds.

The same topology delayed exact-source canonical delivery for `f87dd9c9aa8fd30b8ec710d370f1c6ffdd3dd094`: Android and iOS product jobs were already successful while the release path still waited on a queued aggregation-only `Native mobile result` runner.

## Decision

Remove the aggregation-only runner and use the real per-platform check runs as release truth:

- Android formal release: `CI result` + `Native Android`.
- iOS formal release: `CI result` + `Native iOS`.
- Combined formal release: required desktop checks + `Native Android` + `Native iOS`.
- Post-main desktop publication waits on `Native Android` and `Native iOS` for the same exact source SHA.

The `native-mobile.yml` workflow keeps the actual Android/iOS matrix unchanged but no longer allocates a second `ubuntu-latest` job merely to restate matrix success.

## Safety rationale

This does not reduce tested surface. It removes a derived check whose only input was `needs.platform.result`. The authoritative platform jobs remain fail-closed, and downstream release gates become more explicit because they name the actual Android and iOS evidence directly. The protected-main ruleset requires `CI result`; it does not require the removed aggregate check name.
