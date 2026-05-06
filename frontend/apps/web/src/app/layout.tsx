import type { ReactNode } from "react";
import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import "./globals.css";

export const metadata: Metadata = {
  title: `${brand.name} | 官网`,
  description: brand.mission,
  metadataBase: new URL("https://fabushi.ombhrum.com"),
  alternates: {
    canonical: "/",
  },
  openGraph: {
    title: `${brand.name} | 官网`,
    description: brand.mission,
    url: "https://fabushi.ombhrum.com",
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
