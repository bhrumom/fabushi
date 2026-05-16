import type { NextRequest } from "next/server";
import { NextResponse } from "next/server";
import { getForumDeploymentRuntime } from "./lib/forum-runtime";

export function middleware(_request: NextRequest) {
  const response = NextResponse.next();
  const runtime = getForumDeploymentRuntime();

  response.headers.set("x-forum-deployment-stage", runtime.deploymentStage);
  response.headers.set("x-forum-indexing-enabled", String(runtime.indexingEnabled));

  if (runtime.publicBaseUrl) {
    response.headers.set("x-forum-public-base-url", runtime.publicBaseUrl);
  }

  if (!runtime.indexingEnabled) {
    response.headers.set("x-robots-tag", "noindex, nofollow, noarchive");
  }

  return response;
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
