import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { FaliuShell } from "../../components/faliu-shell";
import { FALIU_FEATURED_WORKS } from "../../lib/faliu-config";
import {
  buildCbetaContentId,
  fetchAllWorks,
  fetchBatchStats,
  fetchWorkInfo,
  type CbetaWorkInfo,
  type ContentStats,
  type CbetaWorkIndexItem,
} from "../../lib/faliu-api";
import { siteUrl } from "../../lib/site-url";

const pageUrl = siteUrl("/faliu");
const pageTitle = `法流 | CBETA 佛典流式浏览 | ${brand.name}`;
const pageDescription =
  "法流页使用 CBETA API 提供佛典题名、卷次与正文浏览，并接入法布施 App 后端的互动统计与评论数据。";

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: pageUrl,
  },
  keywords: [
    "法流",
    "CBETA API",
    "佛典浏览",
    "佛经搜索",
    "大藏经阅读",
    "Fabushi 法流",
  ],
  openGraph: {
    title: pageTitle,
    description: pageDescription,
    url: pageUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: pageTitle,
    description: pageDescription,
  },
};

async function loadInitialFaliuData() {
  try {
    const allWorks = await fetchAllWorks();
    const featuredSet = new Set(FALIU_FEATURED_WORKS);
    const featuredWorks = allWorks
      .filter((item) => featuredSet.has(item.work))
      .sort((left, right) => FALIU_FEATURED_WORKS.indexOf(left.work) - FALIU_FEATURED_WORKS.indexOf(right.work))
      .slice(0, 12);
    const fallbackWorks = featuredWorks.length > 0 ? featuredWorks : allWorks.slice(0, 12);
    const infoEntries = await Promise.all(
      fallbackWorks.map(async (item) => {
        const info = await fetchWorkInfo(item.work).catch(() => null);
        return [item.work, info] as const;
      }),
    );
    const initialWorkInfo: Record<string, CbetaWorkInfo | null> = Object.fromEntries(infoEntries);
    const initialStats: Record<string, ContentStats> = await fetchBatchStats(
      fallbackWorks.map((item) => buildCbetaContentId(item.work, item.juans[0] ?? "1")),
    ).catch(() => ({}));

    return {
      initialWorks: fallbackWorks,
      initialWorkInfo,
      initialStats,
    };
  } catch {
    return {
      initialWorks: [] as CbetaWorkIndexItem[],
      initialWorkInfo: {},
      initialStats: {},
    };
  }
}

export default async function FaliuPage() {
  const initialData = await loadInitialFaliuData();
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "CollectionPage",
        name: "法流",
        url: pageUrl,
        description: pageDescription,
        inLanguage: "zh-CN",
        isPartOf: {
          "@type": "WebSite",
          name: `${brand.name} Fabushi`,
          url: siteUrl("/"),
        },
      },
      {
        "@type": "SearchResultsPage",
        name: "CBETA 佛典流式浏览",
        url: pageUrl,
        description: "浏览精选佛典、切换专题分类，并查看卷次正文与互动数据。",
      },
    ],
  };

  return (
    <main>
      <script
        type="application/ld+json"
        suppressHydrationWarning
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />

      <FaliuShell {...initialData} />
    </main>
  );
}
