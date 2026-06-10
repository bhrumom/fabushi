import { LocalizedText } from "./localized-text";
import { siteHref } from "../lib/site-url";

const NAV_ITEMS = [
  {
    href: "/",
    zh: "首页",
    en: "Home",
  },
  {
    href: "/app",
    zh: "大乘 Web",
    en: "Dacheng Web",
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
          <a className="nav-cta" href={siteHref("/app")}>
            <LocalizedText zh="打开大乘" en="Open Dacheng" />
          </a>
        </div>
      </div>
    </nav>
  );
}
