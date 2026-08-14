"use client";

import dynamic from "next/dynamic";

const HostClient = dynamic(() => import("./host-client"), {
  ssr: false,
});

export default function HostClientEntry() {
  return <HostClient />;
}
