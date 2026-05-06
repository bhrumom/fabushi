import type { InsightArticle } from "./types";

export const wechatMiniProgramPhaseOneArticle: InsightArticle = {
  slug: "wechat-mini-program-phase-one",
  title: "微信小程序首期范围",
  description: "为什么首期优先做轻浏览、榜单、公开档案和基础登录，而不是把主应用完整搬进去。",
  category: "小程序",
  publishedAt: "2026-05-06",
  author: "Fabushi Team",
  readTime: "2 分钟",
  body: [
    "微信小程序首期的目标不是复制整个主应用，而是把最容易形成传播和留存入口的能力先放进去。",
    "轻浏览可以承担首次认知，榜单和公开档案可以承担社交发现，基础登录则为后续个人数据和关注关系打下最小闭环。",
    "等这些链路稳定之后，再决定哪些内容创作、上传或更重的互动流程值得继续往小程序里加，哪些则继续留在 Flutter 主应用里更合适。",
  ],
};
