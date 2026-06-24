import { LanguageSwitch } from "./language-switch";
import { LocalizedText } from "./localized-text";
import { siteHref } from "../lib/site-url";

const FLUTTER_WEB_URL = "https://flutter.ombhrum.com";

const NAV_ITEMS = [
  {
    href: "/faliu",
    zh: "法流",
    en: "Faloo",
  },
  {
    href: "/faq",
    zh: "下载 FAQ",
    en: "Download FAQ",
  },
  {
    href: "/contact",
    zh: "联系支持",
    en: "Contact Support",
  },
  {
    href: "/privacy",
    zh: "隐私说明",
    en: "Privacy",
  },
] as const;

export function SiteHeader() {
  return (
    <nav className="site-nav" aria-label="Main navigation / 主导航">
      <a className="site-wordmark" href={siteHref("/")}>
        <span>
          <LocalizedText zh="大乘" en="Dacheng" />
        </span>
        <small>
          <LocalizedText zh="法布施" en="Dharma Sharing" />
        </small>
      </a>
      <div className="site-nav-links-wrap">
        <div className="site-nav-links">
          {NAV_ITEMS.map((item) => (
            <a key={item.href} href={siteHref(item.href)}>
              <LocalizedText zh={item.zh} en={item.en} />
            </a>
          ))}
        </div>
        <div className="site-nav-actions">
          <LanguageSwitch />
          <a className="nav-cta" href={FLUTTER_WEB_URL}>
            <LocalizedText zh="打开大乘" en="Open Dacheng" />
          </a>
        </div>
      </div>
    </nav>
  );
}
