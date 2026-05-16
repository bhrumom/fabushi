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
- JSON routes for the same seed contract, including reply data on thread detail
- a dedicated GitHub Actions workflow that checks the forum app when `forum/**` changes
- a container deployment baseline built from Next.js standalone output
- a container smoke check that starts the forum and hits `/api/status`

## Current product boundary

This app is intentionally narrow in the first pass.

Included:

- landing page
- thread list page
- thread detail page with sample replies
- structured seed content contract
- read-only API boundary
- moderation and knowledge-stage fields reserved in the content model
- a runtime status endpoint for deployment smoke checks
- standalone server artifact for container packaging

Not included yet:

- authentication
- posting or replying
- durable persistence layer
- search, notifications, bookmarks, or follows as real user actions

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
```

## Runtime contract

The forum currently runs in `seed-json` mode, but the page layer and API routes no longer read the JSON file directly. They now go through a single repository boundary, so the first durable database pass can replace the data source without rewriting the route or page structure.

Current runtime fields:

- `FORUM_DATA_SOURCE=seed-json`
- `FORUM_DATABASE_URL=` reserved for the first durable persistence pass

Current JSON routes:

- `GET /api/threads`
- `GET /api/thread/[slug]`
- `GET /api/status`

## Container deployment

The app now builds with `output: "standalone"`, so deployment does not need the whole repository at runtime.

Build and run locally with Docker:

```bash
docker build -t fabushi-forum ./forum
docker run --rm -p 3000:3000 fabushi-forum
curl http://localhost:3000/api/status
```

Runtime defaults:

- `PORT=3000`
- `HOSTNAME=0.0.0.0`
- `NODE_ENV=production`

A dedicated GitHub Actions workflow now checks that the forum container image can be built whenever `forum/**` changes, and then verifies the container actually serves the runtime status endpoint.

## Why this is the next step

After the structured seed content contract and standalone deployment baseline landed, the next highest-value gap was a clear runtime boundary for the forum's first persistent data source. This iteration keeps the current seed-backed product surface intact while making the data source explicit and adding a smoke-testable runtime endpoint, so the next pass can attach posting flow and durable storage without guessing where that boundary should live.
