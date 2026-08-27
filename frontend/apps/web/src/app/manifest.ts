import type { MetadataRoute } from "next";
import { siteHref } from "../lib/site-url";

export const dynamic = "force-static";

export default function manifest(): MetadataRoute.Manifest {
  return {
    id: siteHref("/"),
    name: "Fabushi 应用市场",
    short_name: "Fabushi",
    description: "发现、安装并运行 Mini App、AI 工具、指南、模板和工作流。",
    start_url: siteHref("/"),
    scope: siteHref("/"),
    display: "standalone",
    background_color: "#000000",
    theme_color: "#000000",
    categories: ["business", "productivity", "utilities"],
    shortcuts: [
      {
        name: "搜索应用与内容",
        short_name: "搜索",
        description: "搜索 Mini App、能力、指南、模板和工作流",
        url: siteHref("/search"),
      },
      {
        name: "打开大乘",
        short_name: "大乘",
        description: "进入 Fabushi 大乘工作台",
        url: siteHref("/app"),
      },
    ],
  };
}
