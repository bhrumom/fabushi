import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import HostClientEntry from "../host/host-client-entry";

const webUrl = "https://web.ombhrum.com/";
const webTitle = "Fabushi Web | Messenger、AI Agents 与 Mini Apps";
const webDescription =
  "Fabushi Web 是完整的浏览器应用，与桌面端共享同一 Host / Messenger 体验，并内置 AI Agents、Mini Apps、WebMCP、应用发现与内容级搜索。";

export const metadata: Metadata = {
  title: webTitle,
  description: webDescription,
  manifest: "/manifest.webmanifest",
  alternates: { canonical: webUrl },
  robots: { index: false, follow: false },
  openGraph: {
    title: webTitle,
    description: webDescription,
    url: webUrl,
    siteName: "Fabushi",
    locale: "zh_CN",
    type: "website",
  },
};

export default function FabushiWebPage() {
  const structuredData = {
    "@context": "https://schema.org",
    "@type": "WebApplication",
    name: `${brand.name} Web`,
    alternateName: "Fabushi Web",
    applicationCategory: "CommunicationApplication",
    operatingSystem: "Web",
    url: webUrl,
    description: webDescription,
    featureList: [
      "Messenger",
      "AI Agents",
      "Mini Apps",
      "WebMCP",
      "Marketplace",
      "Content Search",
    ],
  };

  return (
    <>
      <script
        type="application/ld+json"
        dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData) }}
      />
      <HostClientEntry />
    </>
  );
}
