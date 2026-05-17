import { LanguageSwitch } from "./language-switch";
import { LocalizedText } from "./localized-text";
import { siteHref } from "../lib/site-url";

const NAV_ITEMS = [
  {
    href: "/",
    zh: "首页",
    en: "Home",
  },
  {
    href: "/insights",
    zh: "官网资讯",
    en: "News",
  },
  {
    href: "/buddhadharma",
    zh: "佛法入门",
    en: "Dharma Basics",
  },
  {
    href: "/buddhist-concepts",
    zh: "佛学概念",
    en: "Concepts",
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
] as const;

export function SiteHeader() {
  return (
    <nav className="site-nav" aria-label="Main navigation / 主导航">
      <a className="site-wordmark" href={siteHref("/")}>
        <span>
          <LocalizedText zh="大乘" en="Fabushi" />
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
          <a className="nav-cta" href={siteHref("/download")}>
            <LocalizedText zh="下载 App" en="Download App" />
          </a>
        </div>
      </div>
    </nav>
  );
}
