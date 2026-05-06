import type { MetadataRoute } from "next";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "法布施官网",
    short_name: "Fabushi",
    description: "法布施官网与多端产品入口",
    start_url: "/",
    display: "standalone",
    background_color: "#f7f0e4",
    theme_color: "#b45f06",
  };
}
