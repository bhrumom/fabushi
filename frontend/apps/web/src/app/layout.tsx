import type { ReactNode } from "react";
import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { siteUrl } from "../lib/site-url";
import "./globals.css";

const homeUrl = siteUrl("/");
const siteTitle = `${brand.name} Fabushi | 佛法传播、修行记录与下载入口`;
const siteDescription =
  "Fabushi 法布施官网，统一承接佛法传播、修行记录、公开档案、排行榜、下载入口、测试申请与内容专栏。";

export const metadata: Metadata = {
  title: siteTitle,
  description: siteDescription,
  metadataBase: new URL(homeUrl),
  applicationName: `${brand.name} Fabushi`,
  alternates: {
    canonical: homeUrl,
  },
  keywords: [
    "法布施",
    "Fabushi",
    "佛法传播",
    "修行记录",
    "佛教应用",
    "下载入口",
    "TestFlight",
    "Android Beta",
    "微信小程序",
    "公开档案",
    "排行榜",
  ],
  category: "community",
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
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
