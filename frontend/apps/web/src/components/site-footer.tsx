import { LocalizedText } from "./localized-text";
import { siteHref } from "../lib/site-url";

const FOOTER_LINKS = [
  {
    href: "/app",
    zh: "大乘 Web",
    en: "Dacheng Web",
  },
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
    en: "Contact Support",
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
          <LocalizedText zh="大乘" en="Dacheng" />
        </p>
        <p className="footer-copy">
          <LocalizedText
            zh="统一聊天入口、全球法布施、背诵闪卡、App 下载与支持信息。"
            en="Unified chat entry, global Dharma sharing, recitation flashcards, app downloads, and support."
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
