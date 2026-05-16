import { NextResponse } from "next/server";
import { getForumThreadResponse } from "../../../../../lib/community-api";

const responseHeaders = {
  "Cache-Control": "public, s-maxage=300, stale-while-revalidate=86400",
};

type RouteContext = {
  params: Promise<{
    slug: string;
  }>;
};

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
