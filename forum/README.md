# Fabushi Forum

This directory is the independent root for the forum project.

## What exists now

The forum is no longer being extended inside the marketing website. This directory now contains a standalone Next.js app skeleton so the project can move from an empty placeholder into something runnable, testable, and deployable on its own.

Current scope:

- independent app shell under `forum/src/app`
- structured seed content under `forum/src/data/forum-content.json`
- forum domain helpers under `forum/src/lib/forum-data.ts`
- read-only routes for thread listing and thread detail
- JSON routes for the same seed contract, including reply data on thread detail
- a dedicated GitHub Actions workflow that checks the forum app when `forum/**` changes
- a container deployment baseline built from Next.js standalone output

## Current product boundary

This app is intentionally narrow in the first pass.

Included:

- landing page
- thread list page
- thread detail page with sample replies
- structured seed content contract
- read-only API boundary
- moderation and knowledge-stage fields reserved in the content model
- standalone server artifact for container packaging

Not included yet:

- authentication
- posting or replying
- durable persistence layer
- search, notifications, bookmarks, or follows as real user actions

## Local development

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
```

## Container deployment

The app now builds with `output: "standalone"`, so deployment does not need the whole repository at runtime.

Build and run locally with Docker:

```bash
docker build -t fabushi-forum ./forum
docker run --rm -p 3000:3000 fabushi-forum
```

Runtime defaults:

- `PORT=3000`
- `HOSTNAME=0.0.0.0`
- `NODE_ENV=production`

A dedicated GitHub Actions workflow now checks that the forum container image can be built whenever `forum/**` changes.

## Why this is the next step

After the structured seed content contract landed, the next highest-value blocker was deployment readiness for the independent forum app. This iteration keeps the current seed-backed product surface intact while adding a real container path, so the next pass can attach persistence, posting flow, and governance services without first inventing a deployment baseline.
