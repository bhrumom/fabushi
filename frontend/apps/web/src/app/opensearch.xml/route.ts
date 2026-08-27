import { siteUrl } from "../../lib/site-url";

export const dynamic = "force-static";

export function GET() {
  const searchTemplate = `${siteUrl("/search")}?q={searchTerms}`.replace(/&/g, "&amp;");
  const xml = `<?xml version="1.0" encoding="UTF-8"?>
<OpenSearchDescription xmlns="http://a9.com/-/spec/opensearch/1.1/">
  <ShortName>Fabushi</ShortName>
  <Description>搜索 Fabushi Mini App、指南、模板和工作流</Description>
  <InputEncoding>UTF-8</InputEncoding>
  <Language>zh-CN</Language>
  <Url type="text/html" template="${searchTemplate}" />
</OpenSearchDescription>`;

  return new Response(xml, {
    headers: {
      "content-type": "application/opensearchdescription+xml; charset=utf-8",
      "cache-control": "public, max-age=3600, s-maxage=86400",
    },
  });
}
