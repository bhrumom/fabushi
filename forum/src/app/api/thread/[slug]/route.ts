import { NextResponse } from "next/server";
import { getSectionBySlug, getThreadBySlug } from "../../../../lib/forum-data";

interface RouteContext {
  params: Promise<{ slug: string }>;
}

export async function GET(_request: Request, context: RouteContext) {
  const { slug } = await context.params;
  const thread = getThreadBySlug(slug);

  if (!thread) {
    return NextResponse.json({ error: "Thread not found" }, { status: 404 });
  }

  return NextResponse.json(
    {
      thread,
      section: getSectionBySlug(thread.sectionSlug),
      source: "seed",
      generatedAt: new Date().toISOString(),
    },
    {
      headers: {
        "cache-control": "public, max-age=300, s-maxage=300",
      },
    },
  );
}
