import { NextResponse } from "next/server";
import { FORUM_THREADS } from "../../../../../lib/community";
import { getForumThreadResponse } from "../../../../../lib/community-api";

export const dynamic = "force-static";
export const dynamicParams = false;

const responseHeaders = {
  "Cache-Control": "public, s-maxage=300, stale-while-revalidate=86400",
};

type RouteContext = {
  params: Promise<{
    slug: string;
  }>;
};

export function generateStaticParams() {
  return FORUM_THREADS.map((thread) => ({ slug: thread.slug }));
}

export async function GET(_request: Request, { params }: RouteContext) {
  const { slug } = await params;
  const response = getForumThreadResponse(slug);

  if (!response) {
    return NextResponse.json(
      {
        error: "Forum thread not found",
      },
      {
        status: 404,
        headers: responseHeaders,
      },
    );
  }

  return NextResponse.json(response, {
    headers: responseHeaders,
  });
}
