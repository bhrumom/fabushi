import type { MetadataRoute } from "next";
import { getForumDeploymentRuntime } from "../lib/forum-runtime";

export const dynamic = "force-dynamic";

export default function robots(): MetadataRoute.Robots {
  const runtime = getForumDeploymentRuntime();

  if (!runtime.indexingEnabled) {
    return {
      rules: {
        userAgent: "*",
        disallow: "/",
      },
    };
  }

  return {
    rules: {
      userAgent: "*",
      allow: "/",
    },
    host: runtime.publicBaseUrl,
  };
}
