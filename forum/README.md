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
- a minimal thread-creation API when sqlite mode is enabled and writes are explicitly opened
- a page-level thread composer on top of the thread-creation API in writable mode
- a minimal reply-creation API for existing threads when sqlite writes are enabled
- a page-level reply composer on thread detail when writes are enabled
- a first moderation-event timeline that can be read back from thread detail and runtime status
- persisted author-role and newcomer-guidance signals for new threads and replies
- a dedicated GitHub Actions workflow that checks the forum app when `forum/**` changes
- a container deployment baseline built from Next.js standalone output
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

Not included yet:

- authentication
- search, notifications, bookmarks, or follows as real user actions
- moderation workflows beyond the first persisted timeline, write-state checks, and preview-code gate

## Local development

Copy `.env.example` to `.env.local` if you want to make the runtime defaults explicit.

```bash
cd forum
pnpm install
pnpm dev
```

Then open `http://localhost:3000`.

If you want sqlite persistence without opening public writes yet, keep:

```bash
FORUM_DATA_SOURCE=sqlite
FORUM_ENABLE_WRITES=false
```

If you want to exercise thread and reply creation locally, explicitly open writes:

```bash
FORUM_DATA_SOURCE=sqlite FORUM_ENABLE_WRITES=true pnpm dev
```

If you want that writable runtime to stay inside a small preview cohort, add a shared write-access code:

```bash
FORUM_DATA_SOURCE=sqlite FORUM_ENABLE_WRITES=true FORUM_WRITE_ACCESS_CODE=forum-preview-2026 pnpm dev
```

Useful checks:

```bash
pnpm typecheck
pnpm build
pnpm start:standalone
curl http://localhost:3000/api/health
curl http://localhost:3000/api/status
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
curl http://localhost:3000/api/thread/first-year-stability
curl http://localhost:3000/threads/new
curl http://localhost:3000/threads
curl http://localhost:3000/threads/first-year-stability
```

When `FORUM_DATA_SOURCE=sqlite` but `FORUM_ENABLE_WRITES=false`, the page-level forms stay visible and clearly report that the runtime is still read-only. When `FORUM_ENABLE_WRITES=true`, `http://localhost:3000/threads/new` can create a new topic and `http://localhost:3000/threads/first-year-stability` can submit a reply through the page-level form. If `FORUM_WRITE_ACCESS_CODE` is set, both the page-level forms and the POST routes require the same shared code before accepting writes. `GET /api/thread/[slug]` now includes `moderationEvents`, thread-level `authorRoleLabel`, thread-level `guidanceSignal`, and reply-level `guidanceSignal`, so thread detail can expose the first durable governance timeline alongside role and newcomer guidance context instead of only content fields. `GET /api/health` is the smallest deployment probe: it stays no-store, returns the current runtime mode, and gives preview containers, compose stacks, or future reverse proxies one stable readiness URL before they depend on the fuller `/api/status` payload.

## Runtime contract

The forum still defaults to `seed-json` mode, but the page layer and API routes no longer read the JSON file directly. They now go through a single repository boundary, so durable storage can replace the seed source without rewriting the route or page structure.

Supported runtime fields:

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

`GET /api/status` now reports both whether the current runtime is writable and whether that writable runtime still requires a shared write-access code. `GET /api/health` is intentionally slimmer: it returns the current readiness state plus the same write-mode boundary flags, so deployment tooling can tell whether the standalone forum service is up before asking for counts and richer runtime detail. In `sqlite` mode, the repository initializes its schema automatically, seeds the database from `forum-content.json` the first time it starts, and keeps the forum durably readable by default. Only when `FORUM_ENABLE_WRITES=true` does the same runtime start accepting new threads and replies, writing moderation timeline events, and persisting author-role and guidance fields for those new submissions. If `FORUM_WRITE_ACCESS_CODE` is also configured, those writes stay behind a shared preview gate until a fuller account boundary is ready.

## Container deployment

The app now builds with `output: "standalone"`, so deployment does not need the whole repository at runtime.

Build and run locally with Docker:

```bash
docker build -t fabushi-forum ./forum
```

Run sqlite in durable read-only mode first:

```bash
docker run --rm -p 3000:3000 \
  -e FORUM_DATA_SOURCE=sqlite \
  -e FORUM_DATABASE_URL=file:/tmp/forum.db \
  fabushi-forum
curl http://localhost:3000/api/health
curl http://localhost:3000/api/status
```

Open writes only when the environment is ready to accept public submissions:

```bash
docker run --rm -p 3000:3000 \
  -e FORUM_DATA_SOURCE=sqlite \
  -e FORUM_ENABLE_WRITES=true \
  -e FORUM_DATABASE_URL=file:/tmp/forum.db \
  fabushi-forum
curl http://localhost:3000/api/health
curl http://localhost:3000/api/status
```

Keep writable deployments in a small preview cohort when needed:

```bash
docker run --rm -p 3000:3000 \
  -e FORUM_DATA_SOURCE=sqlite \
  -e FORUM_ENABLE_WRITES=true \
  -e FORUM_WRITE_ACCESS_CODE=forum-preview-2026 \
  -e FORUM_DATABASE_URL=file:/tmp/forum.db \
  fabushi-forum
curl http://localhost:3000/api/health
curl http://localhost:3000/api/status
```

If you want sqlite data to survive container restarts, use the preview compose example in this directory:

```bash
cd forum
FORUM_ENABLE_WRITES=true FORUM_WRITE_ACCESS_CODE=forum-preview-2026 \
  docker compose -f docker-compose.preview.yml up --build -d
curl http://localhost:3000/api/health
curl http://localhost:3000/api/status
docker compose -f docker-compose.preview.yml down
```

`docker-compose.preview.yml` mounts a named volume at `/data`, keeps `FORUM_DATABASE_URL=file:/data/forum.db`, and now declares the same `/api/health` probe that the container image exposes through `HEALTHCHECK`. That gives preview deployments one consistent readiness contract whether they are started with `docker run`, `docker compose`, or a later reverse-proxy/platform wrapper.

Runtime defaults:

- `PORT=3000`
- `HOSTNAME=0.0.0.0`
- `NODE_ENV=production`

A dedicated GitHub Actions workflow now checks that the forum container image can be built whenever `forum/**` changes, waits for the container healthcheck to report healthy, validates that sqlite starts in read-only mode by default, confirms `/threads/new` exposes the disabled page-level composer until writes are explicitly enabled, reruns the container with `FORUM_ENABLE_WRITES=true` plus a preview write-access code to exercise thread creation, denied writes without the code, thread-detail readback, reply submission, role labels, guidance signals, and appended moderation timeline events, and then restarts the same writable container against a mounted sqlite path to confirm those writes still exist after the process comes back up.

## Why this is the next step

After the preview write-access gate landed, the next launch-readiness gap was no longer another UI slice. The remaining deployment risk was that the forum still lacked a first-class readiness probe, even though preview deployments were already close to real use. This iteration closes that gap in the smallest useful way: it adds a stable `/api/health` endpoint, wires the same probe into Docker and preview compose, and extends the container smoke checks to wait on health before they verify read-only mode, writable preview mode, and sqlite persistence across restarts.
