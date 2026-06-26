import type { ReactNode } from "react";
import "../fast-home.css";

export default function WebAppLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return children;
}
