import { NextResponse } from "next/server";
import {
  type CreateForumReplyInput,
  ForumInputError,
  ForumWriteUnavailableError,
  createForumReply,
  getThreadBySlug,
} from "../../../../../lib/forum-data";

interface RouteContext {
  params: Promise<{ slug: string }>;
}

interface CreateReplyPayload {
  author?: unknown;
  roleLabel?: unknown;
  trustSignal?: unknown;
  body?: unknown;
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

function parseCreateReplyPayload(threadSlug: string, payload: CreateReplyPayload): CreateForumReplyInput {
  const author = requireString(payload.author, "author");
  const body = normalizeStringArray(payload.body, "body");

  if (body.length === 0) {
    throw new ForumInputError("body must contain at least one paragraph.");
  }

  const roleLabel = typeof payload.roleLabel === "string" && payload.roleLabel.trim().length > 0
    ? payload.roleLabel.trim()
    : "论坛参与者";
  const trustSignal = typeof payload.trustSignal === "string" && payload.trustSignal.trim().length > 0
    ? payload.trustSignal.trim()
    : "新提交回复，等待更多互动后再判断是否适合沉淀。";

  return {
    threadSlug,
    author,
    roleLabel,
    trustSignal,
    body,
  };
}

export async function POST(request: Request, context: RouteContext) {
  const { slug } = await context.params;

  if (!getThreadBySlug(slug)) {
    return NextResponse.json({ error: "Thread not found" }, { status: 404 });
  }

  let payload: CreateReplyPayload;

  try {
    payload = (await request.json()) as CreateReplyPayload;
  } catch {
    return NextResponse.json({ error: "Request body must be valid JSON." }, { status: 400 });
  }

  try {
    const updatedThread = createForumReply(parseCreateReplyPayload(slug, payload));

    return NextResponse.json(updatedThread, {
      status: 201,
      headers: {
        "cache-control": "no-store",
        location: `/api/thread/${updatedThread.thread.slug}`,
        "x-forum-data-source": updatedThread.source,
      },
    });
  } catch (error) {
    if (error instanceof ForumInputError) {
      return NextResponse.json({ error: error.message }, { status: 400 });
    }

    if (error instanceof ForumWriteUnavailableError) {
      return NextResponse.json({ error: error.message }, { status: 503 });
    }

    console.error("Failed to create forum reply", error);
    return NextResponse.json({ error: "Unable to create forum reply." }, { status: 500 });
  }
}
