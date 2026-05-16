# Fabushi Forum

This directory is the independent root for the forum project.

## What exists now

The forum is no longer being extended inside the marketing website. This directory now contains a standalone Next.js app skeleton so the project can move from an empty placeholder into something runnable, testable, and deployable on its own.

Current scope:

- independent app shell under `forum/src/app`
- structured seed content under `forum/src/data/forum-content.json`
- forum domain helpers under `forum/src/lib/forum-data.ts`
- a repository boundary that keeps page rendering and API routes behind one forum data source contract
- read-only routes for thread listing, thread detail, and runtime status
- a sqlite-backed repository option that can bootstrap from the current seed content
- an explicit sqlite write gate so durable storage does not automatically imply public thread and reply creation
- a minimal thread-creation API when sqlite mode is enabled and writes are explicitly opened
- a page-level thread composer on top of the thread-creation API in writable mode
- a minimal reply-creation API for existing threads when sqlite writes are enabled
- a page-level reply composer on thread detail when writes are enabled
- a first moderation-event timeline that can be read back from thread detail and runtime status
- persisted author-role and newcomer-guidance signals for new threads and replies
- a dedicated GitHub Actions workflow that checks the forum app when `forum/**` changes
- a container deployment baseline built from Next.js standalone output
- a container smoke check that validates both the default sqlite read-only runtime and the explicitly writable sqlite runtime

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
- a first reply write path for existing threads
- persisted role and guidance fields for new thread authors and reply authors
- standalone server artifact for container packaging

Not included yet:

- authentication
- search, notifications, bookmarks, or follows as real user actions
- moderation workflows beyond the first persisted timeline and write-state checks

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

Useful checks:

```bash
pnpm typecheck
pnpm build
pnpm start:standalone
curl http://localhost:3000/api/status
curl -X POST http://localhost:3000/api/threads \
  -H 'content-type: application/json' \
  -d '{
    "sectionSlug": "newcomer-path",
    "title": "想建立稳定作息，该从哪一步开始？",
    "author": "测试用户",
    "authorRoleLabel": "新手提问者",
    "guidanceSignal": "请先给我一条最容易坚持的一步。",
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
    "trustSignal": "回复已按主题聚焦提交，等待更多互动后再决定是否沉淀。",
    "body": ["我发现先把睡前十分钟固定下来，比一下子改整天作息更容易坚持。"]
  }'
curl http://localhost:3000/api/thread/first-year-stability
curl http://localhost:3000/threads/new
curl http://localhost:3000/threads
curl http://localhost:3000/threads/first-year-stability
```

When `FORUM_DATA_SOURCE=sqlite` but `FORUM_ENABLE_WRITES=false`, the page-level forms stay visible and clearly report that the runtime is still read-only. When `FORUM_ENABLE_WRITES=true`, `http://localhost:3000/threads/new` can create a new topic and `http://localhost:3000/threads/first-year-stability` can submit a reply through the page-level form. `GET /api/thread/[slug]` now includes `moderationEvents`, thread-level `authorRoleLabel`, thread-level `guidanceSignal`, and reply-level `guidanceSignal`, so thread detail can expose the first durable governance timeline alongside role and newcomer guidance context instead of only content fields.

## Runtime contract

The forum still defaults to `seed-json` mode, but the page layer and API routes no longer read the JSON file directly. They now go through a single repository boundary, so durable storage can replace the seed source without rewriting the route or page structure.

Supported runtime fields:

- `FORUM_DATA_SOURCE=seed-json`
- `FORUM_DATA_SOURCE=sqlite`
- `FORUM_ENABLE_WRITES=false`
- `FORUM_DATABASE_URL=file:./data/forum.db`

Current JSON routes:

- `GET /api/threads`
- `POST /api/threads`
- `GET /api/thread/[slug]`
- `POST /api/thread/[slug]/replies`
- `GET /api/status`

`GET /api/status` now reports whether the current runtime is writable, even when the data source is already `sqlite`. In `sqlite` mode, the repository initializes its schema automatically, seeds the database from `forum-content.json` the first time it starts, and keeps the forum durably readable by default. Only when `FORUM_ENABLE_WRITES=true` does the same runtime start accepting new threads and replies, writing moderation timeline events, and persisting author-role and guidance fields for those new submissions.

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
curl http://localhost:3000/api/status
```

Open writes only when the environment is ready to accept public submissions:

```bash
docker run --rm -p 3000:3000 \
  -e FORUM_DATA_SOURCE=sqlite \
  -e FORUM_ENABLE_WRITES=true \
  -e FORUM_DATABASE_URL=file:/tmp/forum.db \
  fabushi-forum
curl http://localhost:3000/api/status
```

Runtime defaults:

- `PORT=3000`
- `HOSTNAME=0.0.0.0`
- `NODE_ENV=production`

A dedicated GitHub Actions workflow now checks that the forum container image can be built whenever `forum/**` changes, validates that sqlite starts in read-only mode by default, confirms `/threads/new` exposes the disabled page-level composer until writes are explicitly enabled, and then reruns the container with `FORUM_ENABLE_WRITES=true` to exercise thread creation, thread-detail readback, reply submission, role labels, guidance signals, and appended moderation timeline events.

## Why this is the next step

After moderation timeline persistence and role-guidance persistence landed, the highest-value gap was no longer another UI slice. The bigger launch-readiness risk was that switching to sqlite also opened anonymous writes by default. This iteration keeps the product surface narrow while making the deployment posture safer: the forum can now be durably readable in sqlite mode first, and public writes become an explicit runtime decision instead of an accidental side effect of persistence.
