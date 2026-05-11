import type { InsightArticle } from "./types";

export const downloadWaitlistFlowArticle: InsightArticle = {
  slug: "download-waitlist-flow",
  title: "下载入口开放节奏",
  description: "Android、iOS 与正式版入口会按测试状态逐步开放。",
  category: "下载",
  publishedAt: "2026-05-06",
  author: "Fabushi Team",
  readTime: "1 分钟",
  body: [
    "Android Beta 会优先跟随公开发布记录更新，适合想尽快体验新版本的人。",
    "iOS 内测通过 TestFlight 分发。公开加入链接开放后，下载页会直接显示。",
    "正式版会在人工确认后公开，更适合首次安装和转发给更多用户。",
  ],
};
