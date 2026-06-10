import type { Metadata } from "next";
import { dachengBrand } from "@fabushi/shared";
import { FastDachengHome } from "../components/fast-dacheng-home";
import { siteUrl } from "../lib/site-url";

const homeUrl = siteUrl("/");
const title = `${dachengBrand.name} | 全球法布施与背诵闪卡`;
const description = "大乘 Web 首页只保留对话、全球法布施和背诵闪卡，首屏使用轻量静态界面。";

export const dynamic = "force-static";

export const metadata: Metadata = {
  title,
  description,
  alternates: {
    canonical: homeUrl,
  },
  keywords: ["大乘", "全球法布施", "背诵闪卡", "极速 Web", "小程序"],
  openGraph: {
    title,
    description,
    url: homeUrl,
    siteName: dachengBrand.name,
    locale: "zh_CN",
    type: "website",
  },
  twitter: {
    card: "summary",
    title,
    description,
  },
};

export default function HomePage() {
  return <FastDachengHome />;
}
