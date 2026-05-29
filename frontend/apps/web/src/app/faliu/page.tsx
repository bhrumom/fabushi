import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { FaliuContentSearchEnhancer } from "../../components/faliu-content-search-enhancer";
import { FaliuMeritBenefitEnhancer } from "../../components/faliu-merit-benefit-enhancer";
import { FaliuShell } from "../../components/faliu-shell";
import { FaliuSynonymEnhancer } from "../../components/faliu-synonym-enhancer";
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

const FALLBACK_FEATURED_WORKS: CbetaWorkIndexItem[] = [
  { work: "T0365", title: "佛說觀無量壽佛經", juans: ["1"] },
  { work: "T0251", title: "般若波羅蜜多心經", juans: ["1"] },
  { work: "T0235", title: "金剛般若波羅蜜經", juans: ["1"] },
  { work: "T0262", title: "妙法蓮華經", juans: ["1", "2", "3", "4", "5", "6", "7"] },
  { work: "T0279", title: "大方廣佛華嚴經", juans: Array.from({ length: 80 }, (_, index) => String(index + 1)) },
  { work: "T0366", title: "佛說阿彌陀經", juans: ["1"] },
  { work: "T0001", title: "長阿含經", juans: Array.from({ length: 22 }, (_, index) => String(index + 1)) },
  { work: "T0099", title: "雜阿含經", juans: Array.from({ length: 50 }, (_, index) => String(index + 1)) },
  { work: "T0220", title: "大般若波羅蜜多經", juans: Array.from({ length: 600 }, (_, index) => String(index + 1)) },
  { work: "T0374", title: "大般涅槃經", juans: Array.from({ length: 40 }, (_, index) => String(index + 1)) },
  { work: "T0261", title: "大乘理趣六波羅蜜多經", juans: Array.from({ length: 10 }, (_, index) => String(index + 1)) },
  { work: "T0278", title: "大方廣佛華嚴經", juans: Array.from({ length: 60 }, (_, index) => String(index + 1)) },
];

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

function sortFeaturedWorks(items: CbetaWorkIndexItem[]) {
  const featuredSet = new Set(FALIU_FEATURED_WORKS);
  return items
    .filter((item) => featuredSet.has(item.work))
    .sort((left, right) => FALIU_FEATURED_WORKS.indexOf(left.work) - FALIU_FEATURED_WORKS.indexOf(right.work));
}

async function loadInitialFaliuData() {
  try {
    const allWorks = await fetchAllWorks().catch(() => FALLBACK_FEATURED_WORKS);
    const featuredWorks = sortFeaturedWorks(allWorks).slice(0, 12);
    const fallbackWorks = featuredWorks.length > 0 ? featuredWorks : FALLBACK_FEATURED_WORKS;
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
      initialWorks: FALLBACK_FEATURED_WORKS,
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
      <FaliuSynonymEnhancer />
      <FaliuContentSearchEnhancer />
      <FaliuMeritBenefitEnhancer />
    </main>
  );
}
