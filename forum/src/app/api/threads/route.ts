import { NextResponse } from "next/server";
import { getForumSnapshot } from "../../../lib/forum-data";

export async function GET() {
  return NextResponse.json(getForumSnapshot(), {
    headers: {
      "cache-control": "public, max-age=300, s-maxage=300",
    },
  });
}
