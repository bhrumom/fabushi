import type { ReactNode } from "react";
import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocaleProvider } from "../components/locale-provider";
import { siteUrl } from "../lib/site-url";
import "./globals.css";

const homeUrl = siteUrl("/");
const siteTitle = `${brand.name} | 全球法布施、佛法入门与修行路径`;
const siteDescription =
  "Fabushi 提供学佛从哪里开始、佛法入门、佛学基本概念、佛经导读、禅修、日常功课、经文听诵与修行记录，帮助把修行路径慢慢接回日常生活。";

export const metadata: Metadata = {
  title: siteTitle,
  description: siteDescription,
  keywords: [
    "Fabushi",
    "法布施",
    "全球法布施",
    "学佛从哪里开始",
    "佛法入门",
    "佛学基本概念",
    "佛经导读",
    "禅修",
    "日常功课",
    "经文听诵",
    "修行记录",
    "Android Beta",
    "iOS TestFlight",
  ],
  applicationName: `${brand.name} Fabushi`,
  authors: [{ name: "Fabushi" }],
  creator: "Fabushi",
  publisher: "Fabushi",
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
      <body>
        <LocaleProvider>{children}</LocaleProvider>
      </body>
    </html>
  );
}
