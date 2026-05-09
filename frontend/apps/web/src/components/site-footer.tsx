import { siteHref } from "../lib/site-url";

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div>
        <p className="footer-title">法布施 Fabushi</p>
        <p className="footer-copy">佛法传播、修行记录与共修连接。</p>
      </div>
      <div className="footer-links">
        <a href={siteHref("/download")}>下载</a>
        <a href={siteHref("/apply")}>申请测试</a>
        <a href={siteHref("/faq")}>FAQ</a>
        <a href={siteHref("/contact")}>联系</a>
        <a href="mailto:support@fabushi.com">support@fabushi.com</a>
      </div>
    </footer>
  );
}
