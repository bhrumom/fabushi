import type { ReactNode } from "react";
import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { siteUrl } from "../lib/site-url";
import "./globals.css";

const homeUrl = siteUrl("/");

export const metadata: Metadata = {
  title: `${brand.name} | 官网`,
  description: brand.mission,
  applicationName: brand.englishName,
  metadataBase: new URL(homeUrl),
  alternates: {
    canonical: homeUrl,
  },
  keywords: ["法布施", "Fabushi", "佛法传播", "修行记录", "微信小程序", "共修", "佛教应用"],
  category: "religion",
  creator: "Fabushi Team",
  publisher: "Fabushi Team",
  referrer: "origin-when-cross-origin",
  openGraph: {
    title: `${brand.name} | 官网`,
    description: brand.mission,
    url: homeUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary_large_image",
    title: `${brand.name} | 官网`,
    description: brand.mission,
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
