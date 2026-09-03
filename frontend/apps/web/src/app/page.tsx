import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import HostClientEntry from "./host/host-client-entry";
import { siteUrl } from "../lib/site-url";

const homeUrl = siteUrl("/");
const homeTitle = "Fabushi | Telegram 式全平台 AI Messenger 与 Mini Apps";
const homeDescription =
  "Fabushi Web 与桌面端共享同一 Host / Messenger 体验，并内置 Mini Apps、WebMCP、应用发现与内容级搜索。";

export const metadata: Metadata = {
  title: homeTitle,
  description: homeDescription,
  alternates: { canonical: homeUrl },
  keywords: [
    "Fabushi",
    "Telegram 式 Messenger",
    "Mini App",
    "AI Agent",
    "MCP Apps",
    "WebMCP",
    "应用市场",
    "内容搜索",
    "跨平台",
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
        name: "Fabushi",
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
        "@type": "WebApplication",
        name: "Fabushi Web",
        applicationCategory: "CommunicationApplication",
        operatingSystem: "Web",
        url: homeUrl,
        description: homeDescription,
        featureList: [
          "Messenger",
          "AI Agents",
          "Mini Apps",
          "WebMCP",
          "Marketplace",
          "Content Search",
        ],
      },
    ],
  };

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />
      <HostClientEntry />
    </>
  );
}
