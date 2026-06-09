import type { Metadata } from "next";
import { aiQuickPrompts, brand } from "@fabushi/shared";
import { siteUrl } from "../../../lib/site-url";
import { AiConsole } from "./ai-console";

const pageTitle = `大乘 AI | ${brand.name} Web App`;
const pageDescription =
  "大乘 AI Web 控制台，支持佛法资源搜索、流式问答、经文摘要、发愿文整理和会话记录。";

export const metadata: Metadata = {
  title: pageTitle,
  description: pageDescription,
  alternates: {
    canonical: siteUrl("/app/ai"),
  },
  robots: {
    index: true,
    follow: true,
  },
  openGraph: {
    title: pageTitle,
    description: pageDescription,
    url: siteUrl("/app/ai"),
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
};

export default function DachengAiPage() {
  return <AiConsole quickPrompts={aiQuickPrompts} />;
}
