import type { InsightArticle } from "./types";

export const downloadWaitlistFlowArticle: InsightArticle = {
  slug: "download-waitlist-flow",
  title: "为什么下载页当前先给等待名单而不是公开直链",
  description: "在正式下载地址还不稳定时，官网为什么先提供申请与等待名单入口。",
  category: "下载策略",
  publishedAt: "2026-05-06",
  author: "Fabushi Team",
  readTime: "3 分钟",
  body: [
    "下载页的目标不是把所有平台的按钮先摆出来，而是让用户在当前阶段拿到真实可用的下一步。对一个还在持续内测、链接和发放节奏仍会变化的产品来说，错误的公开直链比暂时没有直链更容易伤害体验。",
    "因此官网首期更适合先把 iOS、Android、微信小程序和 Web 的开放状态说明清楚，再把用户引导到等待名单、测试申请或路线说明。这样既不会让用户点进空页面，也能把后续资格发放和沟通路径集中起来。",
    "等正式下载地址稳定之后，只需要替换下载页和申请页里的入口配置，就能顺着同一套页面结构继续往前走，而不需要重写整站信息架构。",
  ],
};
