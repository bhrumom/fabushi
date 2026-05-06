import type { NextConfig } from "next";

const rawBasePath = process.env.NEXT_PUBLIC_SITE_BASE_PATH?.trim() ?? "";
const basePath = rawBasePath && rawBasePath !== "/" ? `/${rawBasePath.replace(/^\/+|\/+$/g, "")}` : "";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  transpilePackages: ["@fabushi/shared", "@fabushi/api-client"],
  typedRoutes: true,
  output: "export",
  trailingSlash: true,
  images: {
    unoptimized: true,
  },
  basePath,
};

export default nextConfig;
