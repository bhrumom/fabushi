import { LanguageSwitch } from "./language-switch";
import { LocalizedText } from "./localized-text";
import { siteHref } from "../lib/site-url";

const WEB_APP_URL = "https://web.ombhrum.com/";

const NAV_ITEMS = [
  {
    href: "/",
    zh: "首页",
    en: "Home",
  },
  {
    href: "/apps",
    zh: "应用",
    en: "Apps",
  },
  {
    href: "/download",
    zh: "下载",
    en: "Download",
  },
  {
    href: "/faq",
    zh: "FAQ",
    en: "FAQ",
  },
  {
    href: "/privacy",
    zh: "隐私与安全",
    en: "Privacy & Safety",
  },
] as const;

export function SiteHeader() {
  return (
    <nav className="site-nav" aria-label="Main navigation / 主导航">
      <a className="site-wordmark" href={siteHref("/")}>
        <span>Fabushi</span>
        <small>
          <LocalizedText zh="法布施大乘" en="Mahayana" />
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
          <a className="nav-cta" href={WEB_APP_URL}>
            <LocalizedText zh="打开 Web" en="Open Web" />
          </a>
        </div>
      </div>
    </nav>
  );
}
