import { NextResponse } from "next/server";
import { getForumThreadsResponse } from "../../../../lib/community-api";

const responseHeaders = {
  "Cache-Control": "public, s-maxage=300, stale-while-revalidate=86400",
};

export function GET() {
  return NextResponse.json(getForumThreadsResponse(), {
    headers: responseHeaders,
  });
}
