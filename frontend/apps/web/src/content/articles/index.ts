import type { InsightArticle } from "./types";
import { downloadWaitlistFlowArticle } from "./download-waitlist-flow";
import { officialSiteStructureArticle } from "./official-site-structure";
import { productRoadmapArticle } from "./product-roadmap";
import { wechatMiniProgramPhaseOneArticle } from "./wechat-mini-program-phase-one";

function getInsightArticleSortDate(article: InsightArticle) {
  return article.updatedAt ?? article.publishedAt;
}

export const insightArticles = [
  productRoadmapArticle,
  wechatMiniProgramPhaseOneArticle,
  officialSiteStructureArticle,
  downloadWaitlistFlowArticle,
].sort((a, b) => getInsightArticleSortDate(b).localeCompare(getInsightArticleSortDate(a)));

export type { InsightArticle } from "./types";
