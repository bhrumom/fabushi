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
- a minimal thread-creation API when sqlite mode is enabled
- a page-level thread composer on top of the thread-creation API in writable mode
- a minimal reply-creation API for existing threads in sqlite mode
- a page-level reply composer on thread detail when writes are enabled
- a first moderation-event timeline that can be read back from thread detail and runtime status
- a dedicated GitHub Actions workflow that checks the forum app when `forum/**` changes
- a container deployment baseline built from Next.js standalone output
- a container smoke check that starts the forum, validates `/api/status`, exercises sqlite thread and reply creation, and reads the updated thread back through real forum pages

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
- a runtime status endpoint for deployment smoke checks
- a first durable persistence path backed by sqlite file storage
- a first reply write path for existing threads
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
    "summary": "先把最小作息和听闻节奏稳定下来。",
    "tags": ["新手", "作息"],
    "openingPost": ["我目前还没有固定作息，想先把每天最小的修学节奏建立起来。"]
  }'
curl -X POST http://localhost:3000/api/thread/first-year-stability/replies \
  -H 'content-type: application/json' \
  -d '{
    "author": "测试回复",
    "roleLabel": "新加入同修",
    "trustSignal": "回复已按主题聚焦提交，等待更多互动后再决定是否沉淀。",
    "body": ["我发现先把睡前十分钟固定下来，比一下子改整天作息更容易坚持。"]
  }'
curl http://localhost:3000/api/thread/first-year-stability
curl http://localhost:3000/threads/new
curl http://localhost:3000/threads
curl http://localhost:3000/threads/first-year-stability
```

When `FORUM_DATA_SOURCE=sqlite`, you can also open `http://localhost:3000/threads/new` to create a new topic, and `http://localhost:3000/threads/first-year-stability` to submit a reply through the page-level form. In `seed-json` mode, both page-level forms stay visible but clearly report that the runtime is still read-only. `GET /api/thread/[slug]` now includes `moderationEvents`, so thread detail can expose the first durable governance timeline instead of only content fields.

## Runtime contract

The forum still defaults to `seed-json` mode, but the page layer and API routes no longer read the JSON file directly. They now go through a single repository boundary, so durable storage can replace the seed source without rewriting the route or page structure.

Supported runtime fields:

- `FORUM_DATA_SOURCE=seed-json`
- `FORUM_DATA_SOURCE=sqlite`
- `FORUM_DATABASE_URL=file:./data/forum.db`

Current JSON routes:

- `GET /api/threads`
- `POST /api/threads`
- `GET /api/thread/[slug]`
- `POST /api/thread/[slug]/replies`
- `GET /api/status`

`GET /api/status` now reports whether writes are enabled for the current data source and how many moderation events the current store already contains. In `sqlite` mode, the repository initializes its schema automatically, seeds the database from `forum-content.json` the first time it starts, writes the first moderation timeline events alongside newly created threads and replies, lets the page-level thread composer create new topics, and lets existing threads accept the first persisted reply submissions.

## Container deployment

The app now builds with `output: "standalone"`, so deployment does not need the whole repository at runtime.

Build and run locally with Docker:

```bash
docker build -t fabushi-forum ./forum
docker run --rm -p 3000:3000 \
  -e FORUM_DATA_SOURCE=sqlite \
  -e FORUM_DATABASE_URL=file:/tmp/forum.db \
  fabushi-forum
curl http://localhost:3000/api/status
```

Runtime defaults:

- `PORT=3000`
- `HOSTNAME=0.0.0.0`
- `NODE_ENV=production`

A dedicated GitHub Actions workflow now checks that the forum container image can be built whenever `forum/**` changes, validates the sqlite runtime status, confirms `/threads/new` exposes the writable page-level composer, creates a thread through the API, reads that thread back through `/threads` and `/threads/[slug]`, and then adds a reply to verify both the updated discussion and the appended moderation timeline event are visible on the thread detail page.

## Why this is the next step

After the structured seed content contract, standalone deployment baseline, runtime status boundary, first durable thread creation path, first reply write path, page-level reply submission, page-level thread creation, and page-level sqlite readback checks landed, the next highest-value gap was turning governance signals into durable data rather than leaving them in copy alone. This iteration keeps the product surface narrow while making moderation state inspectable through the same repository and page boundary, so the next pass can focus on role state and more explicit newcomer guidance instead of rediscovering whether governance events survive real writes.
