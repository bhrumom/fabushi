import { NextResponse } from "next/server";
import {
  type CreateForumThreadInput,
  ForumInputError,
  ForumWriteAccessDeniedError,
  ForumWriteUnavailableError,
  assertForumWriteAccessCode,
  createForumThread,
  getForumSnapshot,
} from "../../../lib/forum-data";

interface CreateThreadPayload {
  sectionSlug?: unknown;
  title?: unknown;
  summary?: unknown;
  author?: unknown;
  authorRoleLabel?: unknown;
  guidanceSignal?: unknown;
  tags?: unknown;
  openingPost?: unknown;
  writeAccessCode?: unknown;
}

function requireString(value: unknown, fieldName: string): string {
  if (typeof value !== "string") {
    throw new ForumInputError(`${fieldName} must be a string.`);
  }

  const trimmed = value.trim();

  if (!trimmed) {
    throw new ForumInputError(`${fieldName} is required.`);
  }

  return trimmed;
}

function optionalString(value: unknown, fieldName: string): string {
  if (value === undefined || value === null) {
    return "";
  }

  if (typeof value !== "string") {
    throw new ForumInputError(`${fieldName} must be a string.`);
  }

  return value.trim();
}

function normalizeStringArray(value: unknown, fieldName: string): string[] {
  if (typeof value === "string") {
    const trimmed = value.trim();
    return trimmed ? [trimmed] : [];
  }

  if (!Array.isArray(value)) {
    throw new ForumInputError(`${fieldName} must be a string or string array.`);
  }

  const normalized = value
    .map((entry) => {
      if (typeof entry !== "string") {
        throw new ForumInputError(`${fieldName} entries must be strings.`);
      }

      return entry.trim();
    })
    .filter(Boolean);

  return normalized;
}

function parseCreateThreadPayload(payload: CreateThreadPayload): CreateForumThreadInput {
  const sectionSlug = requireString(payload.sectionSlug, "sectionSlug");
  const title = requireString(payload.title, "title");
  const author = requireString(payload.author, "author");
  const authorRoleLabel = optionalString(payload.authorRoleLabel, "authorRoleLabel");
  const guidanceSignal = optionalString(payload.guidanceSignal, "guidanceSignal");
  const openingPost = normalizeStringArray(payload.openingPost, "openingPost");

  if (openingPost.length === 0) {
    throw new ForumInputError("openingPost must contain at least one paragraph.");
  }

  const summary = typeof payload.summary === "string" && payload.summary.trim().length > 0
    ? payload.summary.trim()
    : openingPost[0].slice(0, 140);
  const tags = payload.tags === undefined ? [] : normalizeStringArray(payload.tags, "tags");

  return {
    sectionSlug,
    title,
    summary,
    author,
    authorRoleLabel,
    guidanceSignal,
    tags,
    openingPost,
  };
}

export async function GET() {
  return NextResponse.json(getForumSnapshot(), {
    headers: {
      "cache-control": "public, max-age=300, s-maxage=300",
    },
  });
}

export async function POST(request: Request) {
  let payload: CreateThreadPayload;

  try {
    payload = (await request.json()) as CreateThreadPayload;
  } catch {
    return NextResponse.json({ error: "Request body must be valid JSON." }, { status: 400 });
  }

  try {
    assertForumWriteAccessCode(payload.writeAccessCode);
    const createdThread = createForumThread(parseCreateThreadPayload(payload));

    return NextResponse.json(createdThread, {
      status: 201,
      headers: {
        "cache-control": "no-store",
        location: `/api/thread/${createdThread.thread.slug}`,
        "x-forum-data-source": createdThread.source,
      },
    });
  } catch (error) {
    if (error instanceof ForumInputError) {
      return NextResponse.json({ error: error.message }, { status: 400 });
    }

    if (error instanceof ForumWriteAccessDeniedError) {
      return NextResponse.json({ error: error.message }, { status: 403 });
    }

    if (error instanceof ForumWriteUnavailableError) {
      return NextResponse.json({ error: error.message }, { status: 503 });
    }

    console.error("Failed to create forum thread", error);
    return NextResponse.json({ error: "Unable to create forum thread." }, { status: 500 });
  }
}
