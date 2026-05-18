# Deploy Fabushi Forum From The Published Image

This guide turns the forum's published GHCR image into a repeatable preview or production runtime without rebuilding the repository on the target host.

## Files involved

- `docker-compose.deploy.yml`
- `.env.deploy.example`
- `scripts/scaffold-deploy-env.mjs`

The repository workflow `Deploy compose checks - Forum` now boots this same compose path in three deployment postures so the server-facing runtime stays covered in CI:

- sqlite read-only preview
- sqlite writable preview with a shared write-access code
- sqlite production indexing with an explicit public base URL

On a fresh host, the quickest path is now to scaffold `.env.deploy` from a preset instead of hand-editing from a blank file:

```bash
cd forum
pnpm scaffold:deploy-env -- --deploy-env-path .env.deploy
```

That default preset produces the safe read-only preview posture. For the other two deployment shapes, switch the preset and add only the values that are truly required:

```bash
cd forum
pnpm scaffold:deploy-env -- \
  --preset writable-preview \
  --deploy-env-path .env.deploy \
  --write-access-code forum-preview-2026

pnpm scaffold:deploy-env -- \
  --preset production \
  --deploy-env-path .env.deploy \
  --public-base-url https://forum.fabushi.com
```

The scaffold command refuses to overwrite an existing file unless you add `--force true`. Every generated file is immediately passed through the same deploy posture validator used elsewhere in the repository, then prints the next deploy, smoke, and handoff commands.

If you prefer to start from the checked-in example instead, this still works:

```bash
cd forum
cp .env.deploy.example .env.deploy
```

Then edit `.env.deploy` for the target runtime.

`forum/.env.deploy` follows Docker Compose env-file syntax. That means the deploy helpers now accept the same common forms that Compose itself accepts, including:

- quoted values such as `FORUM_IMAGE="ghcr.io/bhrumom/fabushi-forum:main"`
- empty quoted values such as `FORUM_PUBLIC_BASE_URL=""`
- inline comments after a value such as `FORUM_ENABLE_WRITES=true # preview cohort only`

Before you start the compose stack, validate the deploy posture from the same file:

```bash
cd forum
pnpm check:deploy-env -- --deploy-env-path .env.deploy
```

That preflight step surfaces the effective deployment stage, write posture, access-code posture, and any mismatches that would otherwise only show up later during deploy or smoke-check time. It currently warns about cases like:

- preview runtime carrying a public base URL
- production runtime still missing a public base URL
- write access code present while writes are still disabled
- production runtime left writable before governance posture is ready

When `FORUM_DEPLOY_CHECK_URL` is still empty, `pnpm smoke:deploy-env` now falls back to `http://127.0.0.1:${FORUM_PORT}` on the same host. That lets the first compose rollout verify itself before a real preview or production URL exists. `pnpm handoff:live-target` still needs the real external URL unless the deploy env already includes `FORUM_DEPLOY_CHECK_URL`; for production, it can also reuse `FORUM_PUBLIC_BASE_URL` when that public origin is already final.

## Hourly live deployment checks

The repository workflow `Live deployment checks - Forum` can now run every hour against one configured live forum target. This turns the current highest-priority deployment question from a manual reminder into a standing smoke check.

Scheduled runs read either:

- a single repository variable `FORUM_LIVE_TARGET`
- or the existing split repository variables:
  - `FORUM_LIVE_URL`
  - `FORUM_LIVE_DEPLOYMENT_STAGE`
  - `FORUM_LIVE_PUBLIC_BASE_URL`
  - `FORUM_LIVE_WRITES_ENABLED`
  - `FORUM_LIVE_REQUIRES_ACCESS_CODE`
  - `FORUM_LIVE_EXERCISE_WRITE_FLOW`

If both are present, `FORUM_LIVE_TARGET` wins. This keeps the hourly workflow backward-compatible while letting the first real live target be stored as one cohesive bundle instead of six separate values.

If the live target still requires the shared preview code, also store it in the repository secret `FORUM_LIVE_WRITE_ACCESS_CODE`.

Once the target host has a working `forum/.env.deploy` and the runtime is reachable at its real preview or production URL, the shortest recommended handoff is now one command:

```bash
cd forum
pnpm handoff:live-target -- \
  --forum-url https://forum-preview.example.com \
  --deploy-env-path .env.deploy
```

If `.env.deploy` already carries `FORUM_DEPLOY_CHECK_URL`, you can omit `--forum-url`. Production runtimes can also omit it when `.env.deploy` already declares the final `FORUM_PUBLIC_BASE_URL`.

That single entrypoint will:

- re-run the deploy env posture summary
- smoke the live runtime against that same `.env.deploy`
- print the bundled `gh variable set FORUM_LIVE_TARGET ... --repo bhrumom/fabushi` command that matches the verified runtime

The command defaults to `bhrumom/fabushi` as the target repository. If you need a different target, add:

```bash
--github-repo owner/name
```

If the host already has `gh` authenticated and you want to push the verified hourly target into GitHub immediately instead of running the printed commands yourself, add:

```bash
--apply-github-live-target true
```

If the preview runtime is intentionally writable and you want the handoff itself to prove the real thread-and-reply flow before printing or syncing the hourly config, add:

```bash
--exercise-write-flow true
```

If you want the underlying translation outputs directly instead of the full handoff command, the lower-level helper is still available:

```bash
cd forum
node scripts/prepare-live-deployment-vars.mjs \
  --forum-url https://forum-preview.example.com \
  --deploy-env-path .env.deploy
```

That command prints the existing split `FORUM_LIVE_*` block. If you want one bundled JSON payload for the repository variable `FORUM_LIVE_TARGET`, use:

```bash
cd forum
node scripts/prepare-live-deployment-vars.mjs \
  --forum-url https://forum-preview.example.com \
  --deploy-env-path .env.deploy \
  --format json
```

If you want copy-pasteable GitHub CLI commands for the single bundled variable instead, use:

```bash
cd forum
node scripts/prepare-live-deployment-vars.mjs \
  --forum-url https://forum-preview.example.com \
  --deploy-env-path .env.deploy \
  --format github-cli-bundled \
  --github-repo bhrumom/fabushi
```

The original split-variable CLI output is still available too:

```bash
cd forum
node scripts/prepare-live-deployment-vars.mjs \
  --forum-url https://forum-preview.example.com \
  --deploy-env-path .env.deploy \
  --format github-cli \
  --github-repo bhrumom/fabushi
```

When `.env.deploy` includes `FORUM_WRITE_ACCESS_CODE`, both `github-cli` formats also print the matching `gh secret set FORUM_LIVE_WRITE_ACCESS_CODE` command so the shared preview gate stays aligned with the live smoke check.

Recommended preview baseline:

```text
FORUM_LIVE_URL=https://forum-preview.example.com
FORUM_LIVE_DEPLOYMENT_STAGE=preview
FORUM_LIVE_PUBLIC_BASE_URL=
FORUM_LIVE_WRITES_ENABLED=false
FORUM_LIVE_REQUIRES_ACCESS_CODE=false
FORUM_LIVE_EXERCISE_WRITE_FLOW=false
```

Equivalent bundled target:

```json
{
  "forumUrl": "https://forum-preview.example.com",
  "deploymentStage": "preview",
  "publicBaseUrl": "",
  "writesEnabled": false,
  "requiresAccessCode": false,
  "exerciseWriteFlow": false
}
```

When preview writes are intentionally open behind the shared code, switch only the runtime flags you actually expect:

```text
FORUM_LIVE_WRITES_ENABLED=true
FORUM_LIVE_REQUIRES_ACCESS_CODE=true
FORUM_LIVE_EXERCISE_WRITE_FLOW=true
```

The hourly workflow now validates that live-target settings describe a coherent runtime before it makes any HTTP requests. It will fail fast when the repository variables disagree with each other, including these cases:

- `FORUM_LIVE_REQUIRES_ACCESS_CODE=true` while `FORUM_LIVE_WRITES_ENABLED=false`
- `FORUM_LIVE_EXERCISE_WRITE_FLOW=true` outside preview mode
- `FORUM_LIVE_EXERCISE_WRITE_FLOW=true` while writes are still disabled
- `FORUM_LIVE_EXERCISE_WRITE_FLOW=true` and `FORUM_LIVE_REQUIRES_ACCESS_CODE=true` without the secret `FORUM_LIVE_WRITE_ACCESS_CODE`

If `FORUM_LIVE_URL` and `FORUM_LIVE_TARGET` are both empty, the hourly workflow exits cleanly without failing. Manual `workflow_dispatch` runs keep working with the explicit inputs.

The hourly workflow now also writes a job summary for both skip and check paths, so the run itself tells you which target posture it resolved and whether the repository variables are still incomplete. When preview checks carry a public base URL, or production checks still omit one, the summary also surfaces that mismatch as a warning instead of leaving it buried in the smoke-check logs.

Live HTTP requests now time out after 15 seconds per call. That keeps an unreachable preview or production target from leaving the hourly workflow hanging for too long before it reports the failure.

## Preview baseline

Keep the safe default first. The new scaffold command is the shortest way to get there:

```bash
pnpm scaffold:deploy-env -- --deploy-env-path .env.deploy
```

Equivalent deploy env:

```dotenv
FORUM_IMAGE=ghcr.io/bhrumom/fabushi-forum:main
FORUM_PORT=3000
FORUM_DATA_DIR=./data
FORUM_DEPLOY_CHECK_URL=
FORUM_DEPLOYMENT_STAGE=preview
FORUM_PUBLIC_BASE_URL=
FORUM_DATA_SOURCE=sqlite
FORUM_ENABLE_WRITES=false
FORUM_WRITE_ACCESS_CODE=
```

Start the forum:

```bash
docker compose --env-file .env.deploy -f docker-compose.deploy.yml up -d
pnpm smoke:deploy-env -- --deploy-env-path .env.deploy
curl http://localhost:3000/api/health
curl http://localhost:3000/api/status
curl http://localhost:3000/robots.txt
```

The smoke command derives the expected runtime directly from `.env.deploy` and verifies the deployed forum's health endpoint, runtime status, headers, `robots.txt`, and page metadata against that same file.

Once this local or server-side preview is reachable at its real target URL, run the one-command handoff so the hourly repository variable stays aligned with the verified runtime:

```bash
pnpm handoff:live-target -- \
  --forum-url https://forum-preview.example.com \
  --deploy-env-path .env.deploy
```

Expected preview signals:

- `/api/health` returns `ready: true`
- `/api/status` reports `deploymentStage=preview`
- `robots.txt` contains `Disallow: /`
- sqlite stays durable but read-only until writes are explicitly opened

## Writable preview cohort

Only open writes when the preview runtime is ready to accept real submissions.

The shortest path is:

```bash
pnpm scaffold:deploy-env -- \
  --preset writable-preview \
  --deploy-env-path .env.deploy \
  --write-access-code forum-preview-2026 \
  --force true
```

Equivalent runtime flags:

```dotenv
FORUM_ENABLE_WRITES=true
FORUM_WRITE_ACCESS_CODE=forum-preview-2026
```

After restarting the compose stack, the runtime stays preview-only and still requires the shared code before thread or reply creation succeeds.

To validate the writable preview against the same deploy env and also exercise the live thread-and-reply path, run:

```bash
pnpm handoff:live-target -- \
  --forum-url http://127.0.0.1:3000 \
  --deploy-env-path .env.deploy \
  --exercise-write-flow true
```

Add `--apply-github-live-target true` when you want the verified bundled live target and preview access-code secret written to GitHub immediately.

## Production indexing runtime

Switch the deployment boundary only when the public origin is ready.

The shortest path is:

```bash
pnpm scaffold:deploy-env -- \
  --preset production \
  --deploy-env-path .env.deploy \
  --public-base-url https://forum.fabushi.com \
  --force true
```

Equivalent runtime flags:

```dotenv
FORUM_DEPLOYMENT_STAGE=production
FORUM_PUBLIC_BASE_URL=https://forum.fabushi.com
FORUM_ENABLE_WRITES=false
```

Bring the stack back up and verify:

```bash
docker compose --env-file .env.deploy -f docker-compose.deploy.yml up -d
pnpm smoke:deploy-env -- --deploy-env-path .env.deploy
curl https://forum.fabushi.com/api/health
curl https://forum.fabushi.com/api/status
curl https://forum.fabushi.com/robots.txt
```

Once the production origin is correct, the handoff can now stay fully deploy-env driven even if `FORUM_DEPLOY_CHECK_URL` is blank:

```bash
pnpm handoff:live-target -- \
  --deploy-env-path .env.deploy \
  --apply-github-live-target true
```

If you want the same production host run to boot the compose stack, verify the local runtime, and sync the hourly target in one pass, the combined rollout helper now follows the same `FORUM_PUBLIC_BASE_URL` fallback:

```bash
pnpm rollout:deploy-env -- \
  --deploy-env-path .env.deploy \
  --apply-github-live-target true
```

That combined helper still smokes the local runtime through `http://127.0.0.1:${FORUM_PORT}` when `FORUM_DEPLOY_CHECK_URL` is blank, then hands the verified hourly target off using `FORUM_PUBLIC_BASE_URL`.

Expected production signals:

- `/api/health` returns `ready: true`
- `/api/status` reports `deploymentStage=production`
- `robots.txt` allows crawling
- page metadata resolves canonical URLs against `FORUM_PUBLIC_BASE_URL`
- headers stop advertising the preview noindex posture