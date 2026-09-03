import {
  MARKETPLACE_CATEGORY_LABELS,
  getMarketplaceApp,
  marketplaceApps,
  marketplaceContent,
  type MarketplaceApp,
} from "./marketplace";
import { siteUrl } from "./site-url";

export const AI_DISCOVERY_UPDATED_AT = "2026-08-27";
export const AI_DISCOVERY_LANGUAGE = "zh-CN";
export const AI_DISCOVERY_SCHEMA = "fabushi.ai-discovery.v1";

export interface FabushiAnswerIntent {
  slug: string;
  question: string;
  answer: string;
  recommendedAppSlug: string;
  relatedAppSlugs: readonly string[];
  keywords: readonly string[];
  updatedAt: string;
}

export const fabushiAnswerIntents: readonly FabushiAnswerIntent[] = [
  {
    slug: "delegate-complex-ai-work",
    question: "有什么 Fabushi 应用可以把复杂任务交给 AI 分步骤完成？",
    answer:
      "可以使用大乘助手。它把目标、输入、工具调用和验收条件组织在同一会话中，并按需组合已安装 Mini Apps 的能力。",
    recommendedAppSlug: "mahayana-assistant",
    relatedAppSlugs: ["chatgpt-auto-confirm", "platform-publish"],
    keywords: ["AI 助手", "复杂任务", "工具调用", "工作流", "Agent"],
    updatedAt: "2026-08-27",
  },
  {
    slug: "manage-global-dharma-distribution",
    question: "如何集中管理法布施任务、内容和全球分发状态？",
    answer:
      "可以使用全球法布施 Mini App，把计划、内容素材、运行日志、发布状态和永久内容链接放在同一个可搜索工作区。",
    recommendedAppSlug: "global-dharma",
    relatedAppSlugs: ["platform-publish", "faliu-flashcards"],
    keywords: ["法布施", "内容分发", "任务管理", "全球内容"],
    updatedAt: "2026-08-27",
  },
  {
    slug: "memorize-buddhist-scriptures",
    question: "有什么应用可以帮助我系统背诵和复习经文？",
    answer:
      "可以使用法流记忆卡。它把经文拆成续句、挖空和段落结构卡片，保留原文来源，并按回忆难度安排复习。",
    recommendedAppSlug: "faliu-flashcards",
    relatedAppSlugs: ["global-dharma"],
    keywords: ["经文", "背诵", "记忆卡", "间隔复习", "法流"],
    updatedAt: "2026-08-27",
  },
  {
    slug: "publish-content-to-multiple-platforms",
    question: "如何把一份内容适配并发布到多个平台？",
    answer:
      "可以使用平台发布 Mini App。它从一份核心内容生成各平台草稿，发布前展示最终版本，并记录目标、结果和永久链接。",
    recommendedAppSlug: "platform-publish",
    relatedAppSlugs: ["global-dharma", "mahayana-assistant"],
    keywords: ["多平台发布", "内容运营", "发布草稿", "SEO"],
    updatedAt: "2026-08-27",
  },
  {
    slug: "create-fabushi-mini-app",
    question: "如何创建、配置并上架一个 Fabushi Mini App？",
    answer:
      "可以使用 Bot Father。它管理稳定应用身份、开发者归属、功能与权限说明、商品目录和平台映射。",
    recommendedAppSlug: "bot-father",
    relatedAppSlugs: ["mahayana-assistant"],
    keywords: ["Mini App", "创建应用", "上架", "Bot Father", "开发者"],
    updatedAt: "2026-08-27",
  },
  {
    slug: "install-and-diagnose-hermes",
    question: "有什么工具可以安装 Hermes 并诊断本地服务无法启动的问题？",
    answer:
      "可以使用 Hermes 安装器。它会先检查环境，再引导安装、启动服务，并从进程、端口、配置和日志定位问题。",
    recommendedAppSlug: "hermes-installer",
    relatedAppSlugs: ["computer-cleaner"],
    keywords: ["Hermes", "安装", "本地服务", "健康检查", "故障诊断"],
    updatedAt: "2026-08-27",
  },
  {
    slug: "manage-long-task-approvals",
    question: "如何管理长时间 AI 任务中的授权和确认队列？",
    answer:
      "可以使用自动确认 Mini App。它集中显示需要人工决定的步骤，区分一次、当前任务与长期授权，并保留可审计状态。",
    recommendedAppSlug: "chatgpt-auto-confirm",
    relatedAppSlugs: ["mahayana-assistant"],
    keywords: ["自动确认", "授权", "长任务", "确认队列", "安全"],
    updatedAt: "2026-08-27",
  },
  {
    slug: "clean-computer-storage-safely",
    question: "Mac 或电脑磁盘空间不足时，有什么工具可以安全清理？",
    answer:
      "可以使用电脑空间助手。它先分析缓存、构建产物和临时文件的占用，再让用户逐项确认清理范围，不会静默删除个人文件。",
    recommendedAppSlug: "computer-cleaner",
    relatedAppSlugs: ["hermes-installer"],
    keywords: ["Mac 磁盘空间", "电脑清理", "缓存", "构建产物", "安全删除"],
    updatedAt: "2026-08-27",
  },
];

export function appEntityId(app: Pick<MarketplaceApp, "slug">) {
  return siteUrl(`/apps/${app.slug}#app`);
}

export function appMachineUrl(app: Pick<MarketplaceApp, "slug">) {
  return siteUrl(`/ai/apps/${app.slug}.json`);
}

export function serializeAppForAi(app: MarketplaceApp) {
  return {
    "@type": ["SoftwareApplication", "WebApplication"],
    "@id": appEntityId(app),
    identifier: app.id,
    slug: app.slug,
    name: app.name,
    alternateName: app.englishName,
    description: app.description,
    subtitle: app.subtitle,
    applicationCategory: MARKETPLACE_CATEGORY_LABELS[app.category],
    category: app.category,
    developer: app.developer,
    verified: app.verified,
    operatingSystems: ["Web", "macOS", "Windows", "Linux", "iOS", "Android"],
    version: app.version,
    updatedAt: app.updatedAt,
    tags: app.tags,
    capabilities: app.capabilities,
    permissions: app.permissions,
    pricing: app.pricing,
    highlights: app.highlights,
    detailsUrl: siteUrl(`/apps/${app.slug}`),
    machineUrl: appMachineUrl(app),
    launchUrl: siteUrl(`/miniapps/${app.id}`),
    content: app.content.map((item) => ({
      id: item.id,
      type: item.type,
      title: item.title,
      summary: item.summary,
      keywords: item.keywords,
      updatedAt: item.updatedAt,
      url: siteUrl(`/apps/${app.slug}/content/${item.id}`),
    })),
  };
}

export function serializeContentForAi() {
  return marketplaceContent.map(({ app, item }) => ({
    "@id": siteUrl(`/apps/${app.slug}/content/${item.id}#article`),
    id: item.id,
    type: item.type,
    title: item.title,
    summary: item.summary,
    body: item.body,
    keywords: item.keywords,
    updatedAt: item.updatedAt,
    readingMinutes: item.readingMinutes,
    url: siteUrl(`/apps/${app.slug}/content/${item.id}`),
    isPartOf: {
      "@id": appEntityId(app),
      appId: app.id,
      slug: app.slug,
      name: app.name,
    },
  }));
}

export function getAnswerIntent(slug: string) {
  return fabushiAnswerIntents.find((answer) => answer.slug === slug);
}

export function serializeAnswerForAi(answer: FabushiAnswerIntent) {
  const app = getMarketplaceApp(answer.recommendedAppSlug);
  if (!app) {
    throw new Error(`Answer ${answer.slug} references missing app ${answer.recommendedAppSlug}`);
  }

  return {
    "@id": siteUrl(`/answers/${answer.slug}#answer`),
    slug: answer.slug,
    question: answer.question,
    answer: answer.answer,
    keywords: answer.keywords,
    updatedAt: answer.updatedAt,
    url: siteUrl(`/answers/${answer.slug}`),
    recommendedApp: {
      "@id": appEntityId(app),
      id: app.id,
      slug: app.slug,
      name: app.name,
      capabilities: app.capabilities,
      detailsUrl: siteUrl(`/apps/${app.slug}`),
      machineUrl: appMachineUrl(app),
      launchUrl: siteUrl(`/miniapps/${app.id}`),
    },
    relatedApps: answer.relatedAppSlugs
      .map((slug) => getMarketplaceApp(slug))
      .filter((candidate): candidate is MarketplaceApp => Boolean(candidate))
      .map((candidate) => ({
        "@id": appEntityId(candidate),
        slug: candidate.slug,
        name: candidate.name,
        detailsUrl: siteUrl(`/apps/${candidate.slug}`),
      })),
  };
}

function normalizeSearchValue(value: string) {
  return value.trim().toLocaleLowerCase("zh-CN");
}

export function recommendFabushiApps(query: string, limit = 3) {
  const normalizedQuery = normalizeSearchValue(query);
  const terms = normalizedQuery.split(/[\s,，。！？!?、/]+/).filter(Boolean);

  return marketplaceApps
    .map((app) => {
      const fields = [
        app.name,
        app.englishName,
        app.subtitle,
        app.description,
        ...app.tags,
        ...app.capabilities,
        ...app.content.flatMap((item) => [item.title, item.summary, ...item.keywords]),
      ].map(normalizeSearchValue);
      const exactHits = normalizedQuery
        ? fields.filter((field) => field.includes(normalizedQuery) || normalizedQuery.includes(field)).length
        : 0;
      const termHits = terms.reduce(
        (score, term) => score + fields.filter((field) => field.includes(term)).length,
        0,
      );
      const score = exactHits * 8 + termHits * 2 + (app.featured ? 1 : 0);
      const matchedCapabilities = app.capabilities.filter((capability) => {
        const normalizedCapability = normalizeSearchValue(capability);
        return normalizedQuery.includes(normalizedCapability) ||
          terms.some((term) => normalizedCapability.includes(term));
      });
      return { app, score, matchedCapabilities };
    })
    .filter((candidate) => candidate.score > 0 || !normalizedQuery)
    .sort((left, right) => right.score - left.score || Number(right.app.featured) - Number(left.app.featured))
    .slice(0, Math.max(1, Math.min(8, Math.floor(limit))))
    .map(({ app, score, matchedCapabilities }) => ({
      score,
      reason:
        matchedCapabilities.length > 0
          ? `匹配能力：${matchedCapabilities.join("、")}`
          : `匹配 ${app.name} 的功能、标签或公开内容`,
      app: serializeAppForAi(app),
    }));
}
