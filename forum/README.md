# Fabushi Forum

This directory is the independent root for the forum project.

## What exists now

The forum is no longer being extended inside the marketing website. This directory now contains a standalone Next.js app skeleton so the project can move from an empty placeholder into something runnable, testable, and deployable on its own.

Current scope:

- independent app shell under `forum/src/app`
- structured seed content under `forum/src/data/forum-content.json`
- forum domain helpers under `forum/src/lib/forum-data.ts`
- a repository boundary that keeps page rendering and API routes behind one forum data source contract
- read-only routes for thread listing, thread detail, runtime status, and deployment health
- a sqlite-backed repository option that can bootstrap from the current seed content
- an explicit sqlite write gate so durable storage does not automatically imply public thread and reply creation
- an optional write-access code gate so writable sqlite deployments can stay in a small preview cohort before full authentication lands
- a preview/production deployment contract that keeps preview responses noindex until the public forum origin is explicit
- a reusable deployment smoke script plus a manual GitHub Actions workflow for checking real preview and production forum URLs against that contract
- an optional live preview write smoke check that can create a thread and reply against a deployed runtime before broader rollout
- a minimal thread-creation API when sqlite mode is enabled and writes are explicitly opened
- a page-level thread composer on top of the thread-creation API in writable mode
- a minimal reply-creation API for existing threads when sqlite writes are enabled
- a page-level reply composer on thread detail when writes are enabled
- a first moderation-event timeline that can be read back from thread detail and runtime status
- persisted author-role and newcomer-guidance signals for new threads and replies
- a dedicated GitHub Actions workflow that checks the forum app when `forum/**` changes
- a container deployment baseline built from Next.js standalone output
- a GitHub Actions workflow that publishes versioned forum container images to GHCR whenever `main` accepts forum changes
- a container healthcheck plus smoke checks that validate both the default sqlite read-only runtime and the explicitly writable sqlite runtime
- a preview compose example that keeps sqlite on a mounted volume so data survives container restarts

## Current product boundary

This app is intentionally narrow in the first pass.

Included:

- landing page
- thread list page
- thread detail page with sample replies
- page-level thread creation in writable mode
- page-level reply submission in writable mode
- structured seed content contract
- read-only API boundary
- moderation and knowledge-stage fields reserved in the content model
- a first moderation-event timeline for thread publishing and new sqlite writes
- a first durable persistence path backed by sqlite file storage
- an explicit runtime gate for public writes
- an optional write-access code for pre-auth preview deployments
- a first reply write path for existing threads
- persisted role and guidance fields for new thread authors and reply authors
- standalone server artifact for container packaging
- a no-store health endpoint for deployment readiness probes
- a preview-safe indexing contract driven by deployment stage plus public forum origin
- a reusable smoke check for real deployment URLs
- an optional write-path smoke check for deployed preview runtimes

Not included yet:

- authentication
- search, notifications, bookmarks, or follows as real user actions
- moderation workflows beyond the first persisted timeline, write-state checks, preview-code gate, and preview indexing boundary

## Local development

Copy `.env.example` to `.env.local` if you want to make the runtime defaults explicit.

```bash
cd forum
pnpm install
pnpm dev
```

Then open `http://localhost:3000`.

Local development and preview checks now assume the safe deployment default:

```bash
FORUM_DEPLOYMENT_STAGE=preview
```

If you want sqlite persistence without opening public writes yet, keep:

```bash
FORUM_DEPLOYMENT_STAGE=preview
FORUM_DATA_SOURCE=sqlite
FORUM_ENABLE_WRITES=false
```

If you want to exercise thread and reply creation locally, explicitly open writes:

```bash
FORUM_DEPLOYMENT_STAGE=preview FORUM_DATA_SOURCE=sqlite FORUM_ENABLE_WRITES=true pnpm dev
```

If you want that writable runtime to stay inside a small preview cohort, add a shared write-access code:

```bash
FORUM_DEPLOYMENT_STAGE=preview FORUM_DATA_SOURCE=sqlite FORUM_ENABLE_WRITES=true FORUM_WRITE_ACCESS_CODE=forum-preview-2026 pnpm dev
```

Useful checks:

```bash
pnpm typecheck
pnpm build
pnpm start:standalone
curl http://localhost:3000/api/health
curl http://localhost:3000/api/status
curl http://localhost:3000/robots.txt
pnpm smoke:deployment -- --url http://localhost:3000 --deployment-stage preview --writes-enabled=false --requires-access-code=false
curl -X POST http://localhost:3000/api/threads \
  -H 'content-type: application/json' \
  -d '{
    "sectionSlug": "newcomer-path",
    "title": "想建立稳定作息，该从哪一步开始？",
    "author": "测试用户",
    "authorRoleLabel": "新手提问者",
    "guidanceSignal": "请先给我一条最容易坚持的一步。",
    "writeAccessCode": "forum-preview-2026",
    "summary": "先把最小作息和听闻节奏稳定下来。",
    "tags": ["新手", "作息"],
    "openingPost": ["我目前还没有固定作息，想先把每天最小的修学节奏建立起来。"]
  }'
curl -X POST http://localhost:3000/api/thread/first-year-stability/replies \
  -H 'content-type: application/json' \
  -d '{
    "author": "测试回复",
    "roleLabel": "新加入同修",
    "guidanceSignal": "我想先补一条最容易执行的下一步建议。",
    "writeAccessCode": "forum-preview-2026",
    "trustSignal": "回复已按主题聚焦提交，等待更多互动后再决定是否沉淀。",
    "body": ["我发现先把睡前十分钟固定下来，比一下子改整天作息更容易坚持。"]
  }'
FORUM_WRITE_ACCESS_CODE=forum-preview-2026 \
  pnpm smoke:deployment -- --url http://localhost:3000 --deployment-stage preview --writes-enabled=true --requires-access-code=true --exercise-write-flow true
curl http://localhost:3000/api/thread/first-year-stability
curl http://localhost:3000/threads/new
curl http://localhost:3000/threads
curl http://localhost:3000/threads/first-year-stability
```

When `FORUM_DATA_SOURCE=sqlite` but `FORUM_ENABLE_WRITES=false`, the page-level forms stay visible and clearly report that the runtime is still read-only. When `FORUM_ENABLE_WRITES=true`, `http://localhost:3000/threads/new` can create a new topic and `http://localhost:3000/threads/first-year-stability` can submit a reply through the page-level form. If `FORUM_WRITE_ACCESS_CODE` is set, both the page-level forms and the POST routes require the same shared code before accepting writes. `GET /api/thread/[slug]` now includes `moderationEvents`, thread-level `authorRoleLabel`, thread-level `guidanceSignal`, and reply-level `guidanceSignal`, so thread detail can expose the first durable governance timeline alongside role and newcomer guidance context instead of only content fields.

`GET /api/health` is the smallest deployment probe: it stays no-store, returns the current runtime mode, and gives preview containers, compose stacks, or future reverse proxies one stable readiness URL before they depend on the fuller `/api/status` payload. `GET /api/status` now also reports the deployment stage and whether indexing is enabled. `GET /robots.txt` plus the `x-forum-deployment-stage`, `x-forum-indexing-enabled`, and preview `x-robots-tag` headers make the deployment boundary explicit without pushing more internal notes into the page UI.

## Runtime contract

The forum still defaults to `seed-json` mode, but the page layer and API routes no longer read the JSON file directly. They now go through a single repository boundary, so durable storage can replace the seed source without rewriting the route or page structure.

Supported runtime fields:

- `FORUM_DEPLOYMENT_STAGE=preview`
- `FORUM_DEPLOYMENT_STAGE=production`
- `FORUM_PUBLIC_BASE_URL=https://forum.example.com`
- `FORUM_DATA_SOURCE=seed-json`
- `FORUM_DATA_SOURCE=sqlite`
- `FORUM_ENABLE_WRITES=false`
- `FORUM_DATABASE_URL=file:./data/forum.db`
- `FORUM_WRITE_ACCESS_CODE=forum-preview-2026`

Current JSON routes:

- `GET /api/health`
- `GET /api/threads`
- `POST /api/threads`
- `GET /api/thread/[slug]`
- `POST /api/thread/[slug]/replies`
- `GET /api/status`

`GET /api/status` now reports whether the current runtime is writable, whether a shared write-access code is still required, which deployment stage the process is in, and whether indexing is currently enabled. `GET /api/health` is intentionally slimmer: it returns the current readiness state plus the same deployment-stage and write-mode boundary flags, so deployment tooling can tell whether the standalone forum service is up before asking for counts and richer runtime detail.

Indexing now follows an explicit two-key contract:

- preview is the safe default
- indexing stays off unless `FORUM_DEPLOYMENT_STAGE=production`
- production still stays noindex until `FORUM_PUBLIC_BASE_URL` is also configured

That means preview deployments, local smoke checks, and half-finished runtime experiments cannot accidentally start advertising a crawlable forum origin just because the container is up.

In `sqlite` mode, the repository initializes its schema automatically, seeds the database from `forum-content.json` the first time it starts, and keeps the forum durably readable by default. Only when `FORUM_ENABLE_WRITES=true` does the same runtime start accepting new threads and replies, writing moderation timeline events, and persisting author-role and guidance fields for those new submissions. If `FORUM_WRITE_ACCESS_CODE` is also configured, those writes stay behind a shared preview gate until a fuller account boundary is ready.

## Live deployment checks

When a real preview URL or production forum origin exists, you no longer need to manually inspect `/api/health`, `/api/status`, headers, `robots.txt`, and page metadata one by one.

Run the reusable script locally against any reachable forum URL:

```bash
pnpm smoke:deployment -- --url https://forum-preview.example.com --deployment-stage preview --writes-enabled=true --requires-access-code=true
pnpm smoke:deployment -- --url https://forum.example.com --deployment-stage production --public-base-url https://forum.example.com --writes-enabled=false --requires-access-code=false
```

If you want the live check to also verify the preview write path, opt in explicitly and provide the shared preview code through an environment variable. This mode creates a real thread and a real reply on the deployed runtime, so it is intended for preview environments and other safe rollout targets, not public production forums.

```bash
FORUM_WRITE_ACCESS_CODE=forum-preview-2026 \
  pnpm smoke:deployment -- --url https://forum-preview.example.com --deployment-stage preview --writes-enabled=true --requires-access-code=true --exercise-write-flow true
```

The same checks are also available as the manual GitHub Actions workflow `Live deployment checks - Forum`. Provide:

- `forum_url` for the real forum entry you want to verify
- `deployment_stage` as `preview` or `production`
- `public_base_url` when the target should already be publicly indexable
- `writes_enabled` and `requires_access_code` so the live runtime is checked against the current rollout posture
- `exercise_write_flow=true` only when you intentionally want the workflow to create a preview thread and reply during the run

If the preview runtime still requires a shared write-access code, store it in the repository secret `FORUM_LIVE_WRITE_ACCESS_CODE` before triggering the workflow. The workflow passes that secret into the live smoke script only when the write-path check is enabled.

This closes the gap between “container checks passed in CI” and “the actual preview or production forum URL is configured correctly”.

## Published container image

The forum no longer stops at a local `docker build`. The GitHub Actions workflow `Publish forum container image` now publishes a reusable GHCR image whenever `main` accepts changes under `forum/**`.

Published tags:

- `ghcr.io/bhrumom/fabushi-forum:sha-<commit>`
- `ghcr.io/bhrumom/fabushi-forum:main`
- `ghcr.io/bhrumom/fabushi-forum:latest`

Use `workflow_dispatch` when you need to republish the current `main` image without waiting for another forum merge.

## Container deployment

The app now builds with `output: "standalone"`, so deployment does not need the whole repository at runtime. Mainline forum changes can now be consumed either from a local build or from the published GHCR image.

Build and run locally with Docker:

```bash
docker build -t fabushi-forum ./forum
```

Or pull the current mainline image directly:

```bash
docker pull ghcr.io/bhrumom/fabushi-forum:main
```

In the examples below, replace `fabushi-forum` with `ghcr.io/bhrumom/fabushi-forum:main` if you want to run the published image instead of a local build.

Run sqlite in durable read-only preview mode first:

```bash
docker run --rm -p 3000:3000 \
  -e FORUM_DEPLOYMENT_STAGE=preview \
  -e FORUM_DATA_SOURCE=sqlite \
  -e FORUM_DATABASE_URL=file:/tmp/forum.db \
  fabushi-forum
curl http://localhost:3000/api/health
curl http://localhost:3000/api/status
curl http://localhost:3000/robots.txt
pnpm smoke:deployment -- --url http://localhost:3000 --deployment-stage preview --writes-enabled=false --requires-access-code=false
```

Open writes only when the environment is ready to accept preview submissions:

```bash
docker run --rm -p 3000:3000 \
  -e FORUM_DEPLOYMENT_STAGE=preview \
  -e FORUM_DATA_SOURCE=sqlite \
  -e FORUM_ENABLE_WRITES=true \
  -e FORUM_DATABASE_URL=file:/tmp/forum.db \
  fabushi-forum
curl http://localhost:3000/api/health
curl http://localhost:3000/api/status
pnpm smoke:deployment -- --url http://localhost:3000 --deployment-stage preview --writes-enabled=true --requires-access-code=false
```

Keep writable deployments in a small preview cohort when needed:

```bash
docker run --rm -p 3000:3000 \
  -e FORUM_DEPLOYMENT_STAGE=preview \
  -e FORUM_DATA_SOURCE=sqlite \
  -e FORUM_ENABLE_WRITES=true \
  -e FORUM_WRITE_ACCESS_CODE=forum-preview-2026 \
  -e FORUM_DATABASE_URL=file:/tmp/forum.db \
  fabushi-forum
curl http://localhost:3000/api/health
curl http://localhost:3000/api/status
pnpm smoke:deployment -- --url http://localhost:3000 --deployment-stage preview --writes-enabled=true --requires-access-code=true
FORUM_WRITE_ACCESS_CODE=forum-preview-2026 \
  pnpm smoke:deployment -- --url http://localhost:3000 --deployment-stage preview --writes-enabled=true --requires-access-code=true --exercise-write-flow true
```

When the forum is actually ready to advertise a public origin, switch both deployment fields together:

```bash
docker run --rm -p 3000:3000 \
  -e FORUM_DEPLOYMENT_STAGE=production \
  -e FORUM_PUBLIC_BASE_URL=https://forum.fabushi.com \
  -e FORUM_DATA_SOURCE=sqlite \
  -e FORUM_ENABLE_WRITES=false \
  -e FORUM_DATABASE_URL=file:/tmp/forum.db \
  fabushi-forum
curl http://localhost:3000/api/health
curl http://localhost:3000/api/status
curl http://localhost:3000/robots.txt
curl -I http://localhost:3000/threads
pnpm smoke:deployment -- --url http://localhost:3000 --deployment-stage production --public-base-url https://forum.fabushi.com --writes-enabled=false --requires-access-code=false
```

In that production-indexing runtime, verify the pair of signals together before exposing traffic:

- `GET /api/health` and `GET /api/status` both report `deploymentStage=production` and `indexingEnabled=true`
- response headers on page routes include `x-forum-deployment-stage: production` and `x-forum-indexing-enabled: true`, without the preview `x-robots-tag`
- `GET /robots.txt` switches from `Disallow: /` to `Allow: /` and includes the configured `Host:`
- page HTML begins emitting canonical and indexable metadata against `FORUM_PUBLIC_BASE_URL`

If you want sqlite data to survive container restarts, use the preview compose example in this directory:

```bash
cd forum
FORUM_ENABLE_WRITES=true FORUM_WRITE_ACCESS_CODE=forum-preview-2026 \
  docker compose -f docker-compose.preview.yml up --build -d
curl http://localhost:3000/api/health
curl http://localhost:3000/api/status
docker compose -f docker-compose.preview.yml down
```