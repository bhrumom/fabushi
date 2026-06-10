import type { ReactNode } from "react";
import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocaleProvider } from "../components/locale-provider";
import { siteUrl } from "../lib/site-url";
import "./globals.css";

const homeUrl = siteUrl("/");
const siteTitle = `${brand.name} | 全球法布施 App 下载官网`;
const siteDescription =
  "Fabushi 官网只服务 App 下载与安装转化，提供 iOS、Android 与桌面版下载入口、版本说明、安装支持、下载 FAQ 与基础隐私信息。";

export const metadata: Metadata = {
  title: siteTitle,
  description: siteDescription,
  keywords: [
    "Fabushi",
    "法布施",
    "全球法布施",
    "App 下载",
    "iOS 下载",
    "Android 下载",
    "macOS 下载",
    "Windows 下载",
    "Linux 下载",
    "桌面版下载",
    "TestFlight",
    "APK 下载",
    "下载 FAQ",
    "安装支持",
  ],
  applicationName: `${brand.name} Fabushi`,
  authors: [{ name: "Fabushi" }],
  creator: "Fabushi",
  publisher: "Fabushi",
  metadataBase: new URL(homeUrl),
  alternates: {
    canonical: homeUrl,
  },
  category: "utilities",
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
