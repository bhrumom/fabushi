import type { ReactNode } from "react";
import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { siteUrl } from "../lib/site-url";
import "./globals.css";

const homeUrl = siteUrl("/");

export const metadata: Metadata = {
  title: `${brand.name} | 官网`,
  description: brand.mission,
  metadataBase: new URL(homeUrl),
  alternates: {
    canonical: homeUrl,
  },
  openGraph: {
    title: `${brand.name} | 官网`,
    description: brand.mission,
    url: homeUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
