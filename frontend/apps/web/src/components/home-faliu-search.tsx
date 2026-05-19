"use client";

import { useState } from "react";
import { LocalizedText } from "./localized-text";
import { siteHref } from "../lib/site-url";

export function HomeFaliuSearch() {
  const [query, setQuery] = useState("");

  return (
    <form
      className="home-faliu-search"
      role="search"
      onSubmit={(event) => {
        event.preventDefault();
        const trimmed = query.trim();
        const target = trimmed ? `/faliu?q=${encodeURIComponent(trimmed)}` : "/faliu";
        window.location.assign(siteHref(target));
      }}
    >
      <span className="home-faliu-search-icon" aria-hidden="true" />
      <input
        value={query}
        onChange={(event) => setQuery(event.target.value)}
        placeholder="搜索经名或关键词"
        aria-label="搜索 CBETA 佛典"
      />
      <button type="submit">
        <LocalizedText zh="搜索" en="Search" />
      </button>
    </form>
  );
}
