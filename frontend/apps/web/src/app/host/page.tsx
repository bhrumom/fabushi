import type { Metadata } from "next";
import HostClient from "./host-client";

export const metadata: Metadata = {
  title: "Fabushi Mahayana Host",
  description: "Mahayana Rust Core 的快速可测试 React Host。",
};

export default function HostPage() {
  return <HostClient />;
}
