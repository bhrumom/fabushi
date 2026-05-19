import { LocalizedText } from "./localized-text";
import { siteHref } from "../lib/site-url";

const FOOTER_LINKS = [
  {
    href: "/download",
    zh: "下载 App",
    en: "Download App",
  },
  {
    href: "/faq",
    zh: "下载 FAQ",
    en: "Download FAQ",
  },
  {
    href: "/contact",
    zh: "联系支持",
    en: "Contact",
  },
  {
    href: "/privacy",
    zh: "隐私说明",
    en: "Privacy",
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
            zh="App 下载、版本说明、安装支持与稳定入口。"
            en="App download, release notes, installation support, and stable access."
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
