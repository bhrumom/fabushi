import { primaryNavigation } from "@fabushi/shared";
import { siteHref } from "../lib/site-url";

export function SiteHeader() {
  return (
    <nav className="site-nav" aria-label="主导航">
      <a className="site-wordmark" href={siteHref("/")}>
        Fabushi
      </a>
      <div className="site-nav-links">
        {primaryNavigation.map((item) => (
          <a key={item.href} href={siteHref(item.href)}>
            {item.label}
          </a>
        ))}
      </div>
    </nav>
  );
}
