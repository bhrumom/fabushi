import type { Metadata } from "next";
import type { ReactNode } from "react";
import { brand } from "@fabushi/shared";
import { LocaleProvider } from "../components/locale-provider";
import { MarketplaceWebMcp } from "../components/marketplace/marketplace-webmcp";
import { siteUrl } from "../lib/site-url";
import "./globals.css";

const homeUrl = siteUrl("/");
const siteTitle = `${brand.name} | 跨平台 Messenger、AI Agents 与 Mini Apps`;
const siteDescription =
  "Fabushi 是跨平台 Messenger 与 AI Agent Host。Web、桌面与移动端保持一致的核心交互，并内置 Mini Apps、WebMCP、应用市场和内容级搜索。";

export const metadata: Metadata = {
  title: siteTitle,
  description: siteDescription,
  keywords: [
    "Fabushi",
    "Messenger",
    "AI Agent",
    "Mini App",
    "MCP Apps",
    "WebMCP",
    "应用市场",
    "应用分发",
    "内容级搜索",
    "跨平台",
    "工作流",
  ],
  applicationName: brand.name,
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
    siteName: "Fabushi",
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
