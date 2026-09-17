import { LocalizedText } from "./localized-text";
import { siteHref } from "../lib/site-url";

const WEB_APP_URL = "https://web.ombhrum.com/";

const FOOTER_LINKS = [
  {
    href: "/apps",
    zh: "应用",
    en: "Apps",
  },
  {
    href: "/download",
    zh: "下载 App",
    en: "Download App",
  },
  {
    href: "/faq",
    zh: "FAQ",
    en: "FAQ",
  },
  {
    href: "/contact",
    zh: "联系支持",
    en: "Contact Support",
  },
  {
    href: "/privacy",
    zh: "隐私与安全",
    en: "Privacy & Safety",
  },
] as const;

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div>
        <p className="footer-title">Fabushi</p>
        <p className="footer-copy">
          <LocalizedText
            zh="跨平台 Messenger、AI Agents、Mini Apps、WebMCP、应用发现与下载支持。"
            en="Cross-platform Messenger, AI Agents, Mini Apps, WebMCP, app discovery, downloads, and support."
          />
        </p>
      </div>
      <div className="footer-links">
        <a href={WEB_APP_URL}>
          <LocalizedText zh="打开 Fabushi Web" en="Open Fabushi Web" />
        </a>
        {FOOTER_LINKS.map((item) => (
          <a key={item.href} href={siteHref(item.href)}>
            <LocalizedText zh={item.zh} en={item.en} />
          </a>
        ))}
        <a href="mailto:support@ombhrum.com">support@ombhrum.com</a>
      </div>
    </footer>
  );
}
