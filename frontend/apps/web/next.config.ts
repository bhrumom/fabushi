import type { NextConfig } from "next";

const nextConfig: NextConfig = {
  reactStrictMode: true,
  transpilePackages: ["@fabushi/shared", "@fabushi/api-client"],
  typedRoutes: true,
};

export default nextConfig;
