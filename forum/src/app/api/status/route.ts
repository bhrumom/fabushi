import { NextResponse } from "next/server";
import { getForumRuntimeStatus } from "../../../lib/forum-data";

export async function GET() {
  const status = getForumRuntimeStatus();

  return NextResponse.json(status, {
    headers: {
      "cache-control": "no-store",
      "x-forum-data-source": status.dataSource,
    },
  });
}
