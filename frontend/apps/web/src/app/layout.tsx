import type { Metadata } from "next";
import type { ReactNode } from "react";
import { brand } from "@fabushi/shared";
import { LocaleProvider } from "../components/locale-provider";
import { MarketplaceWebMcp } from "../components/marketplace/marketplace-webmcp";
import { siteUrl } from "../lib/site-url";
import "./globals.css";

const homeUrl = siteUrl("/");
const siteTitle = `${brand.name} | Mini App、AI 工具与内容工作流市场`;
const siteDescription =
  "Fabushi 是可发现、可安装、可立即运行的 Mini App 市场，提供独立应用详情、内容级搜索入口、开发者分发资料与 WebMCP 网站工具。";

export const metadata: Metadata = {
  title: siteTitle,
  description: siteDescription,
  keywords: [
    "Fabushi",
    "应用市场",
    "Mini App",
    "AI 应用",
    "MCP Apps",
    "WebMCP",
    "应用分发",
    "内容级搜索",
    "工作流",
    "开发者平台",
    "法布施",
  ],
  applicationName: `${brand.name} 应用市场`,
  authors: [{ name: "Fabushi" }],
  creator: "Fabushi",
  publisher: "Fabushi",
  metadataBase: new URL(homeUrl),
  alternates: {
    canonical: homeUrl,
  },
  category: "software",
  manifest: siteUrl("/manifest.webmanifest"),
  openGraph: {
    title: siteTitle,
    description: siteDescription,
    url: homeUrl,
    siteName: "Fabushi 应用市场",
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: siteTitle,
    description: siteDescription,
  },
  robots: {
    index: true,
    follow: true,
    googleBot: {
      index: true,
      follow: true,
      "max-image-preview": "large",
      "max-snippet": -1,
      "max-video-preview": -1,
    },
  },
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="zh-CN" suppressHydrationWarning>
      <head>
        <link
          rel="search"
          type="application/opensearchdescription+xml"
          title="Fabushi 应用与内容搜索"
          href={siteUrl("/opensearch.xml")}
        />
        <link
          rel="alternate"
          type="application/json"
          title="Fabushi 公开搜索索引"
          href={siteUrl("/search-index.json")}
        />
      </head>
      <body>
        <MarketplaceWebMcp />
        <LocaleProvider>{children}</LocaleProvider>
      </body>
    </html>
  );
}
