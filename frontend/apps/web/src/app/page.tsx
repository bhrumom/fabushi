import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { MarketplaceShell } from "../components/marketplace/marketplace-shell";
import { marketplaceApps, marketplaceContent } from "../lib/marketplace";
import { siteUrl } from "../lib/site-url";

const homeUrl = siteUrl("/");
const homeTitle = "Fabushi 应用市场 | Mini App、AI 工具与内容工作流";
const homeDescription =
  "发现、安装并立即运行 Fabushi Mini App。像 Telegram Mini App 一样即开即用，像 Shopify App Store 一样可比较与分发，并为指南、模板和工作流提供内容级搜索入口。";

export const metadata: Metadata = {
  title: homeTitle,
  description: homeDescription,
  alternates: { canonical: homeUrl },
  keywords: [
    "Fabushi",
    "应用市场",
    "Mini App",
    "Telegram Mini App",
    "AI 应用",
    "MCP Apps",
    "WebMCP",
    "应用商店",
    "内容搜索",
    "工作流",
    "开发者平台",
  ],
  openGraph: {
    title: homeTitle,
    description: homeDescription,
    url: homeUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: homeTitle,
    description: homeDescription,
  },
};

export default function HomePage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "Organization",
        "@id": `${homeUrl}#organization`,
        name: brand.name,
        alternateName: "Fabushi",
        url: homeUrl,
      },
      {
        "@type": "WebSite",
        "@id": `${homeUrl}#website`,
        name: "Fabushi 应用市场",
        url: homeUrl,
        publisher: { "@id": `${homeUrl}#organization` },
        potentialAction: {
          "@type": "SearchAction",
          target: {
            "@type": "EntryPoint",
            urlTemplate: `${siteUrl("/search")}?q={search_term_string}`,
          },
          "query-input": "required name=search_term_string",
        },
      },
      {
        "@type": "CollectionPage",
        "@id": `${homeUrl}#marketplace`,
        name: homeTitle,
        description: homeDescription,
        url: homeUrl,
        isPartOf: { "@id": `${homeUrl}#website` },
        mainEntity: {
          "@type": "ItemList",
          numberOfItems: marketplaceApps.length,
          itemListElement: marketplaceApps.map((app, index) => ({
            "@type": "ListItem",
            position: index + 1,
            url: siteUrl(`/apps/${app.slug}`),
            name: app.name,
          })),
        },
      },
      {
        "@type": "DataCatalog",
        name: "Fabushi 内容级搜索索引",
        description: `收录 ${marketplaceContent.length} 条指南、模板、内容集与工作流。`,
        url: siteUrl("/search-index.json"),
        dataset: marketplaceApps.map((app) => ({
          "@type": "Dataset",
          name: `${app.name} 内容目录`,
          url: siteUrl(`/apps/${app.slug}`),
          distribution: {
            "@type": "DataDownload",
            contentUrl: siteUrl("/search-index.json"),
            encodingFormat: "application/json",
          },
        })),
      },
    ],
  };

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />
      <MarketplaceShell />
    </>
  );
}
