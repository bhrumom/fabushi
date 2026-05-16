import type { Metadata } from "next";
import type { ReactNode } from "react";
import "./globals.css";

export const metadata: Metadata = {
  title: "Fabushi Forum",
  description: "Fabushi 佛法论坛独立项目骨架，用于承载真实可运行、可治理、可沉淀的社区产品。",
};

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
