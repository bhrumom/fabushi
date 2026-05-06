import type { InsightArticle } from "./types";

export const productRoadmapArticle: InsightArticle = {
  slug: "product-roadmap",
  title: "法布施多端产品路线图",
  description: "官网、微信小程序与 Flutter 主应用的职责边界，以及为什么现在要拆出新的前端 monorepo。",
  category: "产品路线",
  publishedAt: "2026-05-06",
  author: "Fabushi Team",
  readTime: "3 分钟",
  featured: true,
  body: [
    "法布施当前已经有一条稳定的 Flutter 主应用主线，它很适合承接完整功能、重交互和沉浸式内容体验，但并不天然适合作为官网和微信小程序的统一载体。",
    "官网这一侧更看重品牌识别、内容收录、页面结构与长期运营，因此选择 Next.js 作为新的官网框架。微信小程序这一侧更看重微信生态内的轻触达、轻交互和后续多端延展，因此选择 Taro。",
    "新的前端 monorepo 不追求把全部界面强行复用，而是把真正稳定的东西沉淀下来：接口层、类型、文案和部分纯业务逻辑。这样既能减少重复劳动，也能避免不同端互相牵制。",
  ],
};
