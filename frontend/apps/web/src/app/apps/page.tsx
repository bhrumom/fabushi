import type { Metadata } from "next";
import { MarketplaceShell } from "../../components/marketplace/marketplace-shell";
import { marketplaceApps, marketplaceContent } from "../../lib/marketplace";
import { siteUrl } from "../../lib/site-url";

const marketplaceUrl = siteUrl("/apps");
const title = "Fabushi Mini Apps | 应用发现、安装与内容搜索";
const description =
  "发现、安装并运行 Fabushi Mini Apps。保留 Telegram 式即开即用体验，并提供应用详情、内容级 SEO、搜索索引与 WebMCP 入口。";

export const metadata: Metadata = {
  title,
  description,
  alternates: { canonical: marketplaceUrl },
  keywords: [
    "Fabushi",
    "Mini Apps",
    "应用市场",
    "MCP Apps",
    "WebMCP",
    "应用分发",
    "内容搜索",
    "开发者平台",
  ],
  openGraph: {
    title,
    description,
    url: marketplaceUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
};

export default function MarketplacePage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@graph": [
      {
        "@type": "CollectionPage",
        "@id": `${marketplaceUrl}#marketplace`,
        name: title,
        description,
        url: marketplaceUrl,
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
