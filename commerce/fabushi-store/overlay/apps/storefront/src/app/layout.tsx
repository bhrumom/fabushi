import { getBaseURL } from "@lib/util/env"
import { Metadata } from "next"
import "styles/globals.css"

export const metadata: Metadata = {
  metadataBase: new URL(getBaseURL()),
  title: {
    default: "Fabushi Store",
    template: "%s | Fabushi Store",
  },
  description: "Fabushi 的独立跨境商城。可直接在浏览器购物，也可在 Fabushi 中由 AI 协助搜索、选品和结账。",
  alternates: { canonical: "/" },
  robots: { index: true, follow: true },
}

export default function RootLayout(props: { children: React.ReactNode }) {
  return (
    <html lang="en" data-mode="light">
      <body>
        <main className="relative">{props.children}</main>
      </body>
    </html>
  )
}
