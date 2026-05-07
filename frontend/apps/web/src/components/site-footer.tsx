import { siteHref } from "../lib/site-url";

export function SiteFooter() {
  return (
    <footer className="site-footer">
      <div>
        <p className="footer-title">法布施 Fabushi</p>
        <p className="footer-copy">官网集中承接下载入口、测试申请、FAQ、内容更新与公开协作信息。</p>
      </div>
      <div className="footer-links">
        <a href={siteHref("/download")}>下载入口</a>
        <a href={siteHref("/apply")}>申请测试</a>
        <a href={siteHref("/faq")}>常见问题</a>
        <a href={siteHref("/contact")}>联系</a>
        <a href={siteHref("/insights")}>内容专栏</a>
        <a href="mailto:support@fabushi.com">support@fabushi.com</a>
      </div>
    </footer>
  );
}
