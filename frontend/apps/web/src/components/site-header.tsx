import { primaryNavigation } from "@fabushi/shared";
import { siteHref } from "../lib/site-url";

const compactNavigation = primaryNavigation.filter((item) =>
  ["/download", "/apply", "/faq", "/contact"].includes(item.href),
);

export function SiteHeader() {
  return (
    <nav className="site-nav" aria-label="主导航">
      <a className="site-wordmark" href={siteHref("/")}>
        <span>Fabushi</span>
        <small>法布施</small>
      </a>
      <div className="site-nav-cluster">
        <div className="site-nav-links">
          {compactNavigation.map((item) => (
            <a key={item.href} href={siteHref(item.href)}>
              {item.label}
            </a>
          ))}
        </div>
        <a className="nav-action" href={siteHref("/apply")}>
          申请测试
        </a>
      </div>
    </nav>
  );
}
