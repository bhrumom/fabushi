import type { MetadataRoute } from "next";
import { siteHref } from "../lib/site-url";

export const dynamic = "force-static";

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: "法布施 Fabushi",
    short_name: "Fabushi",
    description: "经文听诵、禅修冥想、法流视频与全球法布施。",
    start_url: siteHref("/"),
    display: "standalone",
    background_color: "#05070d",
    theme_color: "#101827",
  };
}
