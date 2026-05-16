# Fabushi Forum

This directory is the independent root for the forum project.

## What exists now

The forum is no longer being extended inside the marketing website. This directory now contains a standalone Next.js app skeleton so the project can move from an empty placeholder into something runnable and testable.

Current scope:

- independent app shell under `forum/src/app`
- structured seed content under `forum/src/data/forum-content.json`
- forum domain helpers under `forum/src/lib/forum-data.ts`
- read-only routes for thread listing and thread detail
- JSON routes for the same seed contract, including reply data on thread detail
- a dedicated GitHub Actions workflow that checks the forum app when `forum/**` changes

## Current product boundary

This app is intentionally narrow in the first pass.

Included:

- landing page
- thread list page
- thread detail page with sample replies
- structured seed content contract
- read-only API boundary
- moderation and knowledge-stage fields reserved in the content model

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
```

## Why this is the next step

The highest-priority gap after creating `forum/` was that forum content still lived as hard-coded TypeScript arrays. This iteration moves the project onto a structured content store and reply-aware contract so the next pass can attach a real persistence layer, posting flow, and governance events without first untangling page-local seed data.
