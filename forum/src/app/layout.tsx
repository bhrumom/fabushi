import type { Metadata } from "next";
import type { ReactNode } from "react";
import { getForumDeploymentRuntime } from "../lib/forum-runtime";
import "./globals.css";

export const dynamic = "force-dynamic";

export function generateMetadata(): Metadata {
  const runtime = getForumDeploymentRuntime();

  return {
    title: "Fabushi Forum",
    description: "Fabushi 佛法论坛独立项目骨架，用于承载真实可运行、可治理、可沉淀的社区产品。",
    metadataBase: runtime.publicBaseUrl ? new URL(runtime.publicBaseUrl) : undefined,
    alternates: runtime.publicBaseUrl
      ? {
          canonical: "/",
        }
      : undefined,
    robots: runtime.indexingEnabled
      ? {
          index: true,
          follow: true,
        }
      : {
          index: false,
          follow: false,
          nocache: true,
          googleBot: {
            index: false,
            follow: false,
            noimageindex: true,
          },
        },
  };
}

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
