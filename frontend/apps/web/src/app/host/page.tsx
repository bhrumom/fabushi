import type { Metadata } from "next";
import HostClientEntry from "./host-client-entry";

export const metadata: Metadata = {
  title: "Fabushi Mahayana Host",
  description: "Mahayana Rust Core 的快速可测试 React Host。",
};

export default function HostPage() {
  return <HostClientEntry />;
}
