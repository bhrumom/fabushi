# FCM-012 — Platform control-plane D1 Action deploy repair

- Project: `FAB-P0003 / FCM`
- Status: in-progress
- Source: user request on 2026-08-26 to deploy the marketplace repair through GitHub Actions.

## Objective
Restore the production `Platform Control Plane` GitHub Actions deployment so the approved official Mini App seed migration is applied to the authoritative Cloudflare D1 database and the Mahayana platform Worker deploy completes.

## Observed failure
Action run `32951688683` reached `Apply production platform migrations` and failed with Cloudflare D1 `SQLITE_AUTH / not authorized`. The rejected migration attempted `PRAGMA foreign_keys = ON` inside a D1 migration transaction.

## Open-source / official-source review
- Cloudflare D1 migration and foreign-key documentation confirms D1 enforces foreign keys during migrations and does not allow user queries to change `PRAGMA foreign_keys` inside the implicit transaction.
- Decision: preserve the migration data model and remove only the unsupported pragma; do not weaken foreign-key enforcement.

## Acceptance criteria
1. PR passes required protected-branch checks and merges through the merge queue.
2. Main `Platform Control Plane` Action applies `0009_official_marketplace_seed.sql` successfully.
3. The same Action deploys `mahayana-platform` successfully.
4. Production `GET /v1/marketplace/plugins?platform=desktop` returns the official catalog in addition to existing approved entries.
5. Production search for `全球法布施` returns `global-dharma` and search for `bot` returns `bot-father`.
6. Evidence includes PR, merge SHA, Action run/job IDs and production API verification.

## Rollback
If the migration or deployment fails, keep the task in-progress, inspect the Action logs, and repair the migration in a follow-up protected PR. Do not bypass D1/branch protections with direct production writes.
