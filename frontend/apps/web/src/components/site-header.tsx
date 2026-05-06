import { primaryNavigation } from "@fabushi/shared";

export function SiteHeader() {
  return (
    <nav className="site-nav" aria-label="主导航">
      <a className="site-wordmark" href="/">
        Fabushi
      </a>
      <div className="site-nav-links">
        {primaryNavigation.map((item) => (
          <a key={item.href} href={item.href}>
            {item.label}
          </a>
        ))}
      </div>
    </nav>
  );
}
