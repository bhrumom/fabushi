import { NextResponse } from "next/server";
import { getThreadDetailBySlug } from "../../../../lib/forum-data";

interface RouteContext {
  params: Promise<{ slug: string }>;
}

export async function GET(_request: Request, context: RouteContext) {
  const { slug } = await context.params;
  const detail = getThreadDetailBySlug(slug);

  if (!detail) {
    return NextResponse.json({ error: "Thread not found" }, { status: 404 });
  }

  return NextResponse.json(detail, {
    headers: {
      "cache-control": "public, max-age=300, s-maxage=300",
    },
  });
}
