import type { ReactNode } from "react";
import type { Metadata } from "next";
import { brand } from "@fabushi/shared";
import { LocaleProvider } from "../components/locale-provider";
import { siteUrl } from "../lib/site-url";
import "./globals.css";

const homeUrl = siteUrl("/");
const siteTitle = `${brand.name} | Dharma Sharing, Meditation, and Global Practice`;
const siteDescription =
  "Fabushi offers sutra listening, meditation, dharma videos, practice tracking, and Android / iOS beta downloads.";

export const metadata: Metadata = {
  title: siteTitle,
  description: siteDescription,
  keywords: [
    "Fabushi",
    "法布施",
    "meditation",
    "sutra",
    "practice tracker",
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
    locale: "en_US",
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
