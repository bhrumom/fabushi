import { downloadWaitlistFlowArticle } from "./download-waitlist-flow";
import { officialSiteStructureArticle } from "./official-site-structure";
import { productRoadmapArticle } from "./product-roadmap";
import { wechatMiniProgramPhaseOneArticle } from "./wechat-mini-program-phase-one";

export const insightArticles = [
  productRoadmapArticle,
  wechatMiniProgramPhaseOneArticle,
  officialSiteStructureArticle,
  downloadWaitlistFlowArticle,
].sort((a, b) => b.publishedAt.localeCompare(a.publishedAt));

export type { InsightArticle } from "./types";
