import { officialSiteStructureArticle } from "./official-site-structure";
import { productRoadmapArticle } from "./product-roadmap";
import { wechatMiniProgramPhaseOneArticle } from "./wechat-mini-program-phase-one";

export const insightArticles = [
  productRoadmapArticle,
  wechatMiniProgramPhaseOneArticle,
  officialSiteStructureArticle,
].sort((a, b) => b.publishedAt.localeCompare(a.publishedAt));

export type { InsightArticle } from "./types";
