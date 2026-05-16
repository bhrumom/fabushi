import { NextResponse } from "next/server";
import { getForumRuntimeStatus } from "../../../lib/forum-data";

export async function GET() {
  const status = getForumRuntimeStatus();

  return NextResponse.json(
    {
      service: status.service,
      ready: true,
      dataSource: status.dataSource,
      persistenceMode: status.persistenceMode,
      writesEnabled: status.writesEnabled,
      requiresAccessCode: status.requiresAccessCode,
      generatedAt: status.generatedAt,
    },
    {
      headers: {
        "cache-control": "no-store",
        "x-forum-data-source": status.dataSource,
      },
    },
  );
}
