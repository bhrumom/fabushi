# Deploy Fabushi Forum From The Published Image

This guide turns the forum's published GHCR image into a repeatable preview or production runtime without rebuilding the repository on the target host.

## Files involved

- `docker-compose.deploy.yml`
- `.env.deploy.example`

The repository workflow `Deploy compose checks - Forum` now boots this same compose path in three deployment postures so the server-facing runtime stays covered in CI:

- sqlite read-only preview
- sqlite writable preview with a shared write-access code
- sqlite production indexing with an explicit public base URL

Copy the example environment file first:

```bash
cd forum
cp .env.deploy.example .env.deploy
```

Then edit `.env.deploy` for the target runtime.

## Hourly live deployment checks

The repository workflow `Live deployment checks - Forum` can now run every hour against one configured live forum target. This turns the current highest-priority deployment question from a manual reminder into a standing smoke check.

Scheduled runs read these repository variables:

- `FORUM_LIVE_URL`
- `FORUM_LIVE_DEPLOYMENT_STAGE`
- `FORUM_LIVE_PUBLIC_BASE_URL`
- `FORUM_LIVE_WRITES_ENABLED`
- `FORUM_LIVE_REQUIRES_ACCESS_CODE`
- `FORUM_LIVE_EXERCISE_WRITE_FLOW`

If the live target still requires the shared preview code, also store it in the repository secret `FORUM_LIVE_WRITE_ACCESS_CODE`.

Recommended preview baseline:

```text
FORUM_LIVE_URL=https://forum-preview.example.com
FORUM_LIVE_DEPLOYMENT_STAGE=preview
FORUM_LIVE_PUBLIC_BASE_URL=
FORUM_LIVE_WRITES_ENABLED=false
FORUM_LIVE_REQUIRES_ACCESS_CODE=false
FORUM_LIVE_EXERCISE_WRITE_FLOW=false
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

If `FORUM_LIVE_URL` is still empty, the hourly workflow exits cleanly without failing. Manual `workflow_dispatch` runs keep working with the explicit inputs.

The hourly workflow now also writes a job summary for both skip and check paths, so the run itself tells you which target posture it resolved and whether the repository variables are still incomplete. When preview checks carry a public base URL, or production checks still omit one, the summary also surfaces that mismatch as a warning instead of leaving it buried in the smoke-check logs.

Live HTTP requests now time out after 15 seconds per call. That keeps an unreachable preview or production target from leaving the hourly workflow hanging for too long before it reports the failure.

## Preview baseline

Keep the safe default first:

```dotenv
FORUM_IMAGE=ghcr.io/bhrumom/fabushi-forum:main
FORUM_PORT=3000
FORUM_DATA_DIR=./data
FORUM_DEPLOYMENT_STAGE=preview
FORUM_PUBLIC_BASE_URL=
FORUM_DATA_SOURCE=sqlite
FORUM_ENABLE_WRITES=false
FORUM_WRITE_ACCESS_CODE=
```

Start the forum:

```bash
docker compose --env-file .env.deploy -f docker-compose.deploy.yml up -d
curl http://localhost:3000/api/health
curl http://localhost:3000/api/status
curl http://localhost:3000/robots.txt
```

Expected preview signals:

- `/api/health` returns `ready: true`
- `/api/status` reports `deploymentStage=preview`
- `robots.txt` contains `Disallow: /`
- sqlite stays durable but read-only until writes are explicitly opened

## Writable preview cohort

Only open writes when the preview runtime is ready to accept real submissions.

```dotenv
FORUM_ENABLE_WRITES=true
FORUM_WRITE_ACCESS_CODE=forum-preview-2026
```

After restarting the compose stack, the runtime stays preview-only and still requires the shared code before thread or reply creation succeeds.

## Production indexing runtime

Switch the deployment boundary only when the public origin is ready:

```dotenv
FORUM_DEPLOYMENT_STAGE=production
FORUM_PUBLIC_BASE_URL=https://forum.fabushi.com
FORUM_ENABLE_WRITES=false
```

Bring the stack back up and verify:

```bash
docker compose --env-file .env.deploy -f docker-compose.deploy.yml up -d
curl http://localhost:3000/api/health
curl http://localhost:3000/api/status
curl http://localhost:3000/robots.txt
curl -I http://localhost:3000/threads
```

Expected production signals:

- `/api/health` and `/api/status` both report `deploymentStage=production`
- indexing becomes enabled only after `FORUM_PUBLIC_BASE_URL` is also set
- `robots.txt` switches to `Allow: /` and includes the configured `Host:`
- page responses stop emitting the preview `x-robots-tag`

## Rolling to a newer forum image

Update only the image tag in `.env.deploy`, then refresh the stack:

```dotenv
FORUM_IMAGE=ghcr.io/bhrumom/fabushi-forum:sha-<commit>
```

```bash
docker compose --env-file .env.deploy -f docker-compose.deploy.yml pull
docker compose --env-file .env.deploy -f docker-compose.deploy.yml up -d
```

This keeps the deploy path aligned with the already published forum artifact instead of rebuilding from source on the server.
