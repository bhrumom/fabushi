import { LocalizedText } from "./localized-text";
import { siteHref } from "../lib/site-url";

const FOOTER_LINKS = [
  {
    href: "/download",
    zh: "下载 App",
    en: "Download App",
  },
  {
    href: "/insights",
    zh: "官网资讯",
    en: "Site News",
  },
  {
    href: "/buddhadharma",
    zh: "佛法学习",
    en: "Dharma Learning",
  },
  {
    href: "/practice-guide",
    zh: "修行方法",
    en: "Practice Guide",
  },
  {
    href: "/sutra-guide",
    zh: "佛经导读",
    en: "Sutra Guide",
  },
  {
    href: "/faq",
    zh: "常见问题",
    en: "FAQ",
  },
  {
    href: "/contact",
    zh: "联系支持",
    en: "Contact",
  },
] as const;

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div>
        <p className="footer-title">
          <LocalizedText zh="法布施 大乘" en="Fabushi" />
        </p>
        <p className="footer-copy">
          <LocalizedText
            zh="全球法布施、禅修、听诵、佛经与稳定下载入口。"
            en="Global giving, meditation, listening, sutras, and stable download access."
          />
        </p>
      </div>
      <div className="footer-links">
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
