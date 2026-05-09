import type { MetadataRoute } from "next";
import { siteHref } from "../lib/site-url";

export const dynamic = "force-static";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "法布施 Fabushi 官网",
    short_name: "Fabushi",
    description: "Fabushi 官网，统一承接佛法传播、修行记录、下载入口、测试申请与内容专栏。",
    start_url: siteHref("/"),
    display: "standalone",
    background_color: "#f6f1e8",
    theme_color: "#19140f",
  };
}
