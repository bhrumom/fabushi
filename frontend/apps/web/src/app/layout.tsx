import type { ReactNode } from "react";
import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { siteUrl } from "../lib/site-url";
import "./globals.css";

const homeUrl = siteUrl("/");
const siteTitle = `${brand.name} 大乘 | 经文听诵、禅修与全球法布施`;
const siteDescription =
  "大乘 法布施提供经文听诵、禅修冥想、法流视频、修行记录与 Android / iOS 下载入口。";

export const metadata: Metadata = {
  title: siteTitle,
  description: siteDescription,
  keywords: [
    "法布施",
    "大乘",
    "佛法传播",
    "修行记录",
    "共修",
    "佛教应用",
    "佛法社区",
    "下载入口",
    "Android Beta",
    "TestFlight",
    "微信小程序",
  ],
  applicationName: `${brand.name} 大乘`,
  authors: [{ name: "大乘" }],
  creator: "大乘",
  publisher: "大乘",
  metadataBase: new URL(homeUrl),
  alternates: {
    canonical: homeUrl,
  },
  category: "religion and spirituality",
  manifest: siteUrl("/manifest.webmanifest"),
  openGraph: {
    title: siteTitle,
    description: siteDescription,
    url: homeUrl,
    siteName: "大乘",
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
