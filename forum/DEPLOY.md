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