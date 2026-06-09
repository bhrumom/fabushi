import type { NextConfig } from "next";
import path from "node:path";
import { fileURLToPath } from "node:url";

const rawBasePath = process.env.NEXT_PUBLIC_SITE_BASE_PATH?.trim() ?? "";
const basePath =
  rawBasePath && rawBasePath !== "/"
    ? `/${rawBasePath.replace(/^\/+|\/+$/g, "")}`
    : "";
const appDir = path.dirname(fileURLToPath(import.meta.url));

const nextConfig: NextConfig = {
  reactStrictMode: true,
  transpilePackages: ["@fabushi/shared", "@fabushi/api-client"],
  typedRoutes: true,
  output: "export",
  outputFileTracingRoot: path.resolve(appDir, "../.."),
  trailingSlash: true,
  images: {
    unoptimized: true,
  },
  basePath,
};

export default nextConfig;
