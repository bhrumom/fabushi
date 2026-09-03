import type { MetadataRoute } from "next";
import { siteHref } from "../lib/site-url";

export const dynamic = "force-static";

export default function manifest(): MetadataRoute.Manifest {
  return {
    id: siteHref("/"),
    name: "Fabushi",
    short_name: "Fabushi",
    description: "跨平台 Messenger、AI Agents 与 Mini Apps Host，内置 WebMCP、应用发现和内容级搜索。",
    start_url: siteHref("/"),
    scope: siteHref("/"),
    display: "standalone",
    background_color: "#000000",
    theme_color: "#000000",
    categories: ["social", "productivity", "utilities"],
    shortcuts: [
      {
        name: "打开 Fabushi",
        short_name: "聊天",
        description: "进入 Fabushi Messenger 与 AI Agent Host",
        url: siteHref("/"),
      },
      {
        name: "Mini Apps",
        short_name: "应用",
        description: "发现、安装并打开 Fabushi Mini Apps",
        url: siteHref("/apps"),
      },
      {
        name: "搜索应用与内容",
        short_name: "搜索",
        description: "搜索 Mini App、能力、指南、模板和工作流",
        url: siteHref("/search"),
      },
    ],
  };
}
