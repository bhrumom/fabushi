import type { ReactNode } from "react";
import type { Metadata, Viewport } from "next";
import { dachengBrand } from "@fabushi/shared";
import { siteUrl } from "../lib/site-url";
import "./globals.css";

const homeUrl = siteUrl("/");
const siteTitle = `${dachengBrand.name} | 极速首页`;
const siteDescription = "大乘 Web 只保留首页对话、全球法布施和背诵闪卡功能，使用静态首屏和轻量交互。";

export const metadata: Metadata = {
  title: siteTitle,
  description: siteDescription,
  applicationName: dachengBrand.name,
  authors: [{ name: dachengBrand.name }],
  creator: dachengBrand.name,
  publisher: dachengBrand.name,
  metadataBase: new URL(homeUrl),
  alternates: {
    canonical: homeUrl,
  },
  keywords: ["大乘", "全球法布施", "背诵闪卡", "极速 Web", "小程序"],
  openGraph: {
    title: siteTitle,
    description: siteDescription,
    url: homeUrl,
    siteName: dachengBrand.name,
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary",
    title: siteTitle,
    description: siteDescription,
  },
  robots: {
    index: true,
    follow: true,
  },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  viewportFit: "cover",
  themeColor: "#0b1117",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
