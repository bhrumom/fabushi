import { primaryNavigation } from "@fabushi/shared";
import { siteHref } from "../lib/site-url";

export function SiteHeader() {
  return (
    <nav className="site-nav" aria-label="主导航">
      <a className="site-wordmark" href={siteHref("/")}>
        <span>大乘</span>
        <small>法布施</small>
      </a>
      <div className="site-nav-links-wrap">
        <div className="site-nav-links">
          {primaryNavigation.map((item) => (
            <a key={item.href} href={siteHref(item.href)}>
              {item.label}
            </a>
          ))}
        </div>
        <a className="nav-cta" href={siteHref("/download")}>
          下载入口
        </a>
      </div>
    </nav>
  );
}
