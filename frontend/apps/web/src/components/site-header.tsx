import { LanguageSwitch } from "./language-switch";
import { LocalizedText } from "./localized-text";
import { siteHref } from "../lib/site-url";

const NAV_ITEMS = [
  {
    href: "/#download",
    zh: "下载",
    en: "Download",
  },
  {
    href: "/#features",
    zh: "功能",
    en: "Features",
  },
  {
    href: "/faq",
    zh: "常见问题",
    en: "FAQ",
  },
  {
    href: "/apply",
    zh: "申请测试",
    en: "Apply",
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
            <LocalizedText zh="下载入口" en="Download" />
          </a>
        </div>
      </div>
    </nav>
  );
}
